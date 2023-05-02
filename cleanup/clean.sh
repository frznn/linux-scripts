#!/bin/sh

#Check the Drive Space Used by Cached Files
du -sh /var/cache/apt/archives

#Delete cache file older than 30 days
find ~/.cache/ -type f -atime +30 -delete

#Clean all the log file
#for logs in `find /var/log -type f`;  do > $logs; done

logs=`find /var/log -type f`
for i in $logs
do
> $i
done

#Getting rid of partial packages
sudo apt clean && apt autoclean
sudo apt autoremove -y

#Getting rid of orphaned packages
deborphan | xargs sudo apt-get -y remove --purge

#Free up space by clean out the cached packages
apt-get clean

# Remove old logs
sudo journalctl --vacuum-time=7days

# Remove the Trash
rm -rf /home/*/.local/share/Trash/*/**
rm -rf /root/.local/share/Trash/*/**

# Remove Man
rm -rf /usr/share/man/?? 
rm -rf /usr/share/man/??_*

#Delete all .gz and rotated file
find /var/log -type f -regex ".*\.gz$" | xargs rm -Rf
find /var/log -type f -regex ".*\.[0-9]$" | xargs rm -Rf

#Cleaning the old kernels
dpkg-query -l|grep linux-im*
#dpkg-query -l |grep linux-im*|awk '{print $2}'
apt-get purge $(dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | head -n -1) --assume-yes
apt-get install linux-headers-`uname -r|cut -d'-' -f3`-`uname -r|cut -d'-' -f4`

# Clean cache folder
rm -rf $HOME/.cache/*

#Cleaning is completed
echo "Cleaning is completed"
