#!/bin/bash
# PreToolUse hook — gates the mcp__github__create_pull_request tool so the review
# skills run (and any fixes land on the branch) BEFORE the PR is opened and CI
# starts. Hooks run shell commands, not skills, so this can't invoke
# /code-review itself; it denies the first create attempt and feeds back a
# reason that tells Claude to run the skills, then lets the retry through.
#
# The gate fires at most once per branch per session: it writes a marker on the
# first denial and allows every later attempt, so applying fixes and retrying
# opens the PR without a second interruption (and without an infinite loop).
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
MARKER_DIR=".git/pr-review-gate"
MARKER="${MARKER_DIR}/${BRANCH//\//-}"

# Already gated this branch — allow the PR to open. Exit 0 with no output is an
# allow in the PreToolUse contract.
if [ -f "$MARKER" ]; then
  exit 0
fi

mkdir -p "$MARKER_DIR"
: > "$MARKER"

read -r REASON <<'NUDGE'
Before opening this PR, run the review skills against the branch diff so fixes land first and CI runs on reviewed code: /code-review for bugs (use --fix to apply, or --comment once the PR exists), then /simplify for reuse/efficiency cleanups, then /verify to confirm the change works by running the app (skip /verify only if there is no runtime behavior to exercise). Commit any resulting fixes to the branch, then create the pull request again. This gate fires once per branch, so the retry will go through.
NUDGE

cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "${REASON}"
  }
}
JSON
