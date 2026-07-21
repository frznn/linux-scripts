#!/usr/bin/env bash
# SessionEnd hook: marker-gated transcript deletion.
#
# Wired into ~/.claude/settings.json (hooks.SessionEnd). Runs when any Claude
# Code session terminates. Receives the hook input JSON on stdin, of which we
# only use .transcript_path.
#
# Contract (see dev/.ai/RULES.md Collaboration rules 17-18): a session whose
# transcript should be discarded creates a marker file at
# "<transcript_path>.delete" before ending (e.g. when the user asks for the
# session to be deleted at wrap-up). This hook fires after the session has
# truly ended -- the only safe moment to delete the transcript, since the live
# client appends to it until exit -- and removes both transcript and marker.
# Sessions without a marker are left untouched.
#
# The hook must never block session shutdown: all failure paths exit 0.

set -u

# Read the hook input JSON from stdin; tolerate missing/empty input.
input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null || true)
[ -n "$transcript" ] || exit 0

# Only act when the session explicitly marked itself deletable. The marker is
# created by the session at wrap-up, or via `claude-session mark` (same file) —
# they share this ".delete" primitive. Remove the transcript, the marker, and
# the optional "<uuid>/" sidecar dir (parity with `claude-session reap`).
marker="${transcript}.delete"
if [ -f "$marker" ]; then
  rm -f -- "$transcript" "$marker"
  sidecar="${transcript%.jsonl}"
  [ "$sidecar" != "$transcript" ] && [ -d "$sidecar" ] && rm -rf -- "$sidecar"
fi

exit 0
