# Dev process: the fast path

How the scope → design → build → review → merge → deploy loop works once it's
codified. Today every step is re-prompted from memory. This turns the loop into
committed, reusable artifacts plus two pieces of automation, so the only thing
you supply each cycle is intent.

The end state, in one line: **you describe a change, drive it through saved
commands, approve a PR, and merge ships it.** No manual `kamal deploy`.

---

## The pipeline

```
  /scope  ─►  /mockup  ─►  /build (coordinator+builder, red-green TDD)
                              │
                              ├─ green-bar hook: rubocop -A + bin/rails test on every stop
                              │
                          /review (parallel specialists)  ─►  /simplify
                              │
                          open PR  ─►  CI green  ─►  auto-merge  ─►  deploy job  ─►  tokenprice.fyi
```

Each box is a saved artifact in `.claude/` or a CI job. Nothing here is novel
prompting — it's the loop you already run, written down once.

---

## Step-by-step

### 1. Scope — `/scope`

A committed slash command backed by a `scoper` agent. It reads `docs/PRD.md`,
`docs/PRODUCT_VISION.md`, `CLAUDE.md`, and the relevant `app/` code, then returns
a feasibility-grounded scope: what changes, which files, the data-model impact
(remember prices are append-only `PricePoint`s), and the test surface.

Why it's faster: the agent starts already knowing the stack (Rails 8, SQLite,
Solid Queue, server-rendered ERB, no Node) and the house rules. You stop
re-explaining the project on every scoping pass.

### 2. Design — `/mockup`

A command that emits static Tailwind HTML into `tmp/mockups/` (gitignored),
grounded in `docs/DESIGN_BRIEF_V1.md` and the copy rules in `CLAUDE.md`. It uses
the same Tailwind classes the app ships, so the mockup looks like the real thing,
then opens it for you to react to.

Why it's faster: consistent design tokens and copy voice every time, instead of
re-pasting the brief. The mockup is throwaway (`tmp/`), so it never clutters the
repo.

### 3. Build — `/build` (coordinator + builder, red-green TDD)

Your existing pattern, committed as two agents:

- **`coordinator`** — takes the scope, breaks it into red-green slices, dispatches
  the builder per slice, and keeps the plan.
- **`builder`** — writes the failing test first, makes it pass, refactors. Reports
  back to the coordinator.

The loop is enforced, not requested: see the green-bar hook below.

### 3a. Green-bar hook (the quiet workhorse)

A `Stop` hook in `.claude/settings.json` runs the canonical gate after any edit
turn:

```
bin/rubocop -A   # auto-correct style
bin/rails test   # full suite (parallelized already)
```

You already have the single source of truth for "is this green" — `bin/ci` →
`config/ci.rb`. The hook reuses it. The builder can't hand back red or
unformatted code, because the hook surfaces the failure and the loop continues
until it's green. This is what collapses most of the manual cleanup and the
boring half of review.

### 4. Review — `/review` then `/simplify`

Two layers:

- **Specialist pass — `/review`.** Parallel committed reviewers, each with a
  narrow remit: security (Rails-specific, complements the brakeman CI job),
  Rails idioms, test quality, and **copy style against `CLAUDE.md`** (the voice
  rules are specific enough to lint against). They run concurrently and report
  findings.
- **Cleanup — `/simplify`.** The built-in skill already does reuse /
  simplification / efficiency / altitude cleanup and applies the fixes. No need
  to build this; it ships with the harness. (`/code-review` is its bug-hunting
  sibling if you want a correctness-only pass.)

Why it's faster: reviewers are saved with their remits, so you get the same
four-angle review every time without re-describing what each should look for.

### 5. Merge — auto-merge on green

Open the PR (a `/ship` command can do this), enable auto-merge. CI is the gate:
the existing `test`, `system-test`, `lint`, and the three security jobs must pass.
When they do, GitHub squash-merges without you watching the tab.

### 6. Deploy — auto on green merge

