# cosmic — scripts for the COSMIC desktop

Scripts that only make sense on a [COSMIC](https://github.com/pop-os/cosmic-epoch) session.
They are distribution-agnostic but **require systemd** (`busctl`, `systemd-run --user`).

## Files
- `fix-volume-keys.sh` — revive dead volume/media keys by restarting `cosmic-settings-daemon`
- `cosmic-volume-watch.sh` + `.service` — watch for that stall at login, log it, and repair it

## fix-volume-keys

Media keys sometimes stop working entirely: no volume change, no on-screen display, while ordinary
typing is fine. The keyboard is almost never the cause.

A media key travels three hops — `cosmic-comp` catches it and spawns
`busctl --user call … CosmicSettingsDaemon VolumeUp`, which `cosmic-settings-daemon` turns into a
PipeWire call. The daemon intermittently stops reading its session-bus connection and never
resumes, which kills every media key at once. The process stays alive and idle, so nothing looks
wrong from the outside.

The cause is a lost edge: the bus socket is registered edge-triggered (`EPOLLET`), so a read that
stops before draining to `EAGAIN` forfeits its wakeup. The socket then fills to its buffer limit
and, being full, can never produce another edge. It never recovers on its own.

```
ln -s "$PWD/fix-volume-keys.sh" ~/.local/bin/fix-volume-keys
fix-volume-keys            # restarts the daemon only if it has actually stalled
fix-volume-keys --force    # restart regardless
```

It reports the stall signature before acting, and if the daemon is healthy it changes nothing and
says where to look instead.

### Why it starts a transient unit

`cosmic-session` supervises the panel/dock/launcher family, but starts this daemon once and never
respawns it — killing it alone leaves the session with no settings daemon at all. So the script
restarts it as the transient user unit `cosmic-settings-daemon-manual`, which dies with the session;
the next login gets a normal daemon from `cosmic-session` with no bus-name clash.

That is a property of the COSMIC versions tested (1.8.0, `cosmic-settings-daemon` @ `67c995d`), not
a documented contract. If a future release supervises the daemon, a plain `kill` becomes enough and
this script's unit would race the session's own copy.

### Diagnosing it by hand

```
# is the daemon the broken hop?  (a timeout means yes)
busctl --user call com.system76.CosmicSettingsDaemon \
  /com/system76/CosmicSettingsDaemon org.freedesktop.DBus.Peer Ping

# the proof: bytes stuck unread, and an edge-triggered registration
ss -xpan -m | grep "pid=<pid>"                 # one socket with a non-zero Recv-Q
grep "tfd: *<fd> " /proc/<pid>/fdinfo/3        # events 8000…. => EPOLLET
```
Sample the queue over ~25 s before concluding: **frozen** bytes mean a lost edge, whereas a merely
slow consumer's queue grows and drains. Note the daemon keeps answering on its
`…CosmicSettingsDaemon.Config.*` names throughout — those are separate connections, so "the process
responds" proves nothing.

## cosmic-volume-watch

The stall clusters at session startup — in one occurrence the media keys never worked at all, being
already dead when the session came up. That makes it awkward to catch: by the time you notice, the
evidence of *when* it happened is gone.

This runs as a user unit at login, waits for the daemon to claim its bus name, then probes it
immediately and every 30 s for 10 minutes. Each probe is a single D-Bus `Ping`. It logs one line per
event and, unless `--log-only`, repairs a stall by calling `fix-volume-keys`.

```
ln -s "$PWD/cosmic-volume-watch.sh" ~/.local/bin/cosmic-volume-watch
install -Dm644 cosmic-volume-watch.service ~/.config/systemd/user/cosmic-volume-watch.service
systemctl --user daemon-reload && systemctl --user enable cosmic-volume-watch
```

Log at `~/.local/state/cosmic-volume-watch/log`; every line carries the wall clock **and**
seconds-since-boot, which is what distinguishes "already dead at login" from "died during the
session". Stop with `systemctl --user disable --now cosmic-volume-watch`.

`WINDOW_SECS`, `PROBE_SECS`, `NAME_WAIT_SECS` and `MAX_FIXES` are environment overrides, which also
makes the whole loop testable in seconds.

### Deliberate limits

A diagnostic that outlives its question becomes a load source of its own, so this one is bounded:
it exits when the window closes, makes one cheap call per probe, and keeps a tiny append-only log.

`MAX_FIXES` (default 3) caps repairs per session. It counts **attempts, not successes** — a repair
kills and restarts the daemon before it reports anything, so a failed repair has still consumed a
restart; counting successes would let a repair that keeps failing restart the daemon on every single
probe.

Note the probe adds traffic to the very socket under study. A `Ping` is tiny, but it is not nothing.
