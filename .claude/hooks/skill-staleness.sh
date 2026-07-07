#!/usr/bin/env bash
# Reminds Claude to refresh the solutus-dev skill when the app source has moved
# past the last update to its SKILL.md.
#
# State-based on purpose: it compares git history, not the command that ran, so
# it fires regardless of HOW main advanced — a local `git push` or a merged
# GitHub PR. It runs at SessionStart, i.e. right before the skill gets used, so
# the reminder lands at the moment the skill's accuracy actually matters.
#
# Emits nothing (exit 0) when the skill is already in sync, so it stays quiet
# until there is real drift to report.
set -euo pipefail

EVENT="${1:-SessionStart}"
ROOT="${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || true)}"
[ -n "$ROOT" ] || exit 0
cd "$ROOT" || exit 0

SKILL=".claude/skills/solutus-dev/SKILL.md"
WATCH_DIRS=(Solutus/ SolutusTests/)

# Baseline = last commit that touched the skill. If the skill was never
# committed there is nothing to compare against, so stay silent.
last=$(git log -1 --format=%H -- "$SKILL" 2>/dev/null || true)
[ -n "$last" ] || exit 0

# Commits to the watched source since that baseline, most recent first.
pending=$(git log --format='%h %s' "${last}..HEAD" -- "${WATCH_DIRS[@]}" 2>/dev/null || true)
[ -n "$pending" ] || exit 0

count=$(printf '%s\n' "$pending" | grep -c . || true)
joined=$(printf '%s' "$pending" | tr '\n' '|' | sed 's/|/ | /g; s/ | $//')

msg="REMINDER — solutus-dev skill sync: ${count} commit(s) touched Solutus/ or SolutusTests/ since SKILL.md was last updated. If any changed the app's architecture, flow, OverlayContent/LLMError types, or test coverage, refresh the 'What the app does', 'Architecture', and 'Existing test coverage' sections so the skill stays trustworthy. Commits since baseline: ${joined}"

# JSON-escape the message so newlines/quotes in commit subjects can't break the payload.
esc=$(printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":%s}}\n' "$EVENT" "$esc"
