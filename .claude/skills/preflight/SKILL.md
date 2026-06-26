---
name: preflight
description: Run this repo's full CI gate locally before pushing or opening a PR — RuboCop, Brakeman, bundler-audit, importmap audit, the Rails test suite, and the seed replant. Use when asked to "check before pushing", "run CI", "make sure it's green", "preflight", or after finishing a change and before committing. Mirrors config/ci.rb so local green matches GitHub green.
---

# Preflight

Run the same checks GitHub CI runs (see `config/ci.rb` and `.github/workflows/ci.yml`)
so a change is verified green locally before it's pushed.

## How to run

The repository ships a single runner that executes every step:

```
bin/ci
```

`bin/ci` runs setup, then style, the three security scans, the test suite, and a
seed replant. Prefer it for a full check.

When iterating on one area, run the individual steps directly so feedback is fast:

| Check | Command |
| --- | --- |
| Ruby style | `bin/rubocop` |
| Gem CVE audit | `bin/bundler-audit` |
| JS import audit | `bin/importmap audit` |
| Static security scan | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` |
| Test suite | `bin/rails test` |
| Seeds load cleanly | `env RAILS_ENV=test bin/rails db:seed:replant` |

System tests (`bin/rails test:system`) are not part of `bin/ci` but do run in
GitHub CI. Run them when a change touches views, Stimulus controllers, or
end-to-end flows.

## Fixing failures

- **RuboCop**: try `bin/rubocop -a` for autocorrectable offenses, then fix the
  rest by hand. This repo uses `rubocop-rails-omakase` — match that house style
  rather than adding inline disables.
- **Brakeman**: treat warnings as real until shown otherwise. If a warning is a
  confirmed false positive, add it to the brakeman ignore list rather than
  loosening the scan.
- **Tests**: tests that touch credentials must stub them with `stub_admin_digest!`
  / `stub_anthropic_key!` — the master key is absent here and on CI. See
  `test/test_helper.rb` and the Secrets section of `CLAUDE.md`.

## Done means

All steps pass with a non-error exit. Report which steps ran and their results
plainly — if a step was skipped (e.g. system tests), say so.
