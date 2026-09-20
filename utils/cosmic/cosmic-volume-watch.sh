#!/bin/bash
set -uo pipefail
#
# cosmic-volume-watch — Catch (and optionally repair) the settings-daemon stall at login
#
# cosmic-settings-daemon can lose the edge on its session-bus socket and go
# permanently deaf, which kills every media key (see fix-volume-keys.sh for the
# mechanism). Observed occurrences cluster at session startup: in the most
# recent one the keys never worked at all — they were already dead when the
# session came up. So the useful moment to look is the first seconds of a
# session, not minutes in, and a check that starts late reports a false healthy.
#
# This runs as a user unit at login, waits for the daemon to claim its bus name,
# then probes it: immediately, and again at intervals for a bounded window. Each
# probe is one D-Bus Ping. On a stall it appends a line to the log and, unless
# --log-only, repairs it by calling fix-volume-keys.
#
# It is deliberately short-lived and self-limiting: it exits when the window
# closes, makes one cheap call per probe, keeps a one-line-per-event log, and
# repairs at most MAX_FIXES times so a daemon that stalls repeatedly cannot turn
# this into a restart loop. A diagnostic that outlives its question becomes a
# load source of its own.
#
# INSTALL
#   ln -s "$PWD/utils/cosmic/cosmic-volume-watch.sh" ~/.local/bin/cosmic-volume-watch
#   install -Dm644 utils/cosmic/cosmic-volume-watch.service \
#           ~/.config/systemd/user/cosmic-volume-watch.service
#   systemctl --user daemon-reload && systemctl --user enable --now cosmic-volume-watch
#
# Read the log with:  cat ~/.local/state/cosmic-volume-watch/log
# Stop watching with: systemctl --user disable --now cosmic-volume-watch

BUS_NAME=com.system76.CosmicSettingsDaemon
BUS_PATH=/com/system76/CosmicSettingsDaemon
# Overridable from the environment so the unit can be tuned, and so the whole
# loop can be exercised in seconds when testing instead of ten minutes.
WINDOW_SECS="${WINDOW_SECS:-600}"        # how long to keep watching after login
PROBE_SECS="${PROBE_SECS:-30}"           # gap between probes after the first
NAME_WAIT_SECS="${NAME_WAIT_SECS:-90}"   # how long to wait for the daemon to appear
MAX_FIXES="${MAX_FIXES:-3}"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cosmic-volume-watch"
LOG="$LOG_DIR/log"

LOG_ONLY=0
[ "${1:-}" = "--log-only" ] && LOG_ONLY=1

# Resolve the repair script as a sibling of this one. A unit's PATH is not the
# shell's, so relying on ~/.local/bin being on it would fail silently under
# systemd while working fine when tested by hand.
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
FIXER="$HERE/fix-volume-keys.sh"

mkdir -p "$LOG_DIR"
# Timestamp every line with both wall clock and seconds-since-boot: the second
# is what says whether the daemon was already dead when the session came up.
log() {
    printf '%s  +%ss  %s\n' \
        "$(date -Is)" "$(cut -d. -f1 /proc/uptime)" "$*" >> "$LOG"
}

command -v busctl >/dev/null || { log "ABORT: busctl not found"; exit 1; }

# Wait for the daemon to claim its name before concluding anything: at login
# this unit may well start before cosmic-session has got there, and "absent" is
# not "stalled".
waited=0
until busctl --user status "$BUS_NAME" >/dev/null 2>&1; do
    [ "$waited" -ge "$NAME_WAIT_SECS" ] && {
        log "daemon never claimed $BUS_NAME within ${NAME_WAIT_SECS}s — giving up"
        exit 0
    }
    sleep 2; waited=$((waited + 2))
done

pid() { busctl --user status "$BUS_NAME" 2>/dev/null | awk -F= '/^PID=/{print $2;exit}'; }
responsive() {
    timeout 10 busctl --user call "$BUS_NAME" "$BUS_PATH" \
        org.freedesktop.DBus.Peer Ping >/dev/null 2>&1
}

log "watching — daemon is pid $(pid), appeared after ${waited}s of waiting"

fixes=0
elapsed=0
first=1
while [ "$elapsed" -le "$WINDOW_SECS" ]; do
    if responsive; then
        [ "$first" = 1 ] && log "first probe: healthy (pid $(pid))"
    else
        p="$(pid)"
        # Record the queue depth before repairing: it is the evidence that this
        # is the known stall rather than some other unresponsiveness.
        q=""
        command -v ss >/dev/null &&
            q=$(ss -xpan 2>/dev/null | grep "pid=$p," | awk '$3 != 0 {print $3; exit}')
        log "STALLED — pid $p unresponsive${q:+, $q bytes stuck unread}${first:+ (on the FIRST probe: already dead when the session came up)}"
        if [ "$LOG_ONLY" = 1 ]; then
            log "  --log-only: not repairing"
        elif [ "$fixes" -ge "$MAX_FIXES" ]; then
            log "  already repaired $fixes times this session; not repairing again"
        elif [ -x "$FIXER" ]; then
            # Count the ATTEMPT, not the success: the repair kills and restarts the
            # daemon before it reports anything, so a failed repair has still
            # consumed a restart. Counting successes would let a repair that keeps
            # failing restart the daemon on every probe — the exact loop MAX_FIXES
            # exists to prevent.
            fixes=$((fixes + 1))
            if "$FIXER" >/dev/null 2>&1; then
                log "  repaired (now pid $(pid)); repair $fixes of $MAX_FIXES"
            else
                log "  repair attempt $fixes of $MAX_FIXES FAILED — see: systemctl --user status cosmic-settings-daemon-manual"
            fi
        else
            log "  cannot repair: $FIXER is missing or not executable"
        fi
    fi
    first=""
    sleep "$PROBE_SECS"
    elapsed=$((elapsed + PROBE_SECS))
done

log "window closed after ${WINDOW_SECS}s; $fixes repair(s) this session"
