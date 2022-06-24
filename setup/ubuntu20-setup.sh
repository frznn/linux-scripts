
sudo apt update -y
sudo apt upgrade -y

sudo apt install curl software-properties-common apt-transport-https
# VLC, media codecs, fonts
sudo apt install vlc ubuntu-restricted-extras libdvd-pkg ubuntu-restricted-addons
sudo dpkg-reconfigure libdvd-pkg
# Gnome Tweak tools
sudo apt install gnome-tweak-tool dconf-editor

# Enable AppImages
sudo apt-get install fuse libfuse2
# Install AppImageLauncher
sudo add-apt-repository ppa:appimagelauncher-team/stable
sudo apt update
sudo apt install appimagelauncher

# Timeshift - creates filesystem snapshot to disaster recovery
sudo add-apt-repository -y ppa:teejee2008/ppa
sudo apt-get update
sudo apt-get install timeshift

# Ubuntu Cleaner
sudo add-apt-repository ppa:gerardpuig/ppa
sudo apt-get update
sudo apt-get install ubuntu-cleaner

# Download Bitwarden (from store)

# Install Brave
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list

sudo apt update
sudo apt install brave-browser

# Install Spotify
curl -sS https://download.spotify.com/debian/pubkey_5E3C45D7B312C643.gpg | sudo apt-key add - 
echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
sudo apt-get update && sudo apt-get install spotify-client


# Work
sudo apt install git terminator guake chromium-browser
# Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb

# Insync
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C
echo "deb http://apt.insync.io/ubuntu focal non-free contrib"  | sudo tee /etc/apt/sources.list.d/spotify.list
sudo apt-get update
sudo apt-get install insync

# TexStudio
sudo add-apt-repository ppa:sunderme/texstudio
sudo apt update
sudo apt-get install texlive texstudio # for latex 
sudo apt-get install texlive-full 

# Inkscape
sudo apt install inkscape


# Manual settings:

# Xkill shortcut
# Open Settings → Keyboard Shortcuts → Scroll to the bottom → Click on + button to add a new shortcut → Set name and command to xkill → Set Shortcut → Press keyboard keys to set shortcut (I use CTRL + Esc) -- to kill an app, press ctrl+esc and then click on the window to close
