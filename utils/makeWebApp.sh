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

ARGS=""
#ARGS="--disable-dev-tools"
#ARGS="--tray"
#DRM="-e 15.3.5 --widevine"

nativefier --name $NAME --platform linux --arch x64 --width 1024 --height 768 --disable-dev-tools --single-instance $WEBSITE

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

exit 0

#TODO: uninstall
APP=
rm /usr/share/applications/$APP.desktop
rm $HOME/.local/share/applications/$APP.desktop

# rm cache:
#make APP lowercase
rm -rf ~/.config/$APP-nativefier-*
