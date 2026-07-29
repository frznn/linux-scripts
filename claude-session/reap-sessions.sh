#!/usr/bin/env bash
# Claude Code SessionStart hook.
# Reaps every session carrying a "<transcript>.delete" marker, skipping the
# session that is currently starting (its id arrives as .session_id on stdin)
# and any session that is live elsewhere (claude-session's own guard).
# Silent + always exit 0 so it never blocks or pollutes session context.
input="$(cat 2>/dev/null || true)"
current=""
if command -v jq >/dev/null 2>&1; then
  current="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi
"$HOME/.local/bin/claude-session" reap "$current" >/dev/null 2>&1 || true
exit 0
