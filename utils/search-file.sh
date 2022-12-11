#!/bin/bash

WORD1=$1
WORD2=$2
WORD3=$3

DIR1="/etc/"
DIR2="/home/"
DIR3="/media/"
DIR4="/mnt/"
DIR5="/opt/"

printFormat="%-100s %-30s\n"
printf "${printFormat}" "File" "Path"
printf "${printFormat}" "========================================" "========================================"

# Find matching files and print in columns
find "$DIR1" "$DIR2" "$DIR3" "$DIR4" "$DIR5" -iname "*$WORD1*$WORD2*$WORD3" | \
while read filename
do
    path=`dirname "$filename"`
    file=`basename "$filename"`

    printf "${printFormat}" "$file" "$path"
done
