#!/bin/bash

NAME=$1

DIR1="/media/frznn/Movie DB"
DIR2="/media/frznn/Video/Film"
DIR3="/media/frznn/Download/MegaDownload"

find "$DIR1" "$DIR2" "$DIR3" -iname "*$NAME*"
