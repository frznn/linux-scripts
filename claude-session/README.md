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
  honoured.

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
Then run `claude-session doctor` — it verifies exactly this: the setting, both hooks, and that the
installed CLI and hook scripts still match the copies here.

**Hooks may live anywhere.** `~/.claude/hooks/` is only a convention; what decides which copy
actually runs is the path in `settings.json`. So if you already keep hook scripts somewhere else — a
dotfiles repo, a shared workspace — install them there and wire that path instead. `doctor` reads
the wiring rather than assuming a location: it pairs each wired command with the script of the same
name in this directory, so a hook outside `~/.claude/hooks` is drift-checked exactly like one
inside it, and a wired hook with no counterpart here is somebody else's and is left alone.

## Usage

```
claude-session list [opts]     # date · size · short-id · project · title;  [MARKED] [LIVE]
                               #   ALL sessions: active first, then archived
                               #   -l/--long · --active · --ids · --marked · --live
                               #   --project <name|path> · --match <substr>
                               #   --since <date> · --limit <n> · --header/--no-header
claude-session resume [opts] <id> [claude args...]   # re-enter a session from its own
                               #   project dir;  -n/--dry-run · -f/--force
claude-session mark [<id>]     # mark a session for deletion (default: the current session)
claude-session unmark <id>     # remove a session's marker
claude-session marked          # list sessions currently marked
claude-session delete [-f] [--purge] <id>...   # delete now → trash; refuses a LIVE session unless -f
claude-session reap [<cur>]    # trash every marked, non-live session (SessionStart hook)
claude-session end <path>      # marker-gated removal of one transcript (SessionEnd hook)

claude-session trash           # date · size · id · project · expires · title
claude-session restore <id>    # bring a session back (from trash, else from the archive)
claude-session purge [--older-than <n>] [--all] [-n]    # drop expired trash
claude-session archive [--older-than <n>] [--prune] [--auto] [-n]
claude-session archived        # date · size · id · project · title

claude-session history <id> [--oneline] [-n <n>]   # replay a session's PROMPTS from history.jsonl
claude-session orphans         # sessions in history.jsonl with no transcript anywhere
claude-session log [-n <n>]    # the tombstone log: what was removed, when, by which path
claude-session doctor          # audit the invariants that keep transcripts alive
```

**`list` shows everything, active first then archived.** Once `archive --auto` has been running a
while, almost everything older than a day has a `.gz` copy, so archive state is what separates the
sessions you are still working in from the long tail behind them. `list` prints the active ones,
then a dim `── archived (n) ──` divider, then the rest — both blocks newest-first. `--active` lists
only the first block.

A session counts as archived only when its copy is **current** — the same
`.gz`-newer-than-transcript test `archive` itself uses — so one that grew after being archived is
listed as active, because it is not actually covered. A `[LIVE]` session is always active whatever
the mtimes say: an idle one can pass the currency test, but it invalidates that copy the moment it
writes again. Archiving **copies**, so an archived session is still on disk, still resumable, still
counted by `cleanupPeriodDays` — archived means backed up, not gone.

The divider goes through the same TTY gate as the column header, so piped output stays a plain row
stream; under `--limit` it counts the rows that actually follow (`── archived (2 of 80) ──`).

**Projects and sub-projects.** A session's project is its recorded `cwd` — a real absolute path —
so projects nest: a session in `~/dev/fed-franz/dusk/dusk-testbed` is in the `dusk-testbed`
project, which is a sub-project of `dusk`, which is a sub-project of `fed-franz`. Selecting a
project always includes its sub-projects.

```
claude-session projects                     # the hierarchy, SESSIONS + TOTAL per project
claude-session list --project dusk          # dusk and every sub-project
claude-session delete --project dusk -n     # exactly what that would take
claude-session delete --project dusk --yes  # delete the project
claude-session list --project dusk --ids    # bare UUIDs, for your own commands
```

`SESSIONS` counts sessions in the project itself (`-` when it only holds sub-projects); `TOTAL`
counts it plus every sub-project, i.e. what `--project` selects. A project is listed when it holds
sessions or branches into two or more sub-projects, so pass-through directories collapse into their
child's name rather than padding the tree with levels you could never usefully name.

A name that matches two or more projects is **asked about, never guessed**: you get a numbered
list and pick one. With no terminal to ask on — which is how the hooks run it, stderr on
`/dev/null` and no controlling tty — it falls back to listing the candidates and failing, because a
prompt there would hang session startup. The answer is read from `/dev/tty`, not stdin, so
disambiguation still works inside a pipeline, and every prompt goes to stderr so `--ids` output
stays clean. The old raw substring behaviour is
still available as `--match`, and it is genuinely different: `--match dusk` also matches a sibling
directory called `duskyard`, and `--match frznn` matches every path under `/home/frznn`.

