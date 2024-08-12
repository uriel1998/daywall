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
# Set up config, get image directory to scan
########################################################################

if [ ! -d "${ConfigDir}" ];then
    mkdir -p "${ConfigDir}"
fi
if [ ! -d "${CacheDir}" ];then
    mkdir -p "${CacheDir}"
fi

if [ ! -f "${CacheFile}" ];then
    touch "${CacheFile}"
fi

if [ -f "${ConfigFile}" ];then
    ImageDir=$(realpath $(grep "DIR" "${ConfigFile}" | awk -F '=' '{print $2}'))
else
    touch "${ConfigFile}"
    # If the config file is empty, then a directory to scan MUST be presented.
    if [ ! -d "{$1}" ];then
        echo "Configuration file was not present (now created); no directory to scan"
        echo "presented on command line. Exiting."
        exit 99
    fi
fi
# REPLACE ImageDir if specified on command line

if [ -d "${1}" ];then
    ImageDir="${1}"
    loud "Adding ${ImageDir}"
fi


if [ ! -d "${ImageDir}" ];then
    echo "ERROR: Image Directory To Scan Is Not Present."
    exit 98
fi


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

# function to scan image dir
    # scan the directory in the ini file; if filename is not in our cache, analyze it and add
    # scan a directory passed in $1; if filename is not in our cache, analyze it AND ADD
    # write list of images to scan from later
    
function scan_directory() {
    # This can be the "base" directory or one added on the fly; after the scan 
    # it doesn't matter.
    cd "${ImageDir}"
    
    # TODO:  Rewrite for regular "find" if fdfind isn't present
    imgfiles=$(fdfind --exclude '*tile*' -a -0 -e jpg -e jpeg -e png | xargs --null -I {} realpath {} )

    while read -r line; do
        exist=0
        if [ -f "${line}" ];then 
            filename=$(basename "${line}")
            exist=$(grep -c "${filename}" "${CacheFile}")
            # we aren't rescanning things we already have, thanks
            if [ $exist -eq 0 ];then
                OIFS=$IFS
                IFS=$'\n'; set -f
                brightcolor=$(timeout 5 convert "${line}" -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
                # rounding the number, crudely.
                NUMBER=$(echo $brightcolor | awk '{ print $0 + .90 }')
                NUMBER=$(printf "%0.f" $NUMBER)
                printf "%s,%s,%s\n" "${line}" "${brightcolor}" "${NUMBER}" >> "${CacheFile}"
                # adding for thumbnails for example 
                # this will eventually be the first thumbnailing and range run
                outfile=$(printf "/home/steven/test/%06d.jpg" "${NUMBER}")
                timeout 5 convert -resize 50x50! "${line}" "${outfile}"
                IFS=OIFS
            fi
        fi
    done < <(echo "${imgfiles}")
}    
    
function clean_cache() {
    # TODO: basically go through ${CacheFile} line by line, and omit the lines
    # with files that no longer exist
    
}


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
    
    # Use awk to parse our filelist to find something in the appropriate range
    outfile=""
    while : ; do
        outfile=$(awk -F ',' -v highval="$highval" -v lowval="$lowval" 'BEGIN $3 <= highval && $3 >= lowval {print $1}' "${CacheFile}" | shuf | tail -1)
        # check for its existence
        [[ -f "${outfile}" ]] || break
    done
    echo "${outfile}"
}


scan_directory


echo "The randomly-selected file is: $(time_of_day)"

