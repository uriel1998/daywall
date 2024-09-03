#!/bin/bash

 ########################################################################
 # 
 #   A wrapper for daywall to symlink appropriate images to the 
 #   images directory for xscreensaver 
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
 
SCREENSAVERDIR=~/tmp/daywall_screensaver

if [ ! -d "${SCREENSAVERDIR}" ];then
    mkdir -p "${SCREENSAVERDIR}"
fi

# find and delete ONLY SYMLINKS in the specified directory
find "${SCREENSAVERDIR}" -maxdepth 1 -type l -delete
counter=0
while [ $counter -lt 9 ]; do
    file=$("${SCRIPT_DIR}"/daywall.sh)
    justname=$(basename "${file}")
    ln -sf "${file}" "${SCREENSAVERDIR}"/"${justname}"
    # start a loop (say 5-10 times)
    # call daywall.sh
    # create a symlink with what daywall returns to the specified directory
    # repeat
    # then call this once an hour or so
    ((counter++))

done
