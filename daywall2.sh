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
nobr=""
nodrk=""
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
    echo "--nobr    Not brighten images"
    echo "--nodrk   Not darken images"
    echo "--image [path]  Adjust a specific image"
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

    loud "[info] adjust_brightness called on: ${filename}"
    loud "[info] Target brightness range: low=${low_range} high=${high_range}"
    loud "[info] Output file: ${darker_filename}"

    # Get the current brightness of the image
    # this is for imagemagick 7
    loud "[info] Running: magick identify -format \"%[fx:quantumrange*mean]\" -colorspace Gray \"${filename}\""
    brightcolor=$(timeout 5 magick identify -format "%[fx:quantumrange*mean]" -colorspace Gray "${filename}")
    #below is for imagemagick 6
    #brightcolor=$(timeout 5 convert "${filename}" -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
    if [ -z "${brightcolor}" ]; then
        loud "[warning] magick identify returned empty result for ${filename} (timeout or error), skipping adjustment."
        return 1
    fi
    current_brightness=$(echo $brightcolor | awk '{print int($1)}')

    loud "[info] Measured brightness: ${current_brightness} (raw: ${brightcolor})"
    loud "[info] High range = ${high_range}, Low range = ${low_range}"

    # If brightness is within range, no adjustment is needed
    if (( current_brightness >= low_range && current_brightness <= high_range )); then
        loud "[info] Brightness is within the acceptable range, copying unchanged."
        loud "[info] Running: cp -f \"${filename}\" \"${darker_filename}\""
        cp -f "${filename}" "${darker_filename}"
        loud "[info] Copied original image to: ${darker_filename}"
        return 0
    fi

	if [ -z "${nobr}" ]; then
		# If brightness is too low, brighten the image
		if (( current_brightness < low_range )); then
			loud "[info] Brightness ${current_brightness} is below low threshold ${low_range}, brightening..."
			factor=1.0
			local bright_iters=0
			# Iteratively brighten the image until it's within the range
			while (( current_brightness < low_range )); do
				# Increase factor by percentup percent each loop (e.g. 5 -> +5%)
				factor=$(awk -v f="${factor}" -v step="${percentup}" 'BEGIN{print f*(1+step/100)}')

				loud "[info] Brighten iter ${bright_iters}: factor=${factor}, running: magick \"${filename}\" -colorspace RGB -evaluate Multiply ${factor} \"${darker_filename}\""
				# ImageMagick 7
				timeout 30 magick "${filename}" -colorspace RGB -evaluate Multiply "${factor}" "${darker_filename}"
				if [ $? -ne 0 ]; then
					loud "[warning] magick transform timed out or failed on brightening iter ${bright_iters}, stopping."
					break
				fi

				# ImageMagick 6 equivalent:
				#convert "${filename}" -colorspace RGB -evaluate Multiply "${factor}" "${darker_filename}"

				loud "[info] Running: magick identify -colorspace Gray -format \"%[fx:quantumrange*mean]\" \"${darker_filename}\""
				brightcolor=$(timeout 5 magick identify -colorspace Gray -format "%[fx:quantumrange*mean]" "${darker_filename}")
				#brightcolor=$(timeout 5 convert "${darker_filename}" -colorspace Gray -format "%[fx:quantumrange*mean]" info:)
				if [ -z "${brightcolor}" ]; then
					loud "[warning] magick identify returned empty result on brightening iter ${bright_iters}, stopping."
					break
				fi

				current_brightness=$(echo "${brightcolor}" | awk '{print int($1)}')
				loud "[info] Brightening iter ${bright_iters}: adjusted brightness=${current_brightness}, factor=${factor}"

				# Safety: stop if factor is getting extreme (pixels are clipping, mean won't rise further)
				if awk -v f="${factor}" 'BEGIN{exit (f > 5) ? 1 : 0}'; then : ; else
					loud "[warning] Brightening factor ${factor} exceeded 5.0 (pixel clipping), stopping."
					break
				fi
				(( bright_iters++ ))
				if (( bright_iters >= 100 )); then
					loud "[warning] Brightening loop safety limit of 100 iterations reached, stopping."
					break
				fi
			done
			loud "[info] Brightening complete: final brightness=${current_brightness}, factor=${factor}, iterations=${bright_iters}"
		else
			loud "[info] No brightening needed."
			cp -f "${filename}" "${darker_filename}"
		fi
	else
		loud "[info] --nobr set, skipping brightening, copying file." # because if it's somehow too bright AND too dark, something wrong
		cp -f "${filename}" "${darker_filename}"
	fi

	if [ -z "${nodrk}" ]; then		
		if (( current_brightness > high_range )); then
			loud "[info] Brightness ${current_brightness} is above high threshold ${high_range}, darkening..."
			factor=1.0
			local dark_iters=0
			while (( current_brightness > high_range )); do
				# Reduce by a step, e.g. 5% per iteration
				factor=$(awk -v f="${factor}" -v step="${percentup}" 'BEGIN{print f*(1-step/100)}')

				loud "[info] Darken iter ${dark_iters}: factor=${factor}, running: magick \"${filename}\" -colorspace RGB -evaluate Multiply ${factor} \"${darker_filename}\""
				timeout 30 magick "${filename}" -colorspace RGB -evaluate Multiply "${factor}" "${darker_filename}"
				if [ $? -ne 0 ]; then
					loud "[warning] magick transform timed out or failed on darkening iter ${dark_iters}, stopping."
					break
				fi

				loud "[info] Running: magick identify -colorspace Gray -format \"%[fx:quantumrange*mean]\" \"${darker_filename}\""
				brightcolor=$(timeout 5 magick identify -colorspace Gray -format "%[fx:quantumrange*mean]" "${darker_filename}")
				if [ -z "${brightcolor}" ]; then
					loud "[warning] magick identify returned empty result on darkening iter ${dark_iters}, stopping."
					break
				fi
				current_brightness=$(echo "${brightcolor}" | awk '{print int($1)}')

				loud "[info] Darkening iter ${dark_iters}: adjusted brightness=${current_brightness}, factor=${factor}"

				# Safety: stop if factor is negligibly small (image is near black, won't darken further)
				if awk -v f="${factor}" 'BEGIN{exit (f < 0.01) ? 1 : 0}'; then : ; else
					loud "[warning] Darkening factor ${factor} dropped below 0.01 (near black), stopping."
					break
				fi
				(( dark_iters++ ))
				if (( dark_iters >= 100 )); then
					loud "[warning] Darkening loop safety limit of 100 iterations reached, stopping."
					break
				fi
			done
			loud "[info] Darkening complete: final brightness=${current_brightness}, factor=${factor}, iterations=${dark_iters}"
		else
			loud "[info] No darkening needed."
			cp -f "${filename}" "${darker_filename}"
		fi
	else
		loud "[info] --nodrk set, skipping darkening."
		cp -f "${filename}" "${darker_filename}"
	fi

    loud "[info] Adjusted image saved as: ${darker_filename}"
}


