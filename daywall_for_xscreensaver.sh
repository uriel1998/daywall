#!/bin/bash

 ########################################################################
 # 
 #   A wrapper for daywall to copy appropriate images to the 
 #   images directory for xscreensaver 
 #   Use convert (from imagemagick) so you don't have to worry about the 
 #   type of image.  It has to be the same names in the temp dir because
 #   xscreensaver does not re-read the directory after start.
 #   (you are responsible for configuring xscreensaver!)
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
export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
 
#  NOTE:  THIS SHOULD BE HARD CODED since cron's gonna run it.
SCREENSAVERDIR=/home/steven/tmp/daywall_screensaver

if [ ! -d "${SCREENSAVERDIR}" ];then
    mkdir -p "${SCREENSAVERDIR}"
fi


CURR_FILE_LIST=""






# find and delete files in the specified directory
find "${SCREENSAVERDIR}" -maxdepth 1 -iname "*daywall_screensaver_*" -type f -delete
counter=0
while [ $counter -lt 9 ]; do
    file=$("${SCRIPT_DIR}"/daywall.sh --no-update)
    #  If it's already been chosen in this round, kick it back
    if [[ $CURR_FILE_LIST == *"$file"* ]];then 
        file=""
    fi
    
    if [ -f "${file}" ];then 
        CURR_FILE_LIST+="$file"
        convert "${file}" "${SCREENSAVERDIR}"/daywall_screensaver_"${counter}".jpg
        ((counter++))
    fi
    # then call this once an hour or so
done
