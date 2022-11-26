#!/bin/bash

WORD1=$1
WORD2=$2
WORD3=$3

DIR1="/etc/"
DIR2="/media/"
DIR3="/usr/"

find "$DIR1" "$DIR2" "$DIR3" -iname "*$WORD1*$WORD2*$WORD3"

