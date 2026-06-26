#!/bin/bash
# SessionStart hook — bootstraps the dev environment so tests, linters, and the
# security scanners are runnable the moment a Claude Code session opens.
#
# The web container is cloned fresh each session: gems aren't installed and the
# databases aren't prepared. This script fixes that. It runs synchronously so
# nothing in the session races ahead of an unprepared environment. It is
# idempotent and non-interactive, so it's safe to run on every session.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

echo "== Claude Code session bootstrap =="

# Install gems. bundle check is a fast no-op once the container cache is warm.
if ! bundle check >/dev/null 2>&1; then
  echo "== Installing gems (bundle install) =="
  bundle install
else
  echo "== Gems already installed =="
fi

# Prepare the test database so `bin/rails test` works immediately. Schema load
# is enough; no master key is required for this.
echo "== Preparing test database =="
RAILS_ENV=test bin/rails db:test:prepare

# Prepare the development database too, so the app can boot (bin/dev) and
# development-mode tasks work.
echo "== Preparing development database =="
RAILS_ENV=development bin/rails db:prepare

echo "== Bootstrap complete =="
