#/* 
# * Copyright (c) 2008-9 Patrick Quinn-Graham
# * 
# * Permission is hereby granted, free of charge, to any person obtaining
# * a copy of this software and associated documentation files (the
# * "Software"), to deal in the Software without restriction, including
# * without limitation the rights to use, copy, modify, merge, publish,
# * distribute, sublicense, and/or sell copies of the Software, and to
# * permit persons to whom the Software is furnished to do so, subject to
# * the following conditions:
# * 
# * The above copyright notice and this permission notice shall be
# * included in all copies or substantial portions of the Software.
# * 
# * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# */
 
#
#  TVMain.rb
#  tvmagic
#
#  Created by Patrick Quinn-Graham on 28/09/08.
#  Copyright (c) 2008 Patrick Quinn-Graham. All rights reserved.
#

require 'osx/cocoa'
require 'open-uri'
require 'rubygems'
require 'cgi'
require 'active_record'
require 'rexml/document'
require 'rbosa'
require 'date'
require 'fileutils'

class TvrageCache < ActiveRecord::Base
	self.default_scoping = []
	default_scope :order => 'showname'
end

#ActiveRecord::Base.establish_connection(:adapter => "postgresql", :database => "iplayer_rss", :host => "localhost",
#                                        :port => 5432, :username => 'patrick');

