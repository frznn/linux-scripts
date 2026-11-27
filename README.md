# linux-scripts

Useful scripts for Linux.

## update-all

One report for every update source on this box — **APT**, **Flatpak** (user *and* system scope,
apps and runtimes/extensions alike, all named), **global npm** packages, and software **installed by
hand** that none of those will ever offer: `.deb`s with no apt repo (Discord, Proton Mail) and tools
no package manager tracks (`claude` / `codex` / `grok`). Checking is read-only and needs no privileges; applying is always explicit.
Only a source with something to report is shown (pending updates, a failed check, or an unsupported
npm global); when there is none, the output is the closing "Everything is up to date." line.

Sources: `apt` · `flatpak` · `npm` · `manual`

```bash
update-all                  # check everything, show how to apply, then prompt
update-all npm manual       # only these sources (still prompts)
update-all --notify         # check + desktop notification; never prompts
update-all --full           # don't truncate long lists
update-all --cached         # replay the last check's results, however old (no re-check)
update-all --fresh          # ignore the cached results and check now
```

There is no `--apply` flag: a run reports what is pending, prints the command that applies each
source **by hand**, and then asks. The prompt takes `Y` (all, the default — plain Enter applies
everything), `n` (nothing), or a list of sources to apply — and appears only on a terminal, so an
unattended run reports and stops, which is what makes a "yes" default safe. A plain run reuses the
last check's results if they are under an hour old.

A lookup that gets no answer (network down, a tool erroring) is listed as `check failed` under its
source and is never counted as up to date.

Exit codes: `0` nothing pending (even if a check failed) or applied · `10` pending, not applied ·
`1` an apply failed.

### Install

```bash
ln -sfn "$PWD/update-all" ~/.local/bin/update-all
```

For a daily check + notification, a **user** systemd timer (no root — the check path is unprivileged):

```ini
# ~/.config/systemd/user/update-all.service
[Unit]
Description=Check for pending updates (apt, flatpak, npm, manual) and notify
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

### The `manual` source

One group, one pending list and one apply step for everything installed by hand. Each entry has its
own upstream version lookup and its own installer, so applying the group runs `sudo` for the `.deb`s.

Packages installed from a downloaded `.deb` with no repo behind them (here: Discord, Proton Mail)
are invisible to `apt list --upgradable` forever — `apt-cache policy` shows the candidate equal to
what is installed. Each needs its own upstream version oracle: Discord delegates to
`update-discord --check --no-notify` (one place for that logic), Proton Mail reads upstream's
`version.json`. Applying verifies Proton's published SHA512 before `dpkg -i` — which guards a
truncated download, not a compromised feed, since URL and checksum come from the same place.

Find new `.deb`s of that class with:

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

Installed here as the GitHub release package, so `codex update` bails with "Could not detect the Codex
installation method". The package, not the lone binary, because codex runs no tools without the
`codex-code-mode-host` it ships beside `bin/codex`. `update-all` fetches
`codex-package-x86_64-unknown-linux-musl.tar.gz` from the latest release and checks its sha256
against both the API digest and `codex-package_SHA256SUMS`. It refuses absolute, `..` or escaping-link
entries, and checks that the host is present and that `--version` runs. It extracts into
`~/.codex/packages/standalone/releases/<version>-<target>/` and moves `current` there. The previous
release stays for rollback (`ln -sfn <previous> ~/.codex/packages/standalone/current`); older ones
are pruned. `~/.local/bin/codex` links to `current/bin/codex`.

## update-discord

Keeps Discord current: it is installed from a downloaded `.deb` with no apt repo, so nothing else
will ever offer an update. `--check` reports without installing; `--no-notify` additionally
suppresses the desktop notification, for callers that report for themselves (`update-all`).

## link-picker

Per-click browser/profile chooser for opening links. Registers as the default web browser, then prompts for a browser and one of its profiles via `yad`. Each profile list ends with **Guest** (Chromium-family browsers) or **Private** (Firefox-family); when a Firefox-family browser is already running, its list offers **Running window** and **Private**.

### Dependencies

- `yad` (GTK dialog)
- `jq` (parsing a Chromium-family browser's `Local State`)
- `xrandr` (centering the dialog on the primary monitor)
- the browsers themselves, listed in the browsers file below

### Browsers

The browsers come from `~/.config/link-picker/browsers` (`$XDG_CONFIG_HOME` is honoured), one per line, exactly four fields separated by `|`; blank lines and lines starting with `#` are ignored, and a comment cannot follow a browser on its line:

```
# name   | family   | profile folder                                   | command
Brave    | chromium | ~/.config/BraveSoftware/Brave-Browser            | brave-browser
Chromium | chromium | ~/.var/app/org.chromium.Chromium/config/chromium | flatpak run org.chromium.Chromium
Firefox  | firefox  | ~/.mozilla/firefox                               | firefox
```

