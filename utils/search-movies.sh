#!/bin/bash

NAME=$1

DIR1=""
DIR2=""
DIR3=""

find "$DIR1" "$DIR2" "$DIR3" -iname "*$NAME*"
