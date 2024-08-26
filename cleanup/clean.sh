#!/bin/sh


remove_old_kernels () {
  IN_USE=$(uname -a | awk '{ print $3 }')
  echo "Your in use kernel is $IN_USE"

  OLD_KERNELS=$(
      dpkg --list |
          grep -v "$IN_USE" |
          grep -Ei 'linux-image|linux-headers|linux-modules' |
          awk '{ print $2 }'
  )
  echo "Old Kernels to be removed:"
  echo "$OLD_KERNELS"

  yes | apt purge  $OLD_KERNELS
}

sudo remove_old_kernels

echo "Old Kernels Removed ($?)"


#Check the Drive Space Used by Cached Files
sudo du -sh /var/cache/apt/archives

#Delete cache file older than 30 days
echo "Delete old cache files"
sudo find ~/.cache/ -type f -atime +30 -delete

#Clean all the log file
#for logs in `find /var/log -type f`;  do > $logs; done
echo "Clean log files"
logs=`sudo find /var/log -type f`
for i in $logs
do
sudo rm -f $i
done

#Delete all .gz and rotated file
sudo find /var/log -type f -regex ".*\.gz$" | xargs sudo rm -Rf
sudo find /var/log -type f -regex ".*\.[0-9]$" | xargs sudo rm -Rf


#Getting rid of orphaned packages
#TODO: check if deborphan is installed
echo "Clean orphan packages"
deborphan | xargs sudo apt-get -y remove --purge

#Free up space by clean out the cached packages
#Getting rid of partial packages
echo "Clean APT"
sudo apt clean && sudo apt autoclean
# sudo apt autoremove   ## this removes too much stuff (e.g. build-essential)

# Remove old logs
echo "Remove old journal logs"
sudo journalctl --vacuum-time=7days

# Remove the Trash
echo "Empty trash"
rm -rf /home/*/.local/share/Trash/*/**
sudo rm -rf /root/.local/share/Trash/*/**

# Remove Man
#rm -rf /usr/share/man/?? 
#rm -rf /usr/share/man/??_*


#Cleaning the old kernels
#dpkg-query -l|grep linux-im*
#dpkg-query -l |grep linux-im*|awk '{print $2}'
#sudo apt-get purge $(dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | head -n -1) --assume-yes
#sudo apt-get install linux-headers-`uname -r|cut -d'-' -f3`-`uname -r|cut -d'-' -f4`

# Clean cache folder
echo "Clean cache folder"
rm -rf $HOME/.cache/*

#Cleaning is completed
echo "Cleaning is completed"

#################################################################


