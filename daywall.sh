#!/bin/sh

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
