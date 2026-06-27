#!/bin/bash
# PostToolUse hook — fires right after a pull request is opened (the
# mcp__github__create_pull_request tool) and nudges Claude to run the review
# skills against the PR diff while the work is still fresh.
#
# Hooks run shell commands, not skills, so this can't invoke /code-review
# directly. Instead it injects `additionalContext`, which Claude reads as an
# instruction and acts on in the same turn. It's a reminder, not a gate: the PR
# is already open by the time this runs, so nothing is blocked.
set -euo pipefail

read -r MESSAGE <<'NUDGE'
A pull request was just opened. Before considering this done, run the review skills against the PR diff: /code-review (use --comment to post findings inline on the PR), then /simplify for reuse/efficiency cleanups, then /verify to confirm the change behaves correctly by running the app. Apply or push any fixes the reviews surface, and skip /verify only if the change has no runtime behavior to exercise.
NUDGE

# PostToolUse contract: print hookSpecificOutput.additionalContext to stdout and
# exit 0. The JSON is assembled with a heredoc so the message needs no escaping.
cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "${MESSAGE}"
  }
}
JSON