Not every transcript carries a `cwd` record. The encoded directory name cannot be decoded back into
a path (`-` stands for both a separator and a literal dash), but every transcript in one encoded
directory was written from the same cwd, so a sibling that has the record supplies it. Without that,
a cwd-less session would be invisible to `--under` and `delete --under` would silently skip it.

**Sidecars are archived alongside the transcript.** A session may have a `<uuid>/` sidecar dir
(`tool-results/`, `subagents/`) holding tool output too large to inline. `archive` captures it as
`<uuid>.sidecar.tar.gz` next to the `.gz`, and `restore` unpacks it back; the two pieces have
independent currency tests, since a sidecar can gain files while the transcript is untouched.
Without this, `--prune` degraded a session from complete to transcript-only once its trash copy
expired 30 days later. `doctor` reports `sidecars: N/N archived`.

**`--prune` works on already-archived sessions.** It removes the original once a copy exists,
rather than only for sessions archived in that same run — which made it a silent no-op on a store
`archive --auto` had already covered.

**Short ids / prefixes.** `list` shows the short id (the UUID's first block, e.g. `6684d991`).
Anywhere an `<id>` is expected you may pass a full UUID *or any unambiguous prefix* (git-style). An
ambiguous prefix is rejected with its candidates listed — nothing is deleted by guess. (Prefixes
beat a printed index, which shifts the moment a session is added or reaped.)

Typical flow — mark the current session at the end and let it clean up on exit:

```bash
claude-session mark            # marks the current session ($CLAUDE_CODE_SESSION_ID)
# ...the SessionEnd hook moves it to the trash when you exit; restorable for 30 days.
```

## Resuming a session

`claude --resume` needs the **complete** UUID *and* only finds sessions whose recorded cwd matches
the current directory — so getting back into an old session by hand means `list -l`, copy the UUID,
`cd` to the right project, then resume. `resume` does all three:

```bash
claude-session resume 9f9b37c8              # prefix → full UUID → cd → exec claude --resume
claude-session resume 9f9b37c8 -n           # print the command instead of running it
claude-session resume 9f9b37c8 --fork-session   # extra args are passed through to claude
```

The project directory comes from the transcript's own `cwd` record — never from the encoded
directory name and never from `$PWD`. If it no longer exists, `resume` says so and stops rather than
resuming from the wrong place. It `exec`s, so you land in the real interactive Claude Code process
on a clean TTY, not inside a subshell of the script.

It refuses a session that is **`[LIVE]`** (two clients appending to one transcript would corrupt it)
or **`[MARKED]`** for deletion (anything you did in it would be thrown away at SessionEnd), naming
the fix in each case; `-f`/`--force` overrides both. A prefix that matches a trashed or archived
session points you at `restore` instead.

## Column headers

The tabular listings — `list`, `trash`, `archived`, `orphans`, `log` — print a dim uppercase column
header **when stdout is a TTY**, and omit it when the output is piped or redirected, so scripted
consumers keep seeing data rows only. `--header` / `--no-header` force it either way. `marked` is
deliberately exempt: it stays a bare list of ids for `while read id` loops (use `list --marked` for
the tabular view of the same set).

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

- Every listing resolves its project + title column through one helper (`row_meta`), so `list`,
  `trash` and `archived` render the same way: the transcript's own `cwd` record, falling back to the
  encoded directory name. `archived` reads the metadata straight out of the `.gz`.
- Encoded project directories start with `-`, which unguarded tools read as an option
  (`basename: invalid option -- 'h'`), so the directory name is taken with parameter expansion
  (`_encdir`) rather than `basename`/`dirname`.
- Each transcript's cwd + AI title is memoised in `~/.cache/claude-session/`, keyed by mtime+size —
  `list` used to re-scan every transcript with `jq` on each run. The cache key is qualified by
  location (`<id>`, `<id>.trash`, `<id>.gz`): one session id can exist as a live transcript, a
  trashed copy *and* an archived copy at once, and a single key would let them invalidate each
  other on every run.
- The script deliberately does **not** use `set -o pipefail`: it is full of `… | head -1` idioms,
  and on a large transcript the upstream stage takes SIGPIPE when `head` exits early, which
  pipefail turns into a fatal 141 under `set -e` (this silently truncated `list` output partway
  down the session list).
