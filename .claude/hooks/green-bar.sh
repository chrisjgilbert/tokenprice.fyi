#!/usr/bin/env bash
#
# Green-bar Stop hook — keeps the build loop honest.
#
# Fires when Claude finishes a turn. It runs the canonical local gate
# (rubocop autocorrect + the test suite), but ONLY when Ruby sources under
# app/, lib/, or test/ actually changed since the last commit — so plain Q&A
# turns (like asking a question) don't trigger a full test run.
#
# On failure it exits 2: Claude Code feeds stderr back into the session and
# does not let the turn end, so the build loop self-corrects instead of
# handing back red or unformatted code.
#
# Wired up in .claude/settings.json under hooks.Stop. Remove that entry (or
# this file) to disable.

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 0

# Nothing to check if the repo's Ruby code is unchanged vs HEAD.
if git diff --quiet HEAD -- app lib test 2>/dev/null; then
  exit 0
fi

rubo_out=$(bin/rubocop -a 2>&1); rubo=$?
test_out=$(bin/rails test 2>&1); tests=$?

if [ "$rubo" -ne 0 ] || [ "$tests" -ne 0 ]; then
  {
    echo "Green-bar hook failed — resolve before finishing:"
    [ "$rubo" -ne 0 ]  && { echo "--- rubocop ---"; echo "$rubo_out" | tail -n 20; }
    [ "$tests" -ne 0 ] && { echo "--- tests ---";   echo "$test_out" | tail -n 30; }
  } >&2
  exit 2
fi

exit 0
