So what’s the second script? It’s to change my wallpaper hourly – based on the time of day. it uses feh (more on how to use feh is at the Arch Wiki, a two liner bash script calculator that uses the bc command (below), and sunrise.c, which has compiling directions in the code.

http://souptonuts.sourceforge.net/code/sunrise.c.html

I renamed the files in the directory with day_, night_, or trans_ at the beginning of the filename (example: “day_coolbackground.jpg”) to allow sorting. The beauty is, I can keep adding cool backgrounds to that directory without worries.

The two-line calculator script is this:

#!/bin/bash
echo “scale=4; $1” | bc ; exit

but it’s embedded in the file. You can find the bash script here. Just run it as an hourly crontab event, and work away!
