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
**global npm** packages, **hand-installed `.deb`s** that apt structurally cannot see, and the
standalone **AI CLIs** (`claude` / `codex` / `grok`) that no package manager tracks. Checking is
read-only and needs no privileges; applying is always explicit.

Sources: `apt` · `flatpak` · `npm` · `deb` · `ai`

```bash
update-all                  # check everything, show how to apply, then prompt
update-all npm deb          # only these sources (still prompts)
update-all --notify         # check + desktop notification; never prompts
update-all --full           # don't truncate long lists
```

There is no `--apply` flag: a run reports what is pending, prints the command that applies each
source **by hand**, and then asks. The prompt takes `y` (all), `n` (nothing, the default), or a list
of sources to apply — and appears only on a terminal, so an unattended run reports and stops.

Exit codes: `0` up to date or applied · `10` pending, not applied · `1` an apply failed.

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

### The `deb` source

Packages installed from a downloaded `.deb` with no repo behind them (here: Discord, Proton Mail)
are invisible to `apt list --upgradable` forever — `apt-cache policy` shows the candidate equal to
what is installed. Each needs its own upstream version oracle: Discord delegates to
`update-discord --check --no-notify` (one place for that logic), Proton Mail reads upstream's
`version.json`. Applying verifies Proton's published SHA512 before `dpkg -i` — which guards a
truncated download, not a compromised feed, since URL and checksum come from the same place.

Find new members of that class with:

```bash
comm -23 <(dpkg-query -W -f='${Package}\n' | sort) \
         <(apt-cache dumpavail | awk '/^Package: /{print $2}' | sort -u)
```

### npm targets are engine-aware

`npm outdated` reports the registry's `latest` dist-tag regardless of whether your node can run it.
On node 20 that means `npm@12` (needs node ≥22), which npm then refuses with `EBADENGINE`, and
`corepack@0.35.0`, which installs with a mere warning and is then unsupported. So for each pending
package `update-all` resolves the newest published version whose `engines.node` your node actually
satisfies — using the `semver` that npm itself ships — and says why it held back:

```
npm  10.8.2 → 11.19.0   (latest 12.0.2 needs node ^22.22.2 || ^24.15.0 || >=26.0.0)
```

It also flags globals whose *installed* version already violates its engines. Those are not
"outdated" — the compatible release is older — so nothing else would ever report them.

npm itself is resolved via `~/.nvm/alias/default` with its own `bin/` prepended to `PATH`. Without
that, a systemd unit's bare `PATH` picks the distro `npm`/`node` and the check reports "up to date"
with an empty `/usr` prefix — a silent false negative.

### codex

Installed here as a GitHub release binary, so `codex update` bails with "Could not detect the Codex
installation method". `update-all` fetches `codex-x86_64-unknown-linux-musl.tar.gz` from the latest
release, **runs `--version` on the new binary before it replaces the old one**, and keeps the
previous binary at `~/.local/bin/codex.bak`.

## update-discord

Keeps Discord current: it is installed from a downloaded `.deb` with no apt repo, so nothing else
will ever offer an update. `--check` reports without installing; `--no-notify` additionally
suppresses the desktop notification, for callers that report for themselves (`update-all`).

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
