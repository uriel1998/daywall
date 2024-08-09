#!/bin/sh

 ########################################################################
 # 
 #   MPDQ - The MPD Queuer
 #   by Steven Saus (c)2024
 #   Licensed under the MIT license
 #
 ########################################################################

########################################################################
# Definitions
########################################################################
# Setting them here, will create if needed later
ConfigDir=${XDG_CONFIG_HOME:-$HOME/.config}/mpdq
StateDir=${XDG_STATE_HOME:-$HOME/.local/state}/mpdq
CacheDir=${XDG_CACHE_HOME:-$HOME/.local/state}/mpdq
# Defining some things. This is NOT the instruction file.
ConfigFile=${ConfigDir}/mpdq.ini
# This is used to communicate with running background program, including killing and instruction file changes
RelayName=${StateDir}/mpdq_cmd
# This file will contain time song was played, its filename, the album, and artist
ConfigLogFile=${StateDir}/playedsongs.log
ConfigLogFile2=${StateDir}/playedsongs2.log

# Global variables 
# Global variables 
export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

########################################################################
# Functions
########################################################################

function loud() {
    if [ $LOUD -eq 1 ];then
        echo "$@"
    fi
}


function time_of_day() {
    
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
    
    # where is current hour in comparison to midnight and midday
    currhour=$(date "+%-H")
    echo $currhour
    
    # 0 - 60,000 (or so) is about 5,000 an hour
    # which perceptually is a bit much, so maybe 4k for midnight to + 6
    # then 6k for the 6 hrs to noon, then back down
    # get our brightness range of our photos (rebuild or from config/ini/whatever)
    # they're a string from ... no wait, that won't work. We'll have to define 
    # what range constitutes 
    # dark
    # twilight
    # bright
    
    
    # hdate -s -l N50 -L E14 -z2

#Output:

#Wednesday, 26 June 2019, 23 Sivan 5779
#sunrise: 04:55
#sunset: 21:17

#Options:

#    -s sunset sunrise
#    -l, -L: Altitude and Latitude of Prague (50°05′N 14°25′E)
#    -z zone: SELC=+2

}


currhour=$(date "+%-H")
echo $currhour
tod=$(date "+%p")
case "$tod" in
    "AM")
    risehour=$(sunrise `date "+%Y %m %d"` 39.45 84.11 | awk '{print $3}'|awk -F ":" '{print $1}')  # When is the hour of sunrise
    starttwi=$(echo "scale=0; $risehour-1" | bc)  # hour before and after sunrise hour
    endtwi=$(echo "scale=0; $risehour+1" | bc)
    echo $starttwi $endtwi
    if [ "$currhour" -gt "$endtwi" ]; then
        flavor="day"
    elif [ "$currhour" -lt "$starttwi" ]; then
        flavor="night"
    else
        flavor="trans"
    fi
    echo $flavor
    ;;
    "PM")
    sethour=$(sunrise `date "+%Y %m %d"` 39.45 84.11 | awk '{print $3}'|awk -F ":" '{print $1}')
    starttwi=$(echo "scale=0; $sethour-1+12" | bc)
    endtwi=$(echo "scale=0; $sethour+1+12" | bc)
    echo $starttwi $endtwi
    if [ "$currhour" -gt "$endtwi" ]; then
        flavor="nigh"
    elif [ "$currhour" -lt "$starttwi" ]; then
        flavor="day"
    else
        flavor="trans"
    fi
    echo $flavor    
    ;;  
esac

dir="/home/USERDIRECTORY/.backgrounds/blacknwhite" # Directory
file=`ls -1 /home/USERDIRECTORY/.backgrounds/blacknwhite/$flavor* | sort --random-sort | head -1`
export DISPLAY=:0.0;feh --bg-scale $file
echo "The randomly-selected file is: $file"
exit
