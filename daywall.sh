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

ConfigDir=${XDG_CONFIG_HOME:-$HOME/.config}/daywall
ConfigFile=${ConfigDir}/daywall.ini
LowValue=""
HighValue=""
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

# function to read INI
# should just have the image dir to scan
# and then have a LOW and HIGH value

# function to scan image dir
    # find LOW and HIGH
    # write list of images to scan from later

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

    
    # 0 - 60,000 (or so) is about 5,000 an hour
    # which perceptually is a bit much, so maybe 4k for midnight to + 6
    # then 6k for the 6 hrs to noon, then back down
    if [ $currhour -le
0: 4000
1: 8000
2: 12000
3: 16000
4: 20000
5: 24000
6: 30000
7: 36000
8: 42000
9: 48000
10: 54000
11: 65000

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
