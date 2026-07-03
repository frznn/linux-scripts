#!/bin/bash
# Make the "no silent auto-mount / no auto-run" policy a system-wide, LOCKED default.
set -e
mkdir -p /etc/dconf/db/local.d/locks

cat > /etc/dconf/db/local.d/00-media-handling <<'CONF'
[org/gnome/desktop/media-handling]
automount=false
automount-open=false
autorun-never=true
CONF

cat > /etc/dconf/db/local.d/locks/media-handling <<'CONF'
/org/gnome/desktop/media-handling/automount
/org/gnome/desktop/media-handling/automount-open
/org/gnome/desktop/media-handling/autorun-never
CONF

# make sure the user profile actually reads the system db
if [ ! -f /etc/dconf/profile/user ]; then
  printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
elif ! grep -q '^system-db:local$' /etc/dconf/profile/user; then
  echo 'system-db:local' >> /etc/dconf/profile/user
fi

dconf update
echo "=== applied. current values (system-locked) ==="
echo "automount      = $(dconf read /org/gnome/desktop/media-handling/automount)"
echo "automount-open = $(dconf read /org/gnome/desktop/media-handling/automount-open)"
echo "autorun-never  = $(dconf read /org/gnome/desktop/media-handling/autorun-never)"
echo "(log out/in once for the lock to fully take effect)"
