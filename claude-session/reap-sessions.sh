#!/usr/bin/env bash
# Claude Code SessionStart hook.
#
# Three cheap maintenance steps, in order:
#   1. reap    — move every session carrying a "<transcript>.delete" marker to
#                the trash, skipping the session that is currently starting (its
#                id arrives as .session_id on stdin) and any session live
#                elsewhere (claude-session's own guard).
#   2. purge   — drop trashed sessions past their TTL (default 30 days).
#   3. archive — gzip a copy of every transcript older than a day into
#                ~/.claude/archive, out of reach of Claude Code's own
#                cleanupPeriodDays expiry. Idempotent, so steady-state cost is a
#                few stat calls.
#
# Silent + always exit 0 so it never blocks or pollutes session context.
input="$(cat 2>/dev/null || true)"
current=""
if command -v jq >/dev/null 2>&1; then
  current="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi

cs="$HOME/.local/bin/claude-session"
[ -x "$cs" ] || exit 0

"$cs" reap "$current"   >/dev/null 2>&1 || true
"$cs" purge --expired   >/dev/null 2>&1 || true
"$cs" archive --auto    >/dev/null 2>&1 || true
exit 0
