tvmagic
=======

Takes a folder of files (e.g. .avi, .mov, .m4v) and adds them to iTunes, populating metadata using [TVRage.com][0] whenever possible.

.avi files are wrapped, using QuickTime, in a .mov container that also has a 0 second h.264 clip, thus convincing iTunes to add it (and copy it to an AppleTV, which will play it if you have the necessary codecs installed).

[0]: http://www.tvrage.com/

Notes
-----

This is fairly stable code in that I've been using it successfully for many months. However it is not terribly generic at this point. Some assumptions are made:

1. Files can be found in /Volumes/Jaguarundi/Torrents/Done/ToDo/
2. Files should be put in /Volumes/Jaguarundi/Video/TV/{Show name}/Season {Season#}/{Ep#} {Ep name}.{format}
3. You have the required gems installed
4. You are on Leopard

The required gems are:

- rubyosa
- active_record (including the sqlite gem)

Some data is cached from TVRage - specifically the show name (as seen in file names) to TVRage ID, this also allows to override what the application thinks is the actual show name. This file is stored in ~/Library/Application Support/TVMagic/DataStore.tvmagic (a sqlite3 database).

Licence
-------

Copyright (c) 2008-9 Patrick Quinn-Graham

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


