#!/bin/bash
set -uo pipefail
#
# fix-volume-keys — Revive dead volume/media keys under the COSMIC desktop
#
# SCOPE: COSMIC only, and systemd only. This restarts cosmic-settings-daemon,
# which exists solely on COSMIC, and it uses busctl/systemd-run/systemctl to do
# it. It is otherwise distribution-agnostic: nothing below assumes a package
# manager, a binary prefix or a distro-specific path.
#
# THE BUG
# -------
# Media keys are a three-hop chain: cosmic-comp catches the key and spawns
#   busctl --user call ... CosmicSettingsDaemon VolumeUp
# which cosmic-settings-daemon turns into a PipeWire call. When hop three goes
# deaf every media key dies at once and the keyboard looks broken.
#
# The daemon registers its session-bus socket edge-triggered (EPOLLET). If it
# ever stops draining that socket mid-read it consumes the edge and forfeits the
# wakeup; the socket then fills to its buffer limit, and once full no further
# bytes can arrive, so no new edge can ever be generated. The stall is therefore
# permanent and self-sustaining — the process stays alive, idle and unreachable,
# and only a restart clears it. Observed on COSMIC 1.8.0,
# cosmic-settings-daemon @ 67c995d.
#
# WHY A TRANSIENT UNIT RATHER THAN A PLAIN RESTART
# ------------------------------------------------
# cosmic-session supervises the panel/dock/launcher family but starts this
# daemon once and never respawns it, so killing it alone leaves the session with
# no settings daemon at all. That is a property of the COSMIC versions tested,
# not a documented contract: if a future release supervises the daemon, a bare
# kill becomes sufficient and this unit would then race the session's own copy
# for the bus name. Re-check that before assuming this script is still needed.
#
# INSTALL AS A COMMAND
# --------------------
#   ln -s "$PWD/utils/cosmic/fix-volume-keys.sh" ~/.local/bin/fix-volume-keys
#
# Then run with: fix-volume-keys        (--force restarts even if responsive)

BUS_NAME=com.system76.CosmicSettingsDaemon
BUS_PATH=/com/system76/CosmicSettingsDaemon
UNIT=cosmic-settings-daemon-manual
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

# Fail by name on a missing dependency rather than part-way through with a
# confusing error from whichever call happens to run first.
for tool in busctl systemd-run systemctl; do
    command -v "$tool" >/dev/null ||
        die "fix-volume-keys needs '$tool' (systemd) to talk to and restart the daemon."
done

# Resolve the binary instead of assuming a prefix: /usr/bin is usual but not
# universal (NixOS, local builds).
DAEMON_BIN="$(command -v cosmic-settings-daemon)" ||
    die "cosmic-settings-daemon is not on PATH — is this a COSMIC session?"

# The daemon needs to reach the compositor, so a session environment is not
# optional. Bail clearly rather than starting a daemon that cannot work.
[ -n "${WAYLAND_DISPLAY:-}" ] ||
    die "WAYLAND_DISPLAY is unset — run this from inside your COSMIC session, not a bare TTY."

# Hand the daemon the session's own environment rather than a hardcoded copy of
# it: which variables cosmic-session exports, and their values, differ between
# COSMIC versions and distributions. Only what is actually set is passed on.
ENV_ARGS=()
for var in WAYLAND_DISPLAY DISPLAY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP \
           XDG_SESSION_DESKTOP COSMIC_VERSION GTK_MODULES QT_ACCESSIBILITY \
           QTWEBENGINE_DICTIONARIES_PATH; do
    [ -n "${!var:-}" ] && ENV_ARGS+=( -E "$var=${!var}" )
done

# Resolve the pid from the bus name rather than by process name. Both obvious
# pgrep forms have bitten us here: `pgrep -x cosmic-settings-daemon` matches
# nothing because -x compares against the 15-char comm ("cosmic-settings"), and
# `pgrep -f '^cosmic-settings-daemon'` stops matching once this script has
# restarted it, because systemd-run puts the full binary path in argv.
daemon_pid() {
    busctl --user status "$BUS_NAME" 2>/dev/null | awk -F= '/^PID=/{print $2; exit}'
}

# The daemon keeps separate connections for its Config.* names and answers on
# those even while the main bus connection is dead, so "the process responds"
# proves nothing. Ping the object that the media-key path actually calls.
responsive() {
    timeout 10 busctl --user call "$BUS_NAME" "$BUS_PATH" \
        org.freedesktop.DBus.Peer Ping >/dev/null 2>&1
}

PID="$(daemon_pid)"

if [ -z "$PID" ]; then
    say "No $BUS_NAME on the bus — the daemon is not running at all."
else
    say "cosmic-settings-daemon is pid $PID."
    if responsive; then
        if [ "$FORCE" -eq 0 ]; then
            say "It answers on the bus, so the media-key path is healthy."
            say "Volume keys still dead? The daemon is not the problem — test the"
            say "keyboard itself, and check the compositor is seeing the key at all:"
            say "  pgrep -af busctl   # right after a key press; one per press, <=25 s"
            exit 0
        fi
        say "It answers, but --force was given; restarting anyway."
    else
        # Report the stall signature, so a stall that looks different from the
        # known one is visible rather than silently papered over by the restart.
        say "It does NOT answer — this is the known stall."
        if command -v ss >/dev/null; then
            queue=$(ss -xpan 2>/dev/null | grep "pid=$PID," | awk '$3 != 0 {print $3; exit}')
            [ -n "${queue:-}" ] &&
                say "  ${queue} bytes stuck unread on its bus socket (expected: non-zero and frozen)."
        fi
    fi
    say "Stopping pid $PID..."
    kill "$PID" 2>/dev/null
    for _ in $(seq 20); do
        kill -0 "$PID" 2>/dev/null || break
        sleep 0.25
    done
    kill -0 "$PID" 2>/dev/null && die "pid $PID would not exit; aborting."
fi

# A transient unit rather than a bare background process, so the daemon outlives
# this shell. With Linger=no the user manager exits at logout and takes the unit
# with it, so the next login's cosmic-session starts its own copy with no
# bus-name clash. Clear any unit left from a previous run first: a failed or
# still-registered unit name makes systemd-run refuse to start.
systemctl --user reset-failed "$UNIT.service" 2>/dev/null
systemctl --user stop "$UNIT.service" 2>/dev/null

say "Starting a fresh daemon as $UNIT.service..."
# The daemon reads no fd or socket from cosmic-session, so a hand-started copy
# with the session's environment is a full equivalent.
systemd-run --user --collect --unit="$UNIT" "${ENV_ARGS[@]}" "$DAEMON_BIN" >/dev/null 2>&1 ||
    die "systemd-run failed to start the daemon."

# Verify against the bus, not the unit: an active unit whose daemon has not yet
# claimed the bus name would still leave the media keys dead.
for _ in $(seq 20); do
    responsive && break
    sleep 0.25
done

if responsive; then
    say "Done — daemon is pid $(daemon_pid) and answering. Volume keys should work."
else
    say "The daemon started but is not answering on the bus yet."
    say "Check: systemctl --user status $UNIT.service"
    exit 1
fi
