#!/bin/sh

 ########################################################################
 # 
 #   Daywall - A time/brightness based background changer
 #   by Steven Saus (c)2024
 #   Licensed under the MIT license
 #
 ########################################################################

########################################################################
# Definitions
########################################################################

ConfigDir=${XDG_CONFIG_HOME:-$HOME/.config}
ConfigFile=${ConfigDir}/daywall.ini
CacheDir=${XDG_CACHE_HOME:-$HOME/.local/state}
CacheFile=${ConfigDir}/daywall.cache
ImageDir=""
export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

########################################################################
# Functions
########################################################################

function loud() {
    if [ $LOUD -eq 1 ];then
        echo "$@"
    fi
}

# help
# $1 - if directory, add it to cache and selectable images
# 

# function to read INI
    # should just have the image dir to scan
    # maaaaaaaaaaaaaaaaaaaybe have a way to set it?

# function to scan image dir
    # scan the directory in the ini file; if filename is not in our cache, analyze it and add
    # scan a directory passed in $1; if filename is not in our cache, analyze it AND ADD
    # write list of images to scan from later
    
    
    

function time_of_day() {
    # get geolocated coordinates
    # TODO: Ensure there aren't coords set by environment variable
    
    coords=$(curl -s https://whatismycountry.com/ | sed -e 's/picture/\n/g' -e 's/&#176;//g'  | grep "My coordinates" | awk -F '>' '{print $5}' | awk -F '<' ' {print $1}')
    
    # TODO: test to make sure that's not junk and we're connected to the internet
    lat=$(echo "${coords}" | awk -F ', ' '{ print $1 }')
    long=$(echo "${coords}" | awk -F ', ' '{ print $2 }')    
    sunrise=$(hdate -s -l "$lat" -L "$long" 2>/dev/null | grep "sunrise" | awk '{ print $2 }' | awk -F ':' '{ print $1 }')
    sunset=$(hdate -s -l "$lat" -L "$long" 2>/dev/null | grep "sunrise" | awk '{ print $2 }' | awk -F ':' '{ print $1 }')
    
    # doing all the math with bc to be consistent here
    midday=$(echo "($sunset-$sunrise)/2+$sunrise" | bc)
    midnight=$(echo "($sunset-$sunrise)/2+$sunset" | bc)
    if [ $midnight -gt 23 ];then
        midnight=$(echo "$midnight-24" | bc)
    fi
    
    # where is current hour in comparison to midday
    currhour=$(date "+%-H")
    time_diff=$(expr $(date +%Y%m%d)${currhour} - $(date +%Y%m%d)${midday})
    abs_time_diff=${time_diff#-}
    
    # map the high and low value for the image for the appropriate time
    case "${abs_time_diff}" in
        0)  highval=65000    
            lowval=54000
            ;;
        1)  highval=54000
            lowval=48000
            ;;
        2)  highval=48000
            lowval=42000
            ;;
        3)  highval=42000
            lowval=36000
            ;;
        4)  highval=36000
            lowval=30000
            ;;
        5)  highval=30000
            lowval=24000
            ;;
        6)  highval=24000
            lowval=20000
            ;;
        7)  highval=20000
            lowval=16000
            ;;
        8)  highval=16000
            lowval=12000
            ;;
        9)  highval=12000
            lowval=8000
            ;;
        10) highval=8000
            lowval=4000
            ;;
        11) highval=4000
            lowval=2000
            ;;
        12) highval=2000
            lowval=200
            ;;
        *)  highval=2000
            lowval=200
            ;;
    esac

    # randomly choose line from file with brightness values
    # if brightness value -le highval or -ge lowval, then output (or pass to feh
    # or whatever)


export DISPLAY=:0.0;feh --bg-scale $file
echo "The randomly-selected file is: $file"
exit
