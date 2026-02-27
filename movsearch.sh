#!/bin/bash

WORD1=$1
WORD2=$2
WORD3=$3

DIR1="/media/frznn/Movie DB"
DIR2="/media/frznn/Video/Film"
DIR3="/media/frznn/Download/MegaDownload"


repeat(){
	local start=1
	local end=${1:-80}
	local str="${2:-=}"
	local range=$(seq $start $end)
	for i in $range ; do echo -n "${str}"; done
}


clear
echo ""

# Print Header
termWidth=$(tput cols)
halfWidth=$(expr $termWidth / 2)
lineWidth=$(expr $halfWidth - 1)

printFormat="%-${halfWidth}s %-${halfWidth}s\n"
#printLine=$(printf -- '=%.0s' {1..$halfWidth})
printLine=$(repeat $lineWidth '='; echo)
printf "${printFormat}" "File" "Path"
printf "${printFormat}" "${printLine}" "${printLine}"

# Find matching files and print in columns
#find: filter out: -not \( -name '*.swp' -o -path './es*' -o -path './en*' \)
find "$DIR1" "$DIR2" "$DIR3" -iname "*$WORD1*$WORD2*$WORD3" -not \( -name '*.lnk' \)  | \
while read filename
do
    path=`dirname "$filename"`
    file=`basename "$filename"`

    printf "${printFormat}" "${file:0:lineWidth}" "${path:0:lineWidth}"
done

echo ""
