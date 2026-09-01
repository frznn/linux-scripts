#!/usr/bin/env bash
# Claude Code SessionEnd hook: marker-gated transcript removal.
#
# Wired into ~/.claude/settings.json (hooks.SessionEnd). Runs when any Claude
# Code session terminates. Receives the hook input JSON on stdin, of which we
# only use .transcript_path.
#
# Contract: a session whose transcript should be discarded creates a marker file
# at "<transcript_path>.delete" before ending (e.g. when the user asks for the
# session to be deleted at wrap-up); `claude-session mark` writes the same
# marker. This hook fires after the session has truly ended -- the only safe
# moment to act, since the live client appends to the transcript until exit.
# Sessions without a marker are left untouched.
#
# The actual removal is delegated to `claude-session end`, so this path shares
# one implementation with `reap` and `delete`: the transcript is moved to the
# trash (recoverable, auto-purged after its TTL) and recorded in the tombstone
# log, rather than unlinked. If the CLI is missing we fall back to the original
# unlink so a marked transcript is still honoured.
#
# The hook must never block session shutdown: all failure paths exit 0.

set -u

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null || true)
[ -n "$transcript" ] || exit 0

cs="$HOME/.local/bin/claude-session"
if [ -x "$cs" ]; then
  "$cs" end "$transcript" >/dev/null 2>&1 || true
  exit 0
fi

# Fallback: no CLI installed — remove transcript, marker and sidecar directly.
marker="${transcript}.delete"
if [ -f "$marker" ]; then
  rm -f -- "$transcript" "$marker"
  sidecar="${transcript%.jsonl}"
  [ "$sidecar" != "$transcript" ] && [ -d "$sidecar" ] && rm -rf -- "$sidecar"
fi

exit 0
