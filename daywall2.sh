#!/bin/bash

 ########################################################################
 # 
 #   Daywall2 - A time/brightness based background changer
 #   by Steven Saus (c)2025
 #   Licensed under the MIT license
 #
 # Normal output is *just* the selected filename, which can be fed into 
 # whatever you use to set your background, e.g. 
 # feh --bg-fill --no-xinerama $(./daywall2.sh) 
 #
 # Or you can hardcode it in.
 # 
 # THE BACKGROUND WILL BE PUT IN $XDG_CACHE_HOME/daywall_darkened.jpg
 ########################################################################

########################################################################
# Definitions
########################################################################

CacheDir="${XDG_CACHE_HOME:-$HOME/.local/state}"
export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOUD=0
high=""
low=""
lat=""
long=""
dirs=()

 
show_help (){
    echo "daywall2.sh"
    echo "usage:  daywall2.sh [OPTIONS]"
    echo " "
    echo "directory is optional, defaults to ${PWD}."
    echo "OPTIONS:"
    echo "--help    This."
    echo "--loud    Provide extra output."
    echo "--high    Maximum high value for brightness"
    echo "--low     Minimum low value for brightness"
    echo "--dirs    directories to recursively search for files"
    echo "--cords   Your coordinates to avoid lookup"
}

########################################################################
# Functions
########################################################################

# loud outputs on stderr 
function loud() {
    if [ $LOUD -eq 1 ];then
        echo "$@" 1>&2
    fi
}

find_image () {
  local image
  imagelist=$(find "$@" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort | uniq )
  image=$(echo "$imagelist" | shuf -n 1)
  echo "${image}"
}
 
 
# Function to adjust the brightness of the image to fall within the desired range
adjust_brightness() {
    local filename="${1}"
    local low_range="${3}"
    local high_range="${2}"
    local percent=0  # leave at 0
    local percentup=5  # Amount to darken the image in each step
    local brightcolor
    local current_brightness
    local darker_filename="${CacheDir}/daywall_darkened.jpg"

    # Get the current brightness of the image
    brightcolor=$(timeout 5 convert "${filename}" -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
    current_brightness=$(echo $brightcolor | awk '{print int($1)}')

    loud "[info] Current brightness: $current_brightness"
    loud "[info] high range = $high_range"
    loud "[info] low = $low_range"
    # If brightness is within range, no adjustment is needed
    if (( current_brightness >= low_range && current_brightness <= high_range )); then
        loud "[info] Brightness is within the acceptable range."
        convert "${filename}" "${darker_filename}"
        loud "[info] Returning original image as darkened image: ${darker_filename}"
        return 0
    fi

    # If brightness is too low, brighten the image
    if (( current_brightness < low_range )); then
        loud "[info] Brightness is too low, brightening the image..."

        # Iteratively brighten the image until it's within the range
        while (( current_brightness < low_range )); do
            (( percent += percentup ))
            convert "${filename}" -brightness-contrast ${percent}x${percent} "${darker_filename}"
            #convert "${filename}" -fill white -colorize ${percent}% "${darker_filename}"
            brightcolor=$(timeout 5 convert "${darker_filename}" -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
            current_brightness=$(echo "${brightcolor}" | awk '{print int($1)}')
            loud "[info] Adjusted brightness: ${current_brightness}"
        done
    fi


    # If brightness is too high, darken the image
    if (( current_brightness > high_range )); then
        loud "[info] Brightness is too high, darkening the image..."

        # Iteratively darken the image until it's within the range
        while (( current_brightness > high_range )); do
            (( percent+=$percentup ))
            convert "${filename}" -brightness-contrast -${percent}x-${percent} "${darker_filename}"
            #convert "${filename}" -fill black -colorize ${percent}% "${darker_filename}"
            brightcolor=$(timeout 5 convert "${darker_filename}" -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
            current_brightness=$(echo $brightcolor | awk '{print int($1)}')
            loud "[info] Adjusted brightness: $current_brightness"
        done
    fi

    # Return the new darkened image filename
    loud "[info] Darkened image saved as: ${darker_filename}"
}
 

function locale_time_brightness () {
    local highval=""
    local lowval=""

    # TODO: test to make sure that's not junk and we're connected to the internet
    lat=$(echo "${coords}" | awk -F ', ' '{ print $1 }')
    long=$(echo "${coords}" | awk -F ', ' '{ print $2 }')    
    sunrise=$(hdate -s -l "$lat" -L "$long" 2>/dev/null | grep "sunrise" | awk '{ print $2 }' | awk -F ':' '{ print $1 }')
    sunset=$(hdate -s -l "$lat" -L "$long" 2>/dev/null | grep "sunset" | awk '{ print $2 }' | awk -F ':' '{ print $1 }')
    
    # doing all the math with bc to be consistent here
    midday=$(echo "($sunset-$sunrise)/2+$sunrise" | bc)
    midnight=$(echo "($sunset-$sunrise)/2+$sunset" | bc)

    re='^[0-9]+$'
    if ! [[ $midnight =~ $re ]] ; then
        midnight=23
    fi
    if ! [[ $midnight =~ $re ]] ; then
        midday=11
    fi
    
    if [ $midnight -gt 23 ];then
        midnight=$(echo "$midnight-24" | bc)
    fi
    
    # where is current hour in comparison to midday
    # You need the printf because otherwise the time_diff calculation is WRONG.
    currhour=$(printf "%02.f" $(date "+%-H"))
    time_diff=$(expr $(date +%Y%m%d)${currhour} - $(date +%Y%m%d)${midday})
    abs_time_diff=${time_diff#-}
    # map the high and low value for the image for the appropriate time
    # THESE ARE THE BRIGHTNESS VALUES TO EDIT
    # 0 is MID-DAY
    case "${abs_time_diff}" in
        0)  highval=65000    
            lowval=54000
            ;;
        1)  highval=54000
            lowval=47000
            ;;
        2)  highval=47000
            lowval=38000
            ;;
        3)  highval=38000
            lowval=30000
            ;;
        4)  highval=30000
            lowval=23000
            ;;
        5)  highval=23000
            lowval=17000
            ;;
        6)  highval=17000
            lowval=12000
            ;;
        7)  highval=12000
            lowval=9000
            ;;
        8)  highval=9000
            lowval=6000
            ;;
        9)  highval=6000
            lowval=4500
            ;;
        10) highval=4500
            lowval=3000
            ;;
        11) highval=3000
            lowval=1500
            ;;
        12) highval=1500
            lowval=200
            ;;
        *)  highval=2000
            lowval=200
            ;;
    esac
    printf "%s\t%s" "$highval" "$lowval"
}