class TVMain < OSX::NSObject

	ib_outlets :processing, :progress, :table, :tableData

	def doStuff(sender)
		##OSX::NSLog "Hello"
	end
	ib_action :doStuff
	
	def processFiles(sender)
		process_files
	end
	ib_action :processFiles
	
	def applicationDidFinishLaunching(sender)
	
		@superDebug = true
		
		fn = cache_file_name
		
		OSX::NSLog("FN is %@", fn)
		
		@logger = Logger.new "/tmp/tvmagic.log"
		ActiveRecord::Base.logger = @logger
		#ActiveRecord::Base.colorize_logging = false

		
		ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => fn);
		
		migrations_path =  OSX::NSBundle.mainBundle.resourcePath + "/Migrations/"
		ActiveRecord::Migrator.migrate(migrations_path, nil)

		process_files
	end

	def awakeFromNib
		@tableData  = []		
		#@table.delegate = self
		#@table.dataSource = self
	end
	
	def numberOfRowsInTableView(table)
		#OSX::NSLog "numberOfRowsInTableView"
		#OSX::NSLog "Number of rows: " + @tableData.length.to_s
		return @tableData.length.to_i
	end
	
	def tableView_objectValueForTableColumn_row(table, column, row)
		#OSX::NSLog "tableView_objectValueForTableColumn_row"
		#OSX::NSLog "This is row: " + row
		keys = [:showname, :season, :episode, :title]
		actual_key = keys[column.identifier.to_i]
		actual_row = @tableData[row.to_i]
		#OSX::NSLog "Actual Row: " + actual_row
		return actual_row[actual_key]
	end
	
	def process_files
	
		@dir_name = "/Volumes/Elephant/To-iTunes/"
		@dest_dir = "/Volumes/Elephant/Video/TV"
		@movi_dir = "/Volumes/Elephant/Video/Movies"
		
		@processing.stringValue = "Connecting to iTunes..."
		@itunes = OSA.app('iTunes')
		source = @itunes.sources[0]
		@library = source.library_playlists[0]
		
		
		@processing.stringValue = "Checking for files..."
		
		number = 0
		d = Dir.entries(@dir_name)
		# count the matching items
		d.each do |f|
			if f.to_s.scan(/\.(mov|avi|m4v|mp4)$/).length > 0
				number = number + 1
			end
		end
		
		@progress.maxValue = number
		@progress.doubleValue = number
		@processing.stringValue = "Found " + number.to_s + " files."
		
		# now do it for reals
		
	    Thread.start do
		
			new_number = 0
			d.each do |f|			
				if f.to_s.scan(/\.(mov|avi|mp4|m4v|mkv)$/).length > 0
					new_number = new_number + 1
					@processing.stringValue = "Processing " + new_number.to_s + " of " + number.to_s + " files."
				end
				
				# Wrap if needed
				if f.to_s.scan(/\.(avi|mkv)$/).length > 0
					#OSX::NSLog "F was: " + f.to_s
					@processing.stringValue = "Converting video " + new_number.to_s + " (" + f.to_s + ")."
					f = wrap_teh_file f
					@processing.stringValue = "Processing " + new_number.to_s + " of " + number.to_s + " files."
					#OSX::NSLog "F is now: " + f.to_s
				end
				
				OSX::NSLog("Figuring out: " + f.to_s) unless @superDebug.nil?
				
				#The Colbert Report (special case)
				if f.to_s.scan(/The.Colbert.Report.(.*)\.(mov|avi|mp4|m4v)$/).length > 0
					date_based f, 'The Colbert Report', false
			  
				#The Colbert Report (special case)
				elsif f.to_s.scan(/The.Daily.Show.(.*)\.(mov|avi|mp4|m4v)$/).length > 0
					date_based f, 'The Daily Show', false
			  
				#Conan O'Brien (special case)
				elsif f.to_s.scan(/Conan.O.Brien.(.*)\.(mov|avi|mp4|m4v)$/).length > 0
					#OSX::NSLog("Conan O'Brien!")
					date_based f, "Conan O'Brien", true
					
				#Jay Leno (special case)
				elsif f.to_s.scan(/Jay.Leno.(.*)\.(mov|avi|mp4|m4v)$/).length > 0
					date_based f, 'Jay Leno', true

				#standard tv shows
				elsif f.to_s.scan(/([a-zA-Z\. 0-9]+)\.[\S\s]([0-9]+)[Ee]([0-9]+)(.*)\.(mov|avi|m4v|mp4)$/).length > 0
					#OSX::NSLog "Usual'ing: " + f.to_s
					usual f
												
				 Movies
				elsif f.to_s.scan(/^(.*)\.MOVIE\.([a-zA-Z]+)\.(m4v|mp4)$/).length > 0
					OSX::NSLog "Movie'ing: " + f.to_s
					movie f
				end				
				
				if f.to_s.scan(/\.(mov|avi|m4v|mp4)$/).length > 0
					@progress.doubleValue = new_number
				end
			
			end
			@processing.stringValue = "Done."
		end
	
	end
	
	
	def date_based(file, name, figure_out_ep_name)
		OSX::NSLog("Date Based: " + name) unless @superDebug.nil?
		
		if(file.to_s.match /([0-9]{4})\.([0-9]{2})\.([0-9]{2})/)
			OSX::NSLog("It's year-month-day...") unless @superDebug.nil?
			(year, month, day, guest), x = file.to_s.scan /([0-9]{4})\.([0-9]{2})\.([0-9]{2})[\.]?(.*)?\.(mov|avi|m4v|mp4)/	
		elsif(file.to_s.match /([0-9]{2})\.([0-9]{2})\.([0-9]{4})/)
			OSX::NSLog("It's month-day-year...") unless @superDebug.nil?
			(month, day, year, guest), x = file.to_s.scan /([0-9]{2})\.([0-9]{2})\.([0-9]{4})[\.]?(.*)?\.(mov|avi|m4v|mp4)/			
		else
			OSX::NSLog("We don't know how to handle this file, skip it.") unless @superDebug.nil?
			return
		end
		
		OSX::NSLog("Ok, so thart went well.") unless @superDebug.nil?
		
		showname_clean = name
		if figure_out_ep_name
			episode_name = guest.gsub(/(HDTV|X[vV][iI]D\-|YesTV|MOMENTUM|BAJSKORV|LMAO|PDTV)/, '').gsub('.', ' ').strip		
		else
			OSX::NSLog("... things?")
			OSX::NSLog("Month: " + month) unless @superDebug.nil?
			OSX::NSLog("Month: " + month.to_i.to_s) unless @superDebug.nil?
			OSX::NSLog("Month: " + Date::MONTHNAMES[month.to_i]) unless @superDebug.nil?
			OSX::NSLog("Day: " + day) unless @superDebug.nil?
			OSX::NSLog("Day: " + day.to_i.to_s) unless @superDebug.nil?
			OSX::NSLog("Year: " + year.to_s) unless @superDebug.nil?
		
			episode_name = Date::MONTHNAMES[month.to_i] + " " + day.to_i.to_s + ", " + year
		end
		
		OSX::NSLog("Episode Name: " + episode_name)
		
		season = year
		episode = month + day
		target_file = @dir_name + file		
		
		
		OSX::NSLog("Season: " + season) unless @superDebug.nil?
		OSX::NSLog("Episode: " + episode) unless @superDebug.nil?
		OSX::NSLog("target_file: " + target_file) unless @superDebug.nil?
		
		put_in = showname_clean + "/" + year.to_s + "/" + month.to_i.to_s
		
		move_teh_file(put_in, target_file, showname_clean, season, episode, episode_name)
	end
	
	def usual(file)	
		
		OSX::NSLog("Usual hi!") unless @superDebug.nil?
		
	  	(showname, season, episode), x = file.to_s.scan /([a-zA-Z\/\. 0-9]+)\.[\S\s]([0-9]+)[Ee]([0-9]+)/	
		showname_clean = showname.gsub('.', ' ')
		
		OSX::NSLog("Usual: %@", showname_clean) unless @superDebug.nil?
				
		tvshow = TvrageCache.find_or_create_by_showname(showname_clean)
		
		OSX::NSLog("... something?") unless @superDebug.nil?
		
		if(tvshow.nil?) 
			OSX::NSLog("TVShow object is nil")
		end
		
		OSX::NSLog("Got past the tvshow is nil check") unless @superDebug.nil?
		
		if tvshow.tvrageid.nil?
		  read_data = open("http://www.tvrage.com/feeds/search.php?show=" + CGI.escape(showname_clean)).read
		
		  doc = REXML::Document.new(read_data)
		  show_id, x = doc.root.elements['show/showid']
		  unless show_id.nil?
			tvshow.tvrageid = show_id.text.to_i
		  end
		
		  tvshow.save
		end
		  
		eps_xml_url = "http://www.tvrage.com/feeds/episode_list.php?sid=" + tvshow.tvrageid.to_s
		
		OSX::NSLog("Usual URL is: %@", eps_xml_url) unless @superDebug.nil?
		
		read_data = open(eps_xml_url).read
		doc = REXML::Document.new(read_data)

		
		OSX::NSLog("Gots me some XML!") unless @superDebug.nil?
		
		if(tvshow.overridename.nil?)
		  OSX::NSLog("Override name was nil") unless @superDebug.nil?
		  tvr_show_name = doc.root.elements['name']
		  unless tvr_show_name.nil?
			showname_clean = tvr_show_name.text
		  end
		  OSX::NSLog("Override name was nil") unless @superDebug.nil?
		else
		  OSX::NSLog("Oerride name was not nil: " + tvshow.overridename) unless @superDebug.nil?
		  showname_clean = tvshow.overridename
		end
		
		OSX::NSLog("Usual TV Show name is now: " + showname_clean) unless @superDebug.nil?
		
		tvr_season = doc.root.elements['Episodelist/Season[@no=' + season.to_i.to_s + ']']
		
		episode_name = 'Episode ' + episode.to_i.to_s
		unless tvr_season.nil?
		  tvr_season.elements.each('episode') do |ep|
			if ep.elements['seasonnum'].text.to_i == episode.to_i
			  episode_name = ep.elements['title'].text
			end
		 end
		end
		
		OSX::NSLog("Episode name: " + episode_name) unless @superDebug.nil?
		
		movie_path = @dir_name + file
		target_ext = File.extname(movie_path)
		target_file = @dir_name + showname_clean + '.S' + season + 'E' + episode + ' ' + episode_name.gsub(/\//,'-') + target_ext        

		unless File.rename(movie_path, target_file)
		  OSX::NSLog "Rename Failed: " + movie_path + " to " + target_file  
		end   
		OSX::NSLog(showname_clean + ', season ' + season + ', episode ' + episode + ": " + episode_name) unless @superDebug.nil?
		put_in = showname_clean + "/Season " + season.to_i.to_s
		move_teh_file(put_in, target_file, showname_clean, season, episode, episode_name)
	end
	
	def move_teh_file(put_in, target_file, showname_clean, season, episode, episode_name)
	
		OSX::NSLog "Put in: " + put_in unless @superDebug.nil?
	
		dest_folder = @dest_dir + "/" + put_in
		
		OSX::NSLog "dest_folder: " + dest_folder unless @superDebug.nil?
		
		FileUtils.mkdir_p dest_folder
		
		OSX::NSLog "dest_folder created. " unless @superDebug.nil?
		
		(extension, y), x = target_file.scan /\.([a-zA-Z0-9]+)$/
		
		OSX::NSLog "extension is " + extension
	
		dest_file = dest_folder + "/" + episode.to_i.to_s + " " + episode_name.gsub(/\//,'-') + "." + extension
		
		OSX::NSLog "Moving to " + dest_file
		
		FileUtils.mv target_file, dest_file
		
		OSX::NSLog "Adding to iTunes " + dest_file
		
		file = @itunes.add(dest_file, @library)
		unless file.nil?
		  file.show = showname_clean
		  file.season_number = season.to_i
		  file.episode_id = season.to_i.to_s + sprintf("%02.0f", episode.to_i).to_s
		  file.episode_number = episode.to_i
		  file.name = episode_name
		  file.artist = showname_clean
		  file.album = showname_clean + ", Season " + season.to_i.to_s
		  file.track_number = episode.to_i
		  file.year = Date.today.year
		  file.video_kind = OSA::ITunes::EVDK::TV_SHOW
		end
		OSX::NSLog "Done adding to iTunes " + dest_file
		
	end

	def movie(f)
	
		target_file = @dir_name + f
		
		OSX::NSLog "target_file: " + target_file unless @superDebug.nil?
		OSX::NSLog "F: " + f unless @superDebug.nil?
	
		title, genre, extension = f.to_s.scan(/^(.*)\.MOVIE\.([a-zA-Z]+)\.(m4v|mp4)$/)[0]
		
		OSX::NSLog "Title: " + title.to_s unless @superDebug.nil?
		OSX::NSLog "Genre: " + genre.to_s unless @superDebug.nil?
		OSX::NSLog "Extension: " + extension.to_s unless @superDebug.nil?
		
		dest_folder = @movi_dir + "/" + genre

		OSX::NSLog "dest_folder: " + dest_folder unless @superDebug.nil?

		FileUtils.mkdir_p dest_folder

		OSX::NSLog "dest_folder created. " unless @superDebug.nil?

		OSX::NSLog "extension is " + extension

		dest_file = dest_folder + "/" + title.gsub(/\//,'-') + "." + extension

		OSX::NSLog "Moving to " + dest_file

		FileUtils.mv target_file, dest_file

		OSX::NSLog "Adding to iTunes " + dest_file + " with genre " + genre

		file = @itunes.add(dest_file, @library)
		unless file.nil?
		  file.genre = genre
		  file.name = title
		end
		
		OSX::NSLog "Added to iTunes " + dest_file

	end

	
	def wrap_teh_file(file)
		unless @qt.nil?
			system("open -a 'QuickTime Player'")
			@qt = OSA.app("QuickTime Player")
		end
		
		system "open -a 'QuickTime Player'"
		
		destination_file = file.to_s.sub(/.avi$/, '.mov')
		
		#OSX::NSLog "Source: " + @dir_name + file.to_s
		#OSX::NSLog "Destination: " + @dir_name + destination_file
		
		@qt = OSA.app("QuickTime Player")
		@qt.activate
		@qt.open(@dir_name + file.to_s)
		src = @qt.documents[0]
		@qt.rewind(src)
		@qt.select_all(src)
		@qt.copy(src)
		@qt.close(src)
		
		@qt.open(OSX::NSBundle.mainBundle.resourcePath.fileSystemRepresentation + "/nothing.mov") #nothing
		out = @qt.documents[0]
		@qt.select_none(out)
		@qt.rewind(out)
		@qt.add(out)
		@qt.select_none(out)
		@qt.rewind(out)

		out.save_self_contained(@dir_name + destination_file)
		
		#OSX::NSLog("Save requested")
			
		while !save_has_happened(@qt)
		  OSX::NSLog "Still saving..." unless @superDebug.nil?
		end		
		@qt.close out

		# move original to trash/delete/whatever
		#File.delete @dir_name + file.to_s
		FileUtils.mv @dir_name + file.to_s, @dir_name + "_trash/" + file.to_s
		
		return destination_file	
	end
	
	def cache_file_name
	
		paths = OSX::NSSearchPathForDirectoriesInDomains(14, 1, true);
		my_name = OSX::NSBundle.mainBundle.objectForInfoDictionaryKey_("CFBundleName")
		
		my_base_folder = paths[0] + "/" + my_name
		
		unless File.directory?(my_base_folder)
			##OSX::NSLog "Making " + my_base_folder
			FileUtils.mkdir_p(my_base_folder)
		else
		end
		
		return  my_base_folder + "/DataStore.tvmagic"
		
	end
	
	def save_has_happened(out_object)
	  begin
		out_object.activate
		return true
	  rescue
		#OSX::NSLog "An error occurred: " + $!
		return false
	  end
	end
	
end
