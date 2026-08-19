# TODO — linux-scripts

## Review & modernize for Pop!_OS 24.04 / COSMIC
Full pass to update the repo for the current box (Pop!_OS 24.04, COSMIC, flatpak-first, no snap).

### Bugs / correctness
- [ ] `cleanup/clean.sh` — defines `remove_old_kernels()` then calls `sudo remove_old_kernels`; sudo
      can't run a shell function, so kernel purge silently no-ops. Also Pop manages kernels via
      `kernelstub` — rework carefully or drop.
- [ ] `utils/github/getFirstCommit.sh` & `getNewRepos.sh` — take the GitHub token as a **CLI argument**
      (leaks into shell history / process list). Rework to read from `pass`/env. `getNewRepos` also has
      a broken `H2` header workaround.

### Stale on this box
- [ ] `setup/*.sh` (ubuntu20/22) — GNOME + snap-removal + `apt-key` era; rewrite for Pop 24.04 / COSMIC
      or archive.
- [ ] `cleanup/clean-sw.sh` — snap + spotify-snap-cache paths are moot (flatpak now); keep the
      npm/rust-nightly bits.
- [ ] `cleanup/remove-docs.sh` — too aggressive for a dev box (strips man/info); reconsider.
- [ ] `utils/makeWebApp.sh` — built on `nativefier` (deprecated); rewrite against `firefoxpwa` or
      `chromium --app=`.
- [ ] `movsearch.sh` / `utils/movsearch.sh` / `utils/search-movies.sh` — hardcoded `/media/frznn/Movie DB`
      paths; parametrize or drop.
- [ ] `utils/restart-mouse.sh` — PS/2-only; irrelevant for a USB mouse.
- [ ] `list-installed.sh` (old) — superseded by `list-installed-new.sh`; remove. The `-new` filter also
      misses some base packages (`adduser`/`apt`/`apt-utils` still show up).

### Docs
- [ ] README covers `link-picker` + `update-all`; still document the utils (`ps-cpu`, `ps-ram`,
      `list-installed`).
- [ ] Fold the newer `utils/usb-mount-prompt` tool into the same review.

### Done (2026-08-19)
- [x] Added `update-all` — cross-manager update checker/applier (apt · flatpak · npm globals · AI
      CLIs) with a daily `--user` systemd timer + notification. Documented in the README.

### Done (2026-07-13)
- [x] Fixed `link-picker` Firefox path (`/snap/bin/firefox` → `/usr/bin/firefox`).
- [x] Symlinked `ps-cpu`, `ps-ram`, `list-installed`, `link-picker` into `~/.local/bin`; set
      `link-picker` as the default browser.
- [x] Committed `update-discord --check` mode and `list-installed-new.sh`.
