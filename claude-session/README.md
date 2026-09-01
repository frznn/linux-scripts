# claude-session

Manage [Claude Code](https://claude.com/claude-code) session transcripts from the shell — **every
session on the machine, across all projects**. List them (with project and title), mark them for
**per-session, opt-in** deletion, reap the marked ones safely, and recover the ones you change your
mind about.

Claude Code stores each conversation as `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl` (plus an
optional `<uuid>/` sidecar dir). Its built-in `cleanupPeriodDays` setting offers only *blanket*
age-based expiry of **all** transcripts; this tool is the surgical alternative — you decide, per
session, what goes.

> **`cleanupPeriodDays` is not optional.** Leaving it unset does **not** disable expiry — it applies
> Claude Code's **30-day default**, silently deleting older transcripts underneath whatever you do
> here. Set it explicitly (e.g. `"cleanupPeriodDays": 3650`) and let `claude-session doctor` keep
> checking it. This tool runs *on top of* that floor, it does not replace it.

## The deletion primitive: a `.delete` marker

Marking a session for deletion just creates an empty marker file **`<uuid>.jsonl.delete`** next to
its transcript. Two hooks act on that marker, and neither ever touches a *live* transcript:

- **`reap-sessions.sh`** — a **SessionStart** hook. On the next Claude Code launch it removes any
  marked session that isn't currently live. Handles sessions you marked from a terminal, and any
  session whose SessionEnd didn't fire (crash/kill). It also purges expired trash and refreshes the
  archive (both idempotent and silent).
- **`session-end-cleanup.sh`** — a **SessionEnd** hook. When a session ends, it removes *that*
  session's transcript if it's marked. This is the prompt path: mark the current session at wrap-up
  and it's gone the moment you exit, no next-launch wait.

Using a marker (rather than a central queue) means the intent lives next to the transcript,
self-cleans when the transcript is removed, and can be shared by any tool or workflow that agrees
on the convention — e.g. an agent wrap-up can `touch <transcript>.delete` and get the same result
as `claude-session mark`.

## Deletion is recoverable

"Delete" moves the transcript (+ marker + sidecar) into **`~/.claude/trash/<date>/<project>/`** and
appends a line to the **tombstone log** `~/.claude/session-deletions.log` — so *what was removed,
when, from where, by which path, and how many prompts it had* always has an answer. Trashed
sessions are auto-purged after **30 days** (`CLAUDE_SESSION_TRASH_TTL_DAYS`), and `restore` brings
one back before then.

`archive` keeps a gzipped copy in **`~/.claude/archive/`**, deliberately *outside*
`~/.claude/projects/` where Claude Code's own expiry cannot reach it. It copies rather than moves,
so the original stays resumable; `--prune` moves the original to the trash once archived. `restore`
falls back to the archive when the trash no longer has the session.

Only `delete --purge` unlinks outright, with no way back.

## Files

- **`claude-session`** — the CLI → `~/.local/bin`.
- **`reap-sessions.sh`** — the SessionStart hook → `~/.claude/hooks`.
- **`session-end-cleanup.sh`** — the SessionEnd hook → `~/.claude/hooks`. It delegates the actual
  removal to `claude-session end`, so all three deletion paths share one implementation (trash +
  tombstone). If the CLI isn't installed it falls back to a plain unlink, so a marker is still
  honoured. *(On the author's machine the canonical copy lives in a separate workspace; install
  this copy if you don't have your own.)*

## Dependencies

- `bash`, GNU `coreutils`/`findutils` (`find -printf`, `date -d`), `gzip`
- Linux `/proc` (live-session detection)
- `jq` — optional but recommended (titles, prompt salvage, robust live-session parsing; falls back
  to `sed`/no-title without it, and `history`/`orphans`/`doctor` degrade explicitly)

## Install

```bash
install -Dm755 claude-session         ~/.local/bin/claude-session   # ensure ~/.local/bin is on PATH
install -Dm755 reap-sessions.sh       ~/.claude/hooks/reap-sessions.sh
install -Dm755 session-end-cleanup.sh ~/.claude/hooks/session-end-cleanup.sh
```

Register both hooks in `~/.claude/settings.json` (merge into any existing `hooks`), and pin
`cleanupPeriodDays` while you're there:

```json
{
  "cleanupPeriodDays": 3650,
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
Then run `claude-session doctor` — it verifies exactly this wiring.

## Usage

```
claude-session list [opts]     # date · size · short-id · project · title;  [MARKED] [LIVE]
                               #   -l/--long · --marked · --live · --project <s>
                               #   --since <date> · --limit <n>
claude-session mark [<id>]     # mark a session for deletion (default: the current session)
claude-session unmark <id>     # remove a session's marker
claude-session marked          # list sessions currently marked
claude-session delete [-f] [--purge] <id>...   # delete now → trash; refuses a LIVE session unless -f
claude-session reap [<cur>]    # trash every marked, non-live session (SessionStart hook)
claude-session end <path>      # marker-gated removal of one transcript (SessionEnd hook)

claude-session trash           # what's in the trash and when each entry expires
claude-session restore <id>    # bring a session back (from trash, else from the archive)
claude-session purge [--older-than <n>] [--all] [-n]    # drop expired trash
claude-session archive [--older-than <n>] [--prune] [--auto] [-n]
claude-session archived        # list archived sessions

claude-session history <id> [--oneline] [-n <n>]   # replay a session's PROMPTS from history.jsonl
claude-session orphans         # sessions in history.jsonl with no transcript anywhere
claude-session log [-n <n>]    # the tombstone log: what was removed, when, by which path
claude-session doctor          # audit the invariants that keep transcripts alive
```

**Short ids / prefixes.** `list` shows the short id (the UUID's first block, e.g. `6684d991`).
Anywhere an `<id>` is expected you may pass a full UUID *or any unambiguous prefix* (git-style). An
ambiguous prefix is rejected with its candidates listed — nothing is deleted by guess. (Prefixes
beat a printed index, which shifts the moment a session is added or reaped.)

Typical flow — mark the current session at the end and let it clean up on exit:

```bash
claude-session mark            # marks the current session ($CLAUDE_CODE_SESSION_ID)
# ...the SessionEnd hook moves it to the trash when you exit; restorable for 30 days.
```

## Salvage: `history.jsonl` outlives the transcripts

`~/.claude/history.jsonl` records every prompt you ever typed (`sessionId`, `project`, `timestamp`,
`display`) and is **not** touched by `cleanupPeriodDays`. So when a transcript is gone for good, the
prompts usually aren't:

```bash
claude-session orphans            # which sessions survive only as prompts
claude-session history 7dc4f2da   # replay that session's prompts
```

It's a partial record — your side of the conversation, without the assistant's replies — but it is
often enough to reconstruct what a lost session was about.

## Live-session guard

`delete` acts immediately, so it refuses a session that looks live (exit 1) unless `-f`/`--force`.
Liveness comes from Claude Code's per-process registry at `~/.claude/sessions/<pid>.json` (each
holds its `.sessionId`); an entry counts only if `<pid>` is still running (`/proc/<pid>`), which
filters out stale files from crashed sessions. This catches live sessions in other terminals too —
even idle ones, which `list` flags `[LIVE]`. (Claude Code does *not* hold the `.jsonl` open, so
`lsof`/`fuser` are useless; the pid registry is the real signal.) The same live set gates `reap`.
`mark` is intentionally *not* guarded — marking the live/current session is exactly what it's for.
`end` is not guarded either: it runs from the SessionEnd hook, after the session has truly ended.

## Never touches memory

`~/.claude/projects/<cwd>/memory/` (Claude Code's memory store) lives in the same tree; the tool
only ever moves `<uuid>.jsonl`, its `.delete` marker, and the `<uuid>/` sidecar dir.

## Env overrides (mostly for testing)

`CLAUDE_PROJECTS_DIR`, `CLAUDE_SESSIONS_DIR`, `CLAUDE_SESSION_ID`, `CLAUDE_SESSION_TRASH`,
`CLAUDE_SESSION_ARCHIVE`, `CLAUDE_SESSION_LOG`, `CLAUDE_HISTORY_FILE`, `CLAUDE_SETTINGS_FILE`,
`CLAUDE_SESSION_CACHE`, `CLAUDE_SESSION_REPO`, `CLAUDE_SESSION_TRASH_TTL_DAYS`,
`CLAUDE_SESSION_ARCHIVE_MIN_AGE_DAYS`.

## Implementation notes

- `list` memoises each transcript's cwd + AI title in `~/.cache/claude-session/`, keyed by
  mtime+size — it used to re-scan every transcript with `jq` on each run.
- The script deliberately does **not** use `set -o pipefail`: it is full of `… | head -1` idioms,
  and on a large transcript the upstream stage takes SIGPIPE when `head` exits early, which
  pipefail turns into a fatal 141 under `set -e` (this silently truncated `list` output partway
  down the session list).
