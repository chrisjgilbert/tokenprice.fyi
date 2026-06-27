# GitHub `main` merge policy

`main` is protected so every change lands the same way: a squash-merged pull
request that is up to date with `main` and has green CI. This is codified in
[`script/protect-main.sh`](../script/protect-main.sh) — run that rather than
clicking through Settings, so the policy is repeatable and reviewable.

## What it enforces

Two independent layers make up the policy:

**Merge methods (repo settings).** Squash is the only enabled merge button;
merge commits and rebase merges are turned off, and head branches are deleted
automatically after merge. On its own this is only cosmetic — it picks the
button, it doesn't stop a direct push.

**Branch protection on `main` (the actual enforcement).**

- **Require a pull request** — direct pushes to `main` are rejected. Approvals
  required: **0** (solo maintainer — you can merge your own PRs).
- **Require status checks, strict** — a PR must be *up to date with `main`* and
  have green CI before it can merge. This is the "rebase/update before merging"
  gate. Required checks: `scan_ruby`, `scan_js`, `lint`, `test`, `system-test`
  (the `deploy` job is intentionally not required — it only runs on push to
  `main`, so requiring it would deadlock PRs).
- **Require linear history** — merge commits are rejected, so only the squash
  merge can land. Pairs with squash-only above.
- **No force pushes, no deletions** of `main`.
- **Admins may bypass** (`enforce_admins` is off) — an escape hatch for a
  genuine hotfix. Flip this on if you want the rules to apply to everyone.

## Applying or changing it

```bash
gh auth login                       # once, with admin rights on the repo
script/protect-main.sh              # apply (re-runnable; idempotent)
```

To change the policy, edit the values in `script/protect-main.sh` and re-run it.
For example, to require one approving review, set
`required_approving_review_count` to `1`; to apply the rules to admins too, set
`enforce_admins` to `true`.

## Verifying

```bash
gh api repos/chrisjgilbert/tokenprice.fyi \
  --jq '{squash:.allow_squash_merge, merge:.allow_merge_commit, rebase:.allow_rebase_merge}'
gh api repos/chrisjgilbert/tokenprice.fyi/branches/main/protection \
  --jq '{strict:.required_status_checks.strict, linear:.required_linear_history.enabled, pr:.required_pull_request_reviews}'
```
