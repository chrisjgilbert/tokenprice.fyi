---
name: open-pr
description: Review, clean up, and verify the current branch, then open the pull request — runs /code-review, /simplify, and /verify so fixes land before the PR exists and CI runs on reviewed code. Use when asked to "open a PR", "create a PR", "raise a PR", "ready for review", or to put up the current branch for review.
---

# Open PR

Run the review and verification passes against the branch *before* opening the
pull request, so any fixes land first and CI starts on reviewed code. This is the
local, fix-first half of review; the managed Code Review App (if enabled) covers
the PR again server-side once it opens.

Hooks can't invoke skills, so this is a command you run explicitly rather than an
automatic trigger. Run the steps in order and don't open the PR until the review
passes have been acted on and the branch is green.

## Steps

1. **Commit work in progress.** The review covers the branch's commits ahead of
   upstream plus the working tree, so commit (or stash) loose changes first and
   confirm you're on the intended feature branch.

2. **Review for bugs — `/code-review --fix`.** Find correctness issues and apply
   the fixes to the working tree. Read what it changed; don't accept fixes blind.

3. **Clean up — `/simplify`.** Cleanup-only pass for reuse, simplification, and
   efficiency. Skip if the diff is trivial.

4. **Verify behavior — `/verify`.** Confirm the change actually works by running
   the app and observing behavior. Skip only when the change has no runtime
   behavior to exercise (e.g. docs, config-only).

5. **Commit the fixes** from steps 2–4 with a clear message.

6. **Green gate — `bin/ci`** (the `preflight` skill). RuboCop, the security
   scans, the test suite, and the seed replant must pass before the PR opens, so
   local green matches GitHub green. Fix and re-run until clean.

7. **Open the PR.** Push the branch and create the pull request
   (`mcp__github__create_pull_request`). Write the body from the actual diff; if a
   PR template exists, mirror its headings.

## Done means

Steps 2–4 were run and their findings acted on, `bin/ci` is green, and the PR is
open against the fixed branch. Report which steps ran and any you skipped, and
why.
