# removable-media — safe USB auto-mount prompt

Keeps the desktop's auto-mount OFF (nothing mounts/opens silently), and instead pops a
dialog on each newly-connected USB disk to pick **Read-only / Read-write / Don't mount** —
then mounts it via `udisksctl` (with hardened options) and opens the file manager at the mount point.

## Files
- `usb-mount-prompt.sh`      — session daemon: detect new USB fs → prompt → mount → open file manager
- `usb-mount-prompt.desktop` — autostart entry (runs the daemon at login)
- `lock-media-handling.sh`   — makes `automount=false` / `autorun-never=true` a system-wide **locked** default (needs sudo)

## Install
```
install -Dm755 usb-mount-prompt.sh      ~/.local/bin/usb-mount-prompt.sh
install -Dm644 usb-mount-prompt.desktop ~/.config/autostart/usb-mount-prompt.desktop
sudo bash lock-media-handling.sh        # optional but recommended; then log out/in
```
Start now without logging out: `~/.local/bin/usb-mount-prompt.sh &`

## Behaviour
- Read-only mount: `ro,noexec,nosuid,nodev` · Read-write: `rw,nosuid,nodev`
- Ignores internal disks (only USB / hotplug devices with a filesystem).
- Ignores devices already present at startup (won't nag at login).
- Logs to `~/usb-mount-prompt.log` (small; delete anytime).

## Requires
`zenity`, `udisks2` (`udisksctl`), `lsblk`, `findmnt`, `xdg-open` — standard on Ubuntu/GNOME.
Note: on Wayland compositors that expose a "third-level/AltGr" chooser separately, this is unrelated.