- **family** — `chromium` reads profiles from `<folder>/Local State` and opens one with `--profile-directory`, Guest with `--guest`; `firefox` reads `<folder>/profiles.ini` and opens one with `-P`, Private with `--private-window`.
- With a Chromium-family browser, a link opens in a new window when the last window used in that profile is an installed app (a PWA window), even though the profile's normal window is open. The running browser chooses the window and a launch option cannot override it; using the profile's normal window once before clicking the link avoids it.
- **command** — split into words, never run through a shell; a leading `~/` is expanded in the folder only.
- A browser whose command is not installed is left out, so one file can serve several machines. For a flatpak that means the app itself: the command must read `flatpak run [option …] <app id>`, where each option is one of `flatpak run`'s own and an option that takes a value uses the `=` form with a value (`--branch=stable`, not `--branch stable`); any other flatpak form is a malformed line. `--user` (or `-u`), `--system`, `--installation=`, `--arch=` and `--branch=` select which installed copy must be present.
- Private opens each URL in a private window of its own, since `--private-window` takes a single URL.
- A malformed line is reported with its line number and nothing opens.

Without the file the built-in list is Firefox and Chrome (`google-chrome`, `~/.config/google-chrome`); the file replaces that list, so it also sets the order.

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

3. Refresh the desktop database and set it as the http(s) handler:
   ```bash
   update-desktop-database ~/.local/share/applications/
   xdg-mime default link-picker.desktop x-scheme-handler/http x-scheme-handler/https
   ```
   Do not use `xdg-settings set default-web-browser`: it also makes the entry the default for `text/html`, `x-scheme-handler/about` and `x-scheme-handler/unknown`, whatever its `MimeType` declares, which is exactly what the next section warns against. Desktops take the http handler as the default browser, so `xdg-mime` is enough. If you ran it already, delete the `text/html=link-picker.desktop`, `x-scheme-handler/about=link-picker.desktop` and `x-scheme-handler/unknown=link-picker.desktop` lines from `~/.config/mimeapps.list`.

4. Verify:
   ```bash
   xdg-mime query default x-scheme-handler/http
   xdg-mime query default x-scheme-handler/https
   ```

### Important: keep `MimeType` narrow

Only register for `x-scheme-handler/http` and `x-scheme-handler/https`. Do **not** add:

- `text/html` / `application/xhtml+xml` — would intercept any HTML file opened by any app (`text/html` is an opt-in, below, for those who want that)
- `x-scheme-handler/about` — browsers' internal `about:` URLs (Electron apps use these too)
- `x-scheme-handler/unknown` — the catch-all fallback for unknown URL schemes; intercepts updater/IPC URLs from Electron apps (e.g. Discord), causing stuck popups and unwanted browser launches on file downloads

### Optional: open local HTML files through the picker

If you want local `.html` files to get the browser and profile choice too, add `text/html;` to the entry's `MimeType` (`MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;`) and make it the default for that type:

```bash
update-desktop-database ~/.local/share/applications/
xdg-mime default link-picker.desktop text/html
```

The cost: every HTML file that any application opens goes through the picker first, including a file manager's double-click, a mail attachment, a saved report or documentation opened with `xdg-open`, so each one asks before it opens. To undo it, remove `text/html;` from `MimeType` and set `text/html` back to your browser's entry with `xdg-mime default <browser>.desktop text/html`. `about` and `unknown` have no such opt-in.

## code-open

Opens files in VSCode together with their project folder (the nearest ancestor holding a `.ai`, else the file's directory), so a terminal or AI session started there gets that folder as cwd. A directory opens as a window of its own folder. `code-open --url vscode://file/<path>:line:col` does the same for a link (other `vscode://` URLs pass to VSCode's own handler). `code-open --sync` makes it the default app for a user-editable set of extensions and for `vscode://` links, so a chat link opens in a new window unless one already has that folder open.

### Install

```bash
ln -s ~/dev/frznn/linux-scripts/utils/code-open.sh ~/.local/bin/code-open
code-open --sync
```

The first sync writes `~/.config/code-open/extensions` (one extension per line, no dot, `#` comments) with common code and Markdown extensions, then generates `~/.local/share/applications/vscode-scope.desktop` and sets the defaults. Edit the list and run `code-open --sync` again to apply it; an extension removed from the list is released.

Associations are per MIME type, so an extension is resolved through the system MIME database. One that resolves to `text/plain` or to a video, audio or image type is skipped with a warning, since claiming it would capture every plain-text file or a media class.

While the VSCode instance that would receive the request (the process listening on the CLI's IPC socket) is a build that a package upgrade has replaced, opening refuses with a notification to restart VSCode: such an instance still accepts the request but opens an empty window.
