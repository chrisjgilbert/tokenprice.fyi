#!/usr/bin/env bash
#
# Codifies the `main` merge policy on GitHub so it's repeatable, not click-ops.
# Re-runnable: every call PUT/PATCHes the same desired state.
#
# Policy (see docs/GITHUB_BRANCH_PROTECTION.md for the rationale):
#   - Squash is the only merge method; merge commits and rebase merges are off.
#   - Head branches are deleted automatically once merged.
#   - `main` requires a pull request (0 approvals — solo maintainer).
#   - PRs must be up to date with `main` and have green CI before merging
#     (this is the "rebase/update before merge" gate: required_status_checks.strict).
#   - Linear history is required, so only the squash merge can land.
#   - Admins may bypass (no enforce_admins) — an escape hatch for hotfixes.
#
# Requires the GitHub CLI, authenticated with admin rights on the repo:
#   gh auth login
#
# Usage:
#   script/protect-main.sh                       # acts on the default repo below
#   REPO=owner/name script/protect-main.sh       # override the repo
#   BRANCH=main     script/protect-main.sh        # override the protected branch

set -euo pipefail

REPO="${REPO:-chrisjgilbert/tokenprice.fyi}"
BRANCH="${BRANCH:-main}"

# CI checks that run on pull requests, by job name (the `deploy` job is excluded
# on purpose — it only runs on push to main, so requiring it would deadlock PRs).
CONTEXTS='["scan_ruby", "scan_js", "lint", "test", "system-test"]'

echo "→ ${REPO}: squash-only merges, delete head branches on merge"
gh api -X PATCH "repos/${REPO}" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  >/dev/null

echo "→ ${REPO}: protecting '${BRANCH}' (require PR + up-to-date + green CI, linear history)"
gh api -X PUT "repos/${REPO}/branches/${BRANCH}/protection" \
  -H "Accept: application/vnd.github+json" \
  --input - >/dev/null <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ${CONTEXTS} },
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "required_linear_history": true,
  "enforce_admins": false,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON

echo "✓ Done. '${BRANCH}' now requires a squash-merged, up-to-date, CI-green PR."
