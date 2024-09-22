#!/bin/bash

 ########################################################################
 # 
 #   Daywall - A time/brightness based background changer
 #   by Steven Saus (c)2024
 #   Licensed under the MIT license
 #
 # Normal output is *just* the selected filename, which can be fed into 
 # whatever you use to set your background, e.g. 
 # feh --bg-fill --no-xinerama $(./daywall.sh) 
 #
 #
 ########################################################################

########################################################################
# Definitions
########################################################################

ConfigDir=${XDG_CONFIG_HOME:-$HOME/.config}
CacheDir=${XDG_CACHE_HOME:-$HOME/.local/state}
ConfigFile=${ConfigDir}/daywall.ini
CacheFile=${CacheDir}/daywall.cache
CurrImageName=${CacheDir}/daywall_current
ImageDir=""
LOUD=0
DARKEN=0 
UPDATE=1
 
if [[ "$@" == *"--help"* ]]; then
    echo "daywall.sh"
    echo "usage:  daywall.sh [directory] [OPTIONS]"
    echo " "
    echo "directory is optional if configuration file has the directory specified."
    echo "OPTIONS (must come after directory, if specified):"
    echo "--help    This."
    echo "--darker  Darken the image further"
    echo "--loud    Provide extra output."
    echo "--no-update Don't update the files for a quicker run."
    exit 0
fi 

if [[ "$@" == *"--no-update"* ]]; then
    UPDATE=0
fi

 
if [[ "$@" == *"--loud"* ]]; then
    LOUD=1
fi
if [[ "$@" == *"--darken"* ]]; then
    DARKEN=1
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

    # TODO - have adding a directory add it to the ini file
    # TODO - read multiple directories from the ini file

if [ $UPDATE -eq 1 ];then

    clean_cache
    scan_directory
fi    
FileName=$(time_of_day)
loud "The randomly-selected file is: ${FileName}"

# Normal output is *just* the selected filename, which can be fed into 
# whatever you use to set your background, e.g. 
# feh --bg-fill --no-xinerama $(./daywall.sh) 
#
if [ "${DARKEN}" = "1" ];then
        DARKEN=$(mktemp)
        convert "${FileName}" -fill black -colorize 75% "${DARKEN}"
        # because otherwise it ends up filling tmp with old versions!
        cp -f "${DARKEN}" "$TMP/darker_bg.jpg"
        rm "${DARKEN}"
        # feh --bg-fill --no-xinerama "$TMP/darker_bg.jpg" 
        echo "$TMP/darker_bg.jpg"
else
    echo "${FileName}"
    # feh --bg-fill --no-xinerama "${FileName}"
fi

