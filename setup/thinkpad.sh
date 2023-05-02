# Set ImpPt to Menu key (right click)
sudo apt install -y xkbset
xkbset m ## Necessary ?
xmodmap -e "keycode 107 = Menu"
xmodmap -pke > ~/.Xmodmap
echo "if [ -f $HOME/.Xmodmap ]; then
        /usr/bin/xmodmap $HOME/.Xmodmap
fi" >> ~/.xinitrc
