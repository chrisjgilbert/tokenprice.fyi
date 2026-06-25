# Model Guide — build orchestration

*How to build the Model Guide with a coordinator agent, TDD builders, and specialist review gates.
Companion to `MODEL_GUIDE_PLAN.md` (strategy), `MODEL_GUIDE_SPEC.md` (build detail),
`MODEL_GUIDE_COPY.md` (copy), and `MODEL_GUIDE_AUDIT.md` (pre-build fixes).*

## How to launch

Point one fresh Claude Code instance at this file:

> Read `docs/MODEL_GUIDE_BUILD.md` and act as the coordinator. Start Phase 0.

That instance is the **coordinator** for the whole build. It reads the docs, dispatches builder
sub-agents one scoped task at a time, verifies their work, convenes a review panel at each phase
gate, and stops for human approval before each new phase. It writes no feature code itself.

---

## Roles

**Coordinator** (the session you launch; one instance, all phases).
- Owns the plan, the phase gates, and cross-phase consistency. Holds the build's state in its head.
- Writes **no feature code**. Decomposes each phase into small tasks and dispatches a **builder
  sub-agent** per task.
- **Verifies every builder return** — runs `bin/rails test` itself and reads the diff via git before
  accepting. A builder's self-report is never the gate.
- At each phase end, spawns the **reviewer panel** (parallel sub-agents), triages findings,
  dispatches fix-builders for blockers, re-verifies.
- Pushes the branch and (if authorized) opens a PR per phase, then **stops for human approval**.
  Does not start the next phase until the current one is approved.
- Keeps its own context lean: instructs builders/reviewers to return concise summaries, and reads
  diffs through git rather than re-reading whole files.

**Builder sub-agent** (one per scoped task).
- Given: one task, its acceptance criteria, the relevant docs, and a strict TDD mandate.
- Works red→green→refactor, commits in small increments, returns a concise summary + the red/green
  test output as proof. Resumable — the coordinator can continue it to iterate on a fix.

**Reviewer sub-agents** (the panel, at each gate; run in parallel).
- One specialist per lens. Each gets the diff, the relevant doc acceptance criteria, and `CLAUDE.md`.
- Returns PASS/CONCERNS/BLOCK with specific, line-referenced findings. Does not edit code.

---

## TDD mandate (every builder obeys)

Strict red-green-refactor:
1. **Red** — write a failing test that captures the next behavior. Run it; show the failure.
2. **Green** — write the minimal code to pass. Run the suite.
3. **Refactor** — clean up with the suite green.
- Commit in small increments. Run `bin/rails test`. **Never commit a red suite.**
- Any bug — found by a builder, the coordinator, or a reviewer — starts with a new failing test
  that reproduces it, then the fix.
- Tests must be meaningful, not tautological. Cover the edge cases the docs and the audit name.

---

## Gate protocol (per phase)

1. Coordinator reads the phase's acceptance criteria and task breakdown (below).
2. For each task: dispatch a builder (TDD mandate + criteria + docs) → builder returns → coordinator
   runs `bin/rails test`, reads the diff, accepts or resumes the builder to fix.
3. When all tasks are done and the suite is green, coordinator self-checks the acceptance criteria.
4. **Gate:** spawn the reviewer panel for this phase in parallel.
5. Triage findings. Fix every BLOCK via TDD (new failing test → fix). Re-run the suite. Re-review
   non-trivial fixes.
6. Push the branch; open a PR (if authorized); summarize what each reviewer found and how it was
   resolved. **Stop. Wait for human approval.** Do not begin the next phase.

**Sequencing within a phase:** build tasks usually depend on each other (data before view) — run
them in order. Reviews run in parallel. If two build tasks are genuinely independent, give those
builders `isolation: "worktree"` to avoid write conflicts.

---

## Phases

This is the real Rails app. Build in Rails (routes, controllers, ERB, Stimulus, helpers, tests).
**Never port the prototype HTML** — it was a design reference only. Branch each phase off `main`.

### Phase 0 — Bank the cuts
**Builder tasks (sequential):**
- T0.1 Remove `/map` (route, controller, views, the SVG map code, tests).
- T0.2 Remove `/cost` as a destination (route + estimator views) but **extract its pricing math into
  a reusable service/module** the Guide will consume. Do not delete the math; test it in isolation.
- T0.3 Remove `/why` as a page; fold its one-line point into the footer.
- T0.4 Collapse `/learn` from a hub into a lean landing; keep the explainer pages.
- T0.5 Drop `/compare` and `/providers/:id` from the primary nav (update the nav helper); keep the
  routes working as generated views.

