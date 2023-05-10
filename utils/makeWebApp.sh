#!/bin/bash

# Check is nativefier is installed
if ! [ -x "$(command -v nativefier)" ]; then
  echo 'Error: nativefier is not installed.' >&2
  exit 1
fi

if [ $# -lt 2 ]; then
    echo "USAGE: $0 NAME WEBSITE"
    exit 1
fi

NAME=$1
WEBSITE=$2

nativefier --name $NAME --platform linux --arch x64 --width 1024 --height 768--tray --disable-dev-tools  --single-instance $WEBSITE

mv "$NAME-linux-x64" "$NAME"

cd $NAME
path=$(pwd)

echo "[Desktop Entry]
Type=Application
Name=$NAME
Path=$path
Exec=$path/$NAME
Icon=$path/resources/app/icon.png" > $NAME.desktop

sudo desktop-file-install $NAME.desktop

#TODO: uninstall
# /usr/share/applications
# rm APP.desktop
