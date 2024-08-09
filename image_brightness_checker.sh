#!/bin/bash

# initializing arrays
export ImageFile=()
export ImageBright=()

if [ -d "${1}" ];then
    DIRECTORY="${1}"
else
    DIRECTORY="${PWD}"
fi

cd "${DIRECTORY}"
imgfiles=$(fdfind --exclude '*tile*' -a -0 -e jpg -e jpeg -e png | xargs --null -I {} realpath {} )

rm ~/imagebright.csv

while read -r line; do
    # echo "${line}"
    if [ -f "${line}" ];then 
        filename=$(basename "${line}")
        OIFS=$IFS
        IFS=$'\n'; set -f
        brightcolor=$(timeout 5 convert "${line}" -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
        # rounding the number, crudely.
        NUMBER=$(echo $brightcolor | awk '{ print $0 + .90 }')
        NUMBER=$(printf "%0.f" $NUMBER)
        ImageFile+=("${line}")
        ImageBright+=("${NUMBER}")
        printf "%s\t%s\t%s\n" "${filename}" "${brightcolor}" "${NUMBER}"
        printf "%s,%s,%s\n" "${line}" "${brightcolor}" "${NUMBER}" >> ~/imagebright.csv
        # adding for thumbnails for example 
        # this will eventually be the first thumbnailing and range run
        outfile=$(printf "/home/steven/test/%06d.jpg" "${NUMBER}")
        timeout 5 convert -resize 50x50! "${line}" "${outfile}"
        IFS=OIFS
    fi
done < <(echo "${imgfiles}")
# initial run to find full range (omitting missed and obviously false values)
# (600 - 60024)
# so here's what we do 
# - find whether the sun is up
# - find if it's overcast (maybe?)
# - choose appropriate brightness level range
# - find random file, test it's brightness. If within range, great! otherwise, repeat