**Acceptance:** the four cuts done; cost math extracted and unit-tested; compare/provider reachable
but not in nav; primary nav is Models · Guide(placeholder/omit until Phase 1) · Trends · Learn; no
orphaned routes or dead links; `bin/rails test` green.
**Review panel:** TDD/test, Rails/code.

### Phase 1 — FeaturePattern + the Guide
**Builder tasks (sequential):**
- T1.1 `FeaturePattern` data (SPEC §2) for the six launch tasks (RAG, coding agent, chatbot,
  classification, summarization, agentic workflow) as the **single source of truth**. Test the
  invariants: every step has tier/shape/options; `cost_driver`/`capability` flags present; the
  no-capability-step case is representable (audit #4).
- T1.2 Per-call cost service built on the Phase 0 math. **Audit #1:** price every starting option on
  the same cache basis (or label the discounted one); gate any cache discount on `cached != null`.
  Test cache parity and the `cached:null` fallback.
- T1.3 Guide controller + route + ERB view: pipeline steps, starting options, inline per-call cost.
  **Audit #4** (no-capability-step takeaway renders cleanly) and **#5** (embed/non-text steps not
  priced as chat completions — drop or label). Copy from `MODEL_GUIDE_COPY.md`.
- T1.4 301 `/which-model` → the Guide; port its content as seed copy; add Guide to the nav.

**Acceptance:** principles hold (no fabricated volume, no ranking); the Guide and any other consumer
read the one `FeaturePattern` (audit #2 foundation); audit #1, #4, #5 fixed; Guide copy matches the
deck; `bin/rails test` green.
**Review panel:** TDD/test, Rails/code, Product-acceptance, Copy/voice.

### Phase 2 — Education + homepage
**Builder tasks:**
- T2.1 Anatomy explainer rendered from the **same `FeaturePattern`** (audit #2). Keep
  `feature_costs`' worked cost tables; the explainer is the on-ramp to it, not a replacement
  (audit #3).
- T2.2 Preserve the live-data widgets in the rebuilt explainers — port `io_ratio_widget` and the
  live frontier-model example, wired to the real `PriceCatalog` (audit #3).
- T2.3 Homepage hero from the deck (the decision-bridge); Latest-update widget as the single Trends
  entry point (audit #6); **dynamic** model count, never a static "40+"; footer disclaimer and stat
  labels per the deck.
- T2.4 Cross-link explainer ↔ guide both ways.

**Acceptance:** audit #3 (education depth + live widgets preserved), #6 (one Trends entry point), #8
(dynamic count, mono numerics); hero and chrome copy match the deck; `bin/rails test` green.
**Review panel:** Product-acceptance, Copy/voice, TDD/test.

---

## Reviewer briefs (spawn at each gate)

Give each reviewer the diff (`git diff` against the phase base), the named doc sections, and
`CLAUDE.md`. Each returns PASS / CONCERNS / BLOCK with line-referenced findings; no edits.

- **TDD/test reviewer.** Were tests written first and are they meaningful (not tautological)? Do they
  cover the acceptance criteria and the audit edge cases (#1 cache parity, #4 empty-capability step,
  #5 embed pricing)? Is the suite green? Any behavior shipped without a test?
- **Rails/code reviewer.** Idiomatic Rails 8 + Hotwire; matches existing patterns; clean removals, no
  dead code or orphaned routes; no regressions. (The built-in `/code-review` skill can stand in here.)
- **Product-acceptance reviewer.** Does the diff meet this phase's acceptance criteria and hold the
  principles — no fabricated volume, no ranking, `FeaturePattern` as the single source, education
  depth preserved? Check against PLAN, SPEC, and AUDIT.
- **Copy/voice reviewer.** Every user-facing string against `MODEL_GUIDE_COPY.md` and the CLAUDE.md
  voice rules: no filler, no marketing/rhetorical slips, locked vocabulary, mono+tabular numerics.

---

## Guardrails

- The coordinator **verifies, never trusts** — runs the suite and reads the diff before accepting any
  builder return.
- **Small commits, small tasks** — they make the build resumable. If the coordinator session dies, a
  fresh coordinator rebuilds state from these docs + git history.
- **One phase at a time, human-gated** — no phase starts until the previous PR is approved.
- **Docs are the contract** — when a builder or reviewer is unsure, the answer is in PLAN/SPEC/COPY/
  AUDIT or it's a question for the human, not an improvisation.
