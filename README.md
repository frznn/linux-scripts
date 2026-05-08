# linux-scripts

Useful scripts for Linux.

## link-picker

Per-click browser/profile chooser for opening links. Registers as the default web browser, then prompts for browser (Brave/Firefox) and profile via `yad`.

### Dependencies

- `yad` (GTK dialog)
- `jq` (parsing Brave's `Local State`)
- `xrandr` (centering the dialog on the primary monitor)
- Brave (`/usr/bin/brave-browser`) and/or Firefox snap (`/snap/bin/firefox`) — adjust paths in the script if installed elsewhere

### Install

1. Place the script somewhere on `PATH` and make it executable:
   ```bash
   install -Dm755 link-picker ~/.local/bin/link-picker
   ```

2. Create a desktop entry at `~/.local/share/applications/link-picker.desktop`:
   ```ini
   [Desktop Entry]
   Version=1.0
   Type=Application
   Name=Link picker
   Comment=Choose browser and profile per click
   Exec=/home/USER/.local/bin/link-picker %U
   Terminal=false
   MimeType=x-scheme-handler/http;x-scheme-handler/https;
   NoDisplay=false
   Icon=web-browser
   ```
   Replace `USER` with your username (or use `$HOME` expanded at install time).

3. Refresh the desktop database and set as default:
   ```bash
   update-desktop-database ~/.local/share/applications/
   xdg-settings set default-web-browser link-picker.desktop
   xdg-mime default link-picker.desktop x-scheme-handler/http x-scheme-handler/https
   ```

4. Verify:
   ```bash
   xdg-mime query default x-scheme-handler/http
   xdg-mime query default x-scheme-handler/https
   ```

### Important: keep `MimeType` narrow

Only register for `x-scheme-handler/http` and `x-scheme-handler/https`. Do **not** add:

- `text/html` / `application/xhtml+xml` — would intercept any HTML file opened by any app
- `x-scheme-handler/about` — browsers' internal `about:` URLs (Electron apps use these too)
- `x-scheme-handler/unknown` — the catch-all fallback for unknown URL schemes; intercepts updater/IPC URLs from Electron apps (e.g. Discord), causing stuck popups and unwanted browser launches on file downloads
