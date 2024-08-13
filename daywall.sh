#!/bin/bash

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
CacheFile=${CacheDir}/daywall.cache
CurrImageName=${CacheDir}/daywall_current
ImageDir=""
LOUD=0
 
 
if [[ "$@" == *"--help"* ]]; then
    echo "daywall.sh"
    echo "usage:  daywall.sh [directory] [OPTIONS]"
    echo " "
    echo "directory is optional if configuration file has the directory specified."
    echo "OPTIONS (must come after directory, if specified):"
    echo "--help: This."
    echo "--loud: extra output."
    exit 0
fi 
 
if [[ "$@" == *"--loud"* ]]; then
    LOUD=1
fi
########################################################################
# Functions
########################################################################

function loud() {
    if [ $LOUD -eq 1 ];then
        echo "$@"
    fi
}
    
function scan_directory() {
    # scan the directory in the ini file; if filename is not in our cache, analyze it and add
    # scan a directory passed in $1; if filename is not in our cache, analyze it AND ADD
    # write list of images to scan from later


    # This can be the "base" directory or one added on the fly; after the scan 
    # it doesn't matter.
    cd "${ImageDir}"
    
    if [ -f $(which fdfind) ];then 
        imgfiles=$(fdfind -a -0 -e jpg -e jpeg -e png | xargs --null -I {} realpath {} )
    else
        imgfiles=$(find . -iname "*.jpg" -or -iname "*.png" -or -iname "*.jpeg" | xargs -I {} realpath {} )
    fi
    while read -r line; do
        exist=0
        if [ -f "${line}" ];then 
            filename=$(basename "${line}")
            exist=$(grep -c "${filename}" "${CacheFile}")
            # we aren't rescanning things we already have, thanks
            if [ $exist -eq 0 ];then
                OIFS=$IFS
                IFS=$'\n'; set -f
                loud "Analyzing ${filename}"
                brightcolor=$(timeout 5 convert "${line}" -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
                # rounding the number, crudely.
                NUMBER=$(echo $brightcolor | awk '{ print $0 + .90 }')
                NUMBER=$(printf "%0.f" $NUMBER)
                if [ $NUMBER -gt 100 ];then
                    printf "%s,%s,%s\n" "${line}" "${brightcolor}" "${NUMBER}" >> "${CacheFile}"
                else
                    loud "## Probable error processing brightness of ${line}"
                    printf "%s,%s,%s\n" "${line}" "${brightcolor}" "${NUMBER}" >> "${CacheFile}"
                fi
                IFS=$OIFS
            fi
        fi
    done < <(echo "${imgfiles}")
}    
    
function clean_cache() {
    # go through ${CacheFile} line by line, and omit the lines with files that no longer exist
    loud "## Checking filenames in cache"
    if [ -f "${CacheFile}" ];then
        OIFS=$IFS
        IFS=$'\n'; set -f
        cleantemp=$(mktemp)
        cp "${CacheFile}" "${cleantemp}"
        rm "${CacheFile}"
        while read -r line; do
            filename=$(echo "${line}" | awk -F ',' '{print $1}')
            if [ -f "${filename}" ];then
                loud "${filename} still exists, adding."
                echo "${line}" >> "${CacheFile}"
            else
                loud "${filename} no longer present, omitting"
            fi
        done < <(cat "${cleantemp}")
        rm "${cleantemp}"
        IFS=$OIFS
    else
        loud "${CacheFile} does not exist, skipping clean."
    fi
}


function time_of_day() {
    # get geolocated coordinates

    if [ -z "$COORDS" ]; then 
        coords=$(curl -s https://whatismycountry.com/ | sed -e 's/picture/\n/g' -e 's/&#176;//g'  | grep "My coordinates" | awk -F '>' '{print $5}' | awk -F '<' ' {print $1}')
    else 
        coords="${COORDS}"
    fi
    
    # TODO: test to make sure that's not junk and we're connected to the internet
    lat=$(echo "${coords}" | awk -F ', ' '{ print $1 }')
    long=$(echo "${coords}" | awk -F ', ' '{ print $2 }')    
    
    sunrise=$(hdate -s -l "$lat" -L "$long" 2>/dev/null | grep "sunrise" | awk '{ print $2 }' | awk -F ':' '{ print $1 }')
    sunset=$(hdate -s -l "$lat" -L "$long" 2>/dev/null | grep "sunset" | awk '{ print $2 }' | awk -F ':' '{ print $1 }')
    
    # doing all the math with bc to be consistent here
    midday=$(echo "($sunset-$sunrise)/2+$sunrise" | bc)
    midnight=$(echo "($sunset-$sunrise)/2+$sunset" | bc)
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
    echo "${abs_time_diff};$highval;$lowval;$(date +%Y%m%d)${currhour} ; $(date +%Y%m%d)${midday};$(expr $(date +%Y%m%d)${currhour} - $(date +%Y%m%d)${midday})" >> ~/debugging.txt

    # Use awk to parse our filelist to find something in the appropriate range
    outfile=""
    while : ; do
        outfile=$(awk -F ',' -v highval="$highval" -v lowval="$lowval" '$3 <= highval && $3 >= lowval {print $1}' "${CacheFile}" | shuf | tail -1)
        test=0
        test=$(grep -c "$outfile" "${CurrImageName}")
        if [ $test -ge 1 ];then
            outfile=""
        fi
        if [ -f "${outfile}" ]; then
            break
        fi
        # check for its existence
        [[ -f "${outfile}" ]] || break
        # if nothing was found, expand lowval and highval before trying again.
        # that way we'll eventually catch something.
        lowval=$((lowval-100))
        highval=$((highval+100))
        # ensure we haven't exceeded our maximum and minimum possible values
        if [ $lowval -le 100 ];then
            lowval=100
        fi
        if [ $highval -ge 66500 ];then
            highval=66500
        fi
    done
    echo "${outfile}" > "${CurrImageName}"
    echo "${outfile}"
}

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
if [ ! -f "${CurrImageName}" ];then
    touch "${CurrImageName}"
fi
if [ -f "${ConfigFile}" ];then
    test=$(grep -c "DIR" "${ConfigFile}")
    if [ $test -gt 0 ];then
        ImageDir=$(realpath $(grep "DIR" "${ConfigFile}" | awk -F '=' '{print $2}'))
    fi
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

clean_cache

#TODO - have adding a directory add it to the ini file
#TODO - read multiple directories from the ini file

scan_directory
FileName=$(time_of_day)
loud "The randomly-selected file is: ${FileName}"
feh --bg-fill --no-xinerama "${FileName}"