This removes your manual `kamal deploy` entirely. A new `deploy` job in
`.github/workflows/ci.yml` triggers on push to `main` (i.e. after the squash),
**needs** the test and lint jobs, and runs `bin/kamal deploy`.

```yaml
deploy:
  runs-on: ubuntu-latest
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  needs: [ test, lint, scan_ruby, scan_js ]
  steps:
    - uses: actions/checkout@v6
    - uses: ruby/setup-ruby@v1
      with:
        bundler-cache: true
    - name: Deploy with Kamal
      env:
        RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
        KAMAL_REGISTRY_PASSWORD: ${{ secrets.KAMAL_REGISTRY_PASSWORD }}
        SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
      run: |
        mkdir -p ~/.ssh && echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
        ssh-keyscan -H 46.224.179.132 >> ~/.ssh/known_hosts
        bin/kamal deploy
```

Secrets to add in the GitHub repo (Settings → Secrets and variables → Actions):

| Secret | What it is | Source today |
|---|---|---|
| `RAILS_MASTER_KEY` | decrypts `credentials.yml.enc` | `config/master.key` (gitignored) |
| `KAMAL_REGISTRY_PASSWORD` | Docker Hub push/pull | `.kamal/secrets.local` |
| `SSH_PRIVATE_KEY` | key that can SSH to `46.224.179.132` | your deploy key |

This matches `config/deploy.yml` (host, registry user `cjgilbert`, image
`cjgilbert/tokenprice`) and the secret split documented in `CLAUDE.md` (runtime
secrets stay in credentials; only `RAILS_MASTER_KEY` is injected).

Notes:
- The deploy job is gated by `needs:` — a red suite never ships.
- Kamal's `proxy.healthcheck` (`/up`) already guards the cutover, so a boot
  failure won't take the site down.
- If you ever want a human gate instead of fully hands-off, wrap the job in a
  GitHub **environment** with a required reviewer — same workflow, one approval
  click before it runs. We're starting fully automatic per your call.

---

## What gets committed to make this real

The harness ignores `/.claude/` wholesale today (see `.gitignore`). To make the
agents and commands shareable, the ignore rule narrows to internal state only:

```gitignore
# Claude Code internal state (worktree tracking, local session data)
/.claude/*
!/.claude/agents/
!/.claude/commands/
!/.claude/settings.json
```

New files:

```
.claude/
  settings.json            # green-bar Stop hook + permission allowlist
  agents/
    scoper.md
    coordinator.md
    builder.md
    reviewer-security.md
    reviewer-rails.md
    reviewer-tests.md
    reviewer-copy.md
  commands/
    scope.md
    mockup.md
    build.md
    review.md
    ship.md
.github/workflows/ci.yml   # + deploy job
.gitignore                 # narrowed .claude rule
```

Plus a **SessionStart hook** (there's a dedicated skill for it) so Claude Code on
the web — which clones fresh into an ephemeral container each session — runs
`bin/setup --skip-server` up front and can execute tests immediately. Without it,
every web session re-bootstraps before it can do anything useful.

---

## Already solved, just unused

These ship with the Claude Code harness — no build required:

- **`/simplify`** — the cleanup step (reuse, simplification, efficiency).
- **`/code-review`** — correctness/bug review of the current diff.
- **`/verify`** and **`/run`** — drive the actual app to confirm a change works,
  not just that tests pass.

Folding these in covers step 3's cleanup and a chunk of review on day one.

---

## Effort vs. payoff

| Move | Effort | Payoff |
|---|---|---|
| SessionStart hook | low | every web session starts ready — broadest win |
| Green-bar Stop hook | low | self-correcting build loop; kills manual cleanup |
| Auto-deploy job | low–med | deletes step 5 (needs 3 GH secrets) |
| Committed `.claude/` loop | med | durable: stop re-prompting the whole pipeline |

Recommended order: SessionStart hook → green-bar hook → deploy job → the
committed agent/command loop. The first two make every subsequent cycle (and the
work to build the rest) faster.