function locale_time_brightness () {
    local highval=""
    local lowval=""

    # TODO: test to make sure that's not junk and we're connected to the internet
    lat=$(echo "${coords}" | awk -F ', ' '{ print $1 }')
    long=$(echo "${coords}" | awk -F ', ' '{ print $2 }')

    # Check if coordinates are valid before calling hdate
    if [ -n "$lat" ] && [ -n "$long" ]; then
        sunrise=$(hdate -s -l "$lat" -L "$long" 2>/dev/null | grep "sunrise" | awk '{ print $2 }' | awk -F ':' '{ print $1 }')
        sunset=$(hdate -s -l "$lat" -L "$long" 2>/dev/null | grep "sunset" | awk '{ print $2 }' | awk -F ':' '{ print $1 }')
    else
        loud "[warning] Invalid or missing coordinates, using defaults"
        sunrise=""
        sunset=""
    fi

    # Check if sunrise/sunset are valid before doing math
    if [ -n "$sunrise" ] && [ -n "$sunset" ]; then
        # doing all the math with bc to be consistent here
        midday=$(echo "($sunset-$sunrise)/2+$sunrise" | bc)
        midnight=$(echo "($sunset-$sunrise)/2+$sunset" | bc)
    else
        loud "[warning] Failed to get sunrise/sunset times, using defaults"
        midday=12
        midnight=0
    fi

    re='^[0-9]+$'
    if ! [[ $midnight =~ $re ]] ; then
        midnight=23
    fi
    if ! [[ $midday =~ $re ]] ; then
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
    loud "[info] Time differential is $abs_time_diff"

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
    --image)
    shift
      if [ -f "${1}" ];then
        source_image="${1}"
      fi
      shift
      ;;
    --nobr)
        export nobr=1
        shift
        ;;
    --nodrk)
        export nodrk=1
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
    --cords)
      COORDS="$2"
      shift 2
      ;;
    --dirs)
      shift
      while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
        dirs+=("$(realpath "${1}")")
        shift
      done
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      show_help
      exit 1
      ;;
  esac
done

if [ ${#dirs[@]} -eq 0 ];then
    dirs+=("$(realpath "${PWD}")")
fi

# If already specified by env and not on command line, no problemo.
if [ "$lat" != "" ] && [ "$long" != "" ];then
    COORDS=$(echo "$lat, $long")
else
    # get geolocated coordinates
    if [ -z "$COORDS" ]; then
        coords=$(curl -s https://whatismycountry.com/ | grep -oE '[0-9]+\.[0-9]+, -[0-9]+\.[0-9]+' | head -1)
    else
        coords="${COORDS}"
    fi
fi

# get the location and time based brightness levels, compare against
# what the user wants.
read high low < <(locale_time_brightness)


if [[ "$higharg" != "" ]]; then
	if [[ "$higharg" -lt "$high" ]];then
		high="${higharg}"
	fi
fi
if [[ "$lowarg"  != "" ]]; then
	if [[ "$lowarg" -gt "$low" ]];then
		low="${lowarg}"
	fi
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

#if it was passed from the command line
if [ "$source_image" != "" ];then
    loud "[info] Using source image: ${source_image}"
else
    source_image=$(find_image "${dirs[@]}")
fi
adjust_brightness "${source_image}" "${high}" "${low}"
echo "${CacheDir}/daywall_darkened.jpg" &
#feh --bg-fill --no-xinerama "${CacheDir}/daywall_darkened.jpg"
