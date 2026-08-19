# linux-scripts

Useful scripts for Linux.

## claude-session

Manage [Claude Code](https://claude.com/claude-code) session transcripts: list them with titles,
mark sessions for **per-session, opt-in** deletion, and reap the marked ones on the next launch (a
live transcript is never deleted mid-write). Includes a SessionStart hook. Supports git-style short
ids / prefixes and refuses to `delete` a session that's currently live. See
[`claude-session/README.md`](claude-session/README.md) for dependencies, install, and design.

## update-all

One report for every update source on this box — **APT**, **Flatpak** (user *and* system scope),
**global npm** packages, and the standalone **AI CLIs** (`claude` / `codex` / `grok`) that no package
manager tracks. Checking is read-only and needs no privileges; applying is always explicit.

```bash
update-all                       # check everything (default)
update-all --apply               # apply everything
update-all --apply flatpak npm   # only these sources
update-all --notify --only-new   # desktop notification when something is pending
update-all --full                # don't truncate long lists
```

Exit codes: `0` up to date · `10` updates pending (check mode) · `1` an apply failed.

### Install

```bash
ln -sfn "$PWD/update-all" ~/.local/bin/update-all
```

For a daily check + notification, a **user** systemd timer (no root — the check path is unprivileged):

```ini
# ~/.config/systemd/user/update-all.service
[Unit]
Description=Check for pending updates (apt, flatpak, npm, AI CLIs) and notify
[Service]
Type=oneshot
ExecStart=%h/.local/bin/update-all --notify
SuccessExitStatus=0 10          # exit 10 = "updates pending", not a failure
```
```ini
# ~/.config/systemd/user/update-all.timer
[Unit]
Description=Daily update check
[Timer]
OnCalendar=*-*-* 10:00:00
RandomizedDelaySec=30m
Persistent=true
Unit=update-all.service
[Install]
WantedBy=timers.target
```
```bash
systemctl --user daemon-reload && systemctl --user enable --now update-all.timer
```

### Note for nvm users

npm is resolved via `~/.nvm/alias/default` and its own `bin/` is prepended to `PATH`. Without that,
a systemd unit's bare `PATH` picks the distro `npm`/`node` and the check reports "up to date" with
an empty `/usr` prefix — a silent false negative.

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
