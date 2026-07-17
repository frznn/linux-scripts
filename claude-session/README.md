# claude-session

Manage [Claude Code](https://claude.com/claude-code) session transcripts from the shell: list
them (with titles), mark them for **per-session, opt-in** deletion, and reap the marked ones on the
next launch — so a *live* transcript is never deleted while it's still being written.

Claude Code stores each conversation as `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl` (plus an
optional `<uuid>/` sidecar dir). The built-in `cleanupPeriodDays` setting only offers *blanket*
age-based expiry of **all** transcripts; this tool is the surgical alternative — you decide, per
session, what goes.

Two files:

- **`claude-session`** — the CLI (install to `~/.local/bin`).
- **`reap-sessions.sh`** — a Claude Code **SessionStart** hook that reaps marked sessions on the
  next launch (install to `~/.claude/hooks`).

## Dependencies

- `bash` 4+ (uses namerefs), GNU `coreutils`/`findutils` (`find -printf`, `date -r`)
- Linux `/proc` (live-session detection)
- `jq` — optional but recommended (session titles + robust live-session parsing; falls back to
  `sed`/no-title without it)

## Install

```bash
# 1. the CLI
install -Dm755 claude-session ~/.local/bin/claude-session      # ensure ~/.local/bin is on PATH

# 2. the SessionStart reaper hook
install -Dm755 reap-sessions.sh ~/.claude/hooks/reap-sessions.sh
```

Then register the hook in `~/.claude/settings.json` (merge into any existing `hooks`):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/reap-sessions.sh",
            "statusMessage": "Reaping sessions marked for deletion"
          }
        ]
      }
    ]
  }
}
```

The hook is silent and always exits 0, so it never blocks startup or pollutes session context.

## Usage

```
claude-session list [-l]      # sessions newest-first: date · size · short-id · title
                              #   [MARKED] = queued for deletion;  -l shows full UUIDs
claude-session mark [<id>]    # queue a session for deletion (reaped next launch)
                              #   default id = $CLAUDE_CODE_SESSION_ID (the current session)
claude-session unmark <id>    # remove from the queue
claude-session marked         # print the raw queue
claude-session delete [-f] <id>...   # delete transcript(s) NOW; refuses a LIVE session unless -f
claude-session reap [<cur>]   # delete every marked session except <cur> (used by the hook)
```

**Short ids / prefixes.** `list` shows the short id (the UUID's first block, e.g. `6684d991`).
Anywhere an `<id>` is expected you may pass a full UUID *or any unambiguous prefix* (git-style). An
ambiguous prefix is rejected with its candidates listed — nothing is deleted by guess. (Prefixes
are used instead of a printed index because an index shifts the moment a session is added or
reaped; a prefix is stable.)

Typical flow — at the end of a session, queue it and let the next launch clean it up:

```bash
claude-session mark            # queues the current session ($CLAUDE_CODE_SESSION_ID)
# ...next time you start Claude Code, the SessionStart hook deletes it.
```

## How it works / design

- **Mark-now, reap-next-launch.** Deleting the *running* session's transcript is unsafe — Claude
  Code is still appending to it. So `mark` just queues the id (in `~/.claude/reap-sessions`), and
  the SessionStart hook reaps the queue on the next launch, always skipping whatever session is
  live. This also gives a grace period to `unmark`.
- **Live-session guard.** `delete` acts immediately, so it refuses a session that looks live
  (exit 1) unless `-f`/`--force`. Liveness comes from Claude Code's per-process registry at
  `~/.claude/sessions/<pid>.json` (each holds its `.sessionId`); an entry counts only if `<pid>`
  is still running (`/proc/<pid>`), which filters out stale files from crashed sessions. This
  catches live sessions in other terminals too — even idle ones. (Claude Code does *not* hold the
  `.jsonl` open, so `lsof`/`fuser` are useless; the pid registry is the real signal.) `mark` is
  intentionally *not* guarded — queuing the live session is exactly what it's for.
- **Never touches memory.** `~/.claude/projects/<cwd>/memory/` (Claude Code's memory store) lives
  in the same tree; the tool only ever removes `<uuid>.jsonl` and `<uuid>/`.

## Env overrides (mostly for testing)

`CLAUDE_PROJECTS_DIR`, `CLAUDE_REAP_LIST`, `CLAUDE_SESSIONS_DIR`, `CLAUDE_SESSION_ID`.
