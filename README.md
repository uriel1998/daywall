# daywall

A bash script to programatically select an appropriate wallpaper for what time of day it is. 

![Example of images](https://github.com/uriel1998/daywall/blob/1b568e9782630c89d90db898fdbec246b7a7442c/out.jpg)

An image of thumbnails of images arranged by their calculated brightness.

## Contents
 1. [About](#1-about)
 2. [License](#2-license)
 3. [Prerequisites](#3-prerequisites)
 4. [Installation](#4-installation)
 5. [Setup](#5-setup)
 6. [Usage](#6-usage)
 7. [Tweaking](#7-tweaking) 
 8. [TODO](#8-todo)

***

## 1. About

I have a lot of wallpapers, and I like to have them rotate. However, I also work 
varying hours, and don't like to suddenly have a bright white background when it's 
the middle of the night. 

`daywall` uses online geolocation to find your latitude and longitude, determine 
how far away from mid-day the current hour is, and then chooses a random image from 
the directory (or directories) you specify with a (calculated) brightness 
appropriate to the time of day.

## 2. License

This project is licensed under the MIT License. For the full license, see `LICENSE`.

## 3. Prerequisites

* hdate
* bc
* imagemagick
* curl
* fdfind (or fd-find) -- optional, uses `find` if `fd-find` is not present
* gawk
* shuf
* timeout
* realpath
* tail

## 4. Installation

On Debian-like (including Ubuntu):

`sudo apt install coreutils hdate bc fd-find curl gawk imagemagick`

## 5. Setup

In `$HOME/.config/daywall.ini` place the topmost directory that contains your 
(default) wallpaper images, like so:

`DIR=/PATH/TO/IMAGES`

While not strictly *required*, `daywall` will squawk if you forget to specify a 
directory to scan on the command line if this is not set.

If you wish to set your coordinates as an environment variable and not use the 
online lookup, do so like this:

`export COORDS="22.73, -81.08`

That's latitude first, then longitude. The comma and space between them is *required*.

### Using with cron

If you're using daywall with cron, you'll need to ensure that your environment 
variables (including `DISPLAY=0.0`) are properly passed, and that the XDG directories 
are appropriately assigned.  

The easiest way to do this is through having your crontab entry be:

`DISPLAY=0.0 /path/to/daywall_cronjob.sh`

and editing `daywall_cronjob.sh` to pull in your appropriate `.bashrc` and deal
with calling `feh` (or whatever you use to set the wallpaper).

One other thing to check is what your XDG directories are. I ran into this problem, 
because I'd changed XDG_CACHE_HOME (for random reasons) so it kept throwing errors. 

To check for this, in a normal terminal window:
```
echo ${XDG_CONFIG_HOME}
echo ${XDG_CACHE_HOME}
```

If those directories aren't `$HOME/.config` and `$HOME/.local/state`, then move 
those files as needed.

## 6. Usage

`daywall.sh [directory] [options]`

directory is optional if configuration file has the directory specified.

OPTIONS (must come after directory, if specified):
--help: This text
--darken: Darken the output image even further for my fellow nightwalkers
--loud: extra output when running

If `--loud` is not invoked, the output will be a single full filename to use with 
the wallpaper setting program of your choice. For example:

`feh --bg-fill --no-xinerama $(daywall.sh)`

### Need it darker? 

Use the `--darken` option to have it convert and darken the image. Ensure that you 
have the `$TMP` environment variable set.

### Adding files

The first time you run it (or add more files to what `daywall` knows about, it 
will be slow since it does the brightness analyzation and stores that data in a 
simple CSV file in `$HOME/.config/daywall.cache`.  Images added to the directory 
specified in the INI file will be added on the next run automatically. 

If you specify a directory on the commandline, that directory's *files* will be 
analyzed and added to the simple list of images to be chosen from.  So for example, 
if your "main" directory of wallpapers is `$HOME/wallpapers` and you wish to add
images from "$HOME/morewalls" to `daywall`, then you will run *once*:

`daywall.sh $HOME/morewalls`

and the image files *currently* in that directory will be added. These additional 
directories will *not* be re-scanned for new images unless the directory is specified 
at run-time.

### Image Selection

If an image is not found within the appropriate brightness range, `daywall` 
will increase the allowable brightness range (in both directions) automatically.

Additionally, `daywall` records the image it selects, and will not use the same 
file on the next run.

## 7. Tweaking

If there is any error with analyzing the brightness, it will be recorded in an 
error log in `$XDG_CACHE_HOME/daywall.error`, which is actually a simple CSV file. 
You should probably check for its existence when you're actively adding files, as 
`daywall` will keep attempting to process them and it can get slow.

The values in the cache file can be manually adjusted if needed.

If you want to change the brightness values and their time of day (with more finesse
than just adding the `--darken` switch), look for this section of the code:

```
    # THESE ARE THE BRIGHTNESS VALUES TO EDIT
    # 0 is MID-DAY
    case "${abs_time_diff}" in
        0)  highval=65000    
            lowval=54000
            ;;
```

`highval` in each set is the highest allowed brightness value, `lowval` is the lowest. 
The hour number is how far away the time is from the midpoint between sunrise and 
sunset (literally "mid-day").  So, for example, if you wanted a wider range of 
brightness values during the mid-day hour, you could change `lowval` to a lower 
number, like so:

```
        0)  highval=65000    
            lowval=45000
            ;;
```            

## 8. TODO
 
* Add additional "watch" directories to INI file
* Random error checking
* Weather adjustment (for overcast days?)