################################################################################
#  Main, beginning with argument parsing
################################################################################

# Argument parsing loop
while [[ $# -gt 0 ]]; do
  case "$1" in
    --loud)
      LOUD=1
      shift
      ;;
    --high)
      higharg="$2"
      shift 2
      ;;
    --low)
      lowarg="$2"
      shift 2
      ;;
    --lat)
      lat="$2"
      shift 2
      ;;
    --long)
      long="$2"
      shift 2
      ;;
    --dirs)
      shift
      while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
        dirs+=$(realpath "${1}")
        shift
      done
      ;;
    *)
      echo "Unknown argument: $1"
      shift
      ;;
  esac
done

if [ -z "${dirs}" ];then
    dirs+=$(realpath "${PWD}")
fi

# If already specified by env and not on command line, no problemo.
if [ "$lat" != "" ] && [ "$long" != "" ];then
    COORDS=$(echo "$lat, $long")
else
    # get geolocated coordinates
    if [ -z "$COORDS" ]; then 
        coords=$(curl -s https://whatismycountry.com/ | sed -e 's/picture/\n/g' -e 's/&#176;//g'  | grep "My coordinates" | awk -F '>' '{print $5}' | awk -F '<' ' {print $1}')
    else 
        coords="${COORDS}"
    fi
fi

# get the location and time based brightness levels, compare against 
# what the user wants. 
read high low < <(locale_time_brightness)


if [[ "$higharg" != "" ]] && [[ "$higharg" -lt "$high" ]]; then
    high="${higharg}"
fi
if [[ "$lowarg"  != "" ]] && [[ "$lowarg" -gt "$low" ]]; then
    low="${lowarg}"
fi
if [[ "$low" -gt 65000 ]];then
    low=61000
fi

if [[ "$high" -lt "$low" ]];then
    if [[ "$high" -gt 4000 ]];then
        low=$((high-3500))
    else
        low=200
    fi
fi

source_image=$(find_image "${dirs[@]}")
adjust_brightness "${source_image}" "${high}" "${low}"
echo "${CacheDir}/daywall_darkened.jpg" &
#feh --bg-fill --no-xinerama "${CacheDir}/daywall_darkened.jpg"


