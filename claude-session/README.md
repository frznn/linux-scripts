# claude-session

Manage [Claude Code](https://claude.com/claude-code) session transcripts from the shell: list them
(with titles), mark them for **per-session, opt-in** deletion, and reap the marked ones safely — so
a *live* transcript is never deleted while it's still being written.

Claude Code stores each conversation as `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl` (plus an
optional `<uuid>/` sidecar dir). The built-in `cleanupPeriodDays` setting only offers *blanket*
age-based expiry of **all** transcripts; this tool is the surgical alternative — you decide, per
session, what goes.

## The deletion primitive: a `.delete` marker

Marking a session for deletion just creates an empty marker file **`<uuid>.jsonl.delete`** next to
its transcript. Two hooks act on that marker, and both are safe (neither ever deletes a *live*
transcript):

- **`reap-sessions.sh`** — a **SessionStart** hook. On the next Claude Code launch it deletes any
  marked session that isn't currently live. Handles sessions you marked from a terminal, and any
  session whose SessionEnd didn't fire (crash/kill).
- **`session-end-cleanup.sh`** — a **SessionEnd** hook. When a session ends, it deletes *that*
  session's transcript if it's marked. This is the prompt path: mark the current session at wrap-up
  and it's gone the moment you exit, no next-launch wait.

Using a marker (rather than a central queue) means the intent lives next to the transcript,
self-cleans when the transcript is removed, and can be shared by any tool or workflow that agrees
on the convention — e.g. an agent wrap-up can `touch <transcript>.delete` and get the same result
as `claude-session mark`.

## Files

- **`claude-session`** — the CLI → `~/.local/bin`.
- **`reap-sessions.sh`** — the SessionStart reap hook → `~/.claude/hooks`.
- **`session-end-cleanup.sh`** — the SessionEnd cleanup hook → `~/.claude/hooks`. *(Included here
  for completeness; on the author's machine the canonical copy lives in a separate dev workspace.
  Install this copy if you don't have your own.)*

## Dependencies

- `bash`, GNU `coreutils`/`findutils` (`find -printf`, `date -r`)
- Linux `/proc` (live-session detection)
- `jq` — optional but recommended (session titles + robust live-session parsing; falls back to
  `sed`/no-title without it)

## Install

```bash
# CLI
install -Dm755 claude-session ~/.local/bin/claude-session      # ensure ~/.local/bin is on PATH

# hooks
install -Dm755 reap-sessions.sh      ~/.claude/hooks/reap-sessions.sh
install -Dm755 session-end-cleanup.sh ~/.claude/hooks/session-end-cleanup.sh
```

Register both hooks in `~/.claude/settings.json` (merge into any existing `hooks`):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "~/.claude/hooks/reap-sessions.sh" } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command", "command": "~/.claude/hooks/session-end-cleanup.sh" } ] }
    ]
  }
}
```

Both hooks are silent and always exit 0, so they never block startup/shutdown or pollute context.

## Usage

```
claude-session list [-l]      # sessions newest-first: date · size · short-id · title
                              #   [MARKED] = has a .delete marker;  -l shows full UUIDs
claude-session mark [<id>]    # mark a session for deletion (default: the current session)
claude-session unmark <id>    # remove a session's marker
claude-session marked         # list sessions currently marked
claude-session delete [-f] <id>...   # delete transcript(s) NOW; refuses a LIVE session unless -f
claude-session reap [<cur>]   # delete every marked, non-live session (used by the SessionStart hook)
```

**Short ids / prefixes.** `list` shows the short id (the UUID's first block, e.g. `6684d991`).
Anywhere an `<id>` is expected you may pass a full UUID *or any unambiguous prefix* (git-style). An
ambiguous prefix is rejected with its candidates listed — nothing is deleted by guess. (Prefixes
beat a printed index, which shifts the moment a session is added or reaped.)

Typical flow — mark the current session at the end and let it clean up on exit:

```bash
claude-session mark            # marks the current session ($CLAUDE_CODE_SESSION_ID)
# ...the SessionEnd hook deletes it when you exit.
```

## Live-session guard

`delete` acts immediately, so it refuses a session that looks live (exit 1) unless `-f`/`--force`.
Liveness comes from Claude Code's per-process registry at `~/.claude/sessions/<pid>.json` (each
holds its `.sessionId`); an entry counts only if `<pid>` is still running (`/proc/<pid>`), which
filters out stale files from crashed sessions. This catches live sessions in other terminals too —
even idle ones. (Claude Code does *not* hold the `.jsonl` open, so `lsof`/`fuser` are useless; the
pid registry is the real signal.) The same live set gates `reap`. `mark` is intentionally *not*
guarded — marking the live/current session is exactly what it's for.

## Never touches memory

`~/.claude/projects/<cwd>/memory/` (Claude Code's memory store) lives in the same tree; the tool
only ever removes `<uuid>.jsonl`, its `.delete` marker, and the `<uuid>/` sidecar dir.

## Env overrides (mostly for testing)

`CLAUDE_PROJECTS_DIR`, `CLAUDE_SESSIONS_DIR`, `CLAUDE_SESSION_ID`.
