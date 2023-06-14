#NPM
npm cache clean --force

#Snap
# Removes old revisions of snaps
# CLOSE ALL SNAPS BEFORE RUNNING THIS
set -eu

LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' |
    while read snapname revision; do
        sudo snap remove "$snapname" --revision="$revision"
    done

#Spotify
#Delete cache
cd $HOME/.cache/spotify/
#Delete storage
rm -rf Browser Data Storage

#Rust
#Remove nightly builds
cd $HOME/.rustup/toolchains/
for i in nightly-*; do rustup toolchain remove ${i/%-x86_64-unknown-linux-gnu}; done
