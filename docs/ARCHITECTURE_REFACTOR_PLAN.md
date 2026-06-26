# Architecture refactor plan — emptying `app/services/`

Companion to the **Architecture** section of `CLAUDE.md`. That section is the
target; this is the work-breakdown for getting there, sliced into self-contained
packages a sub-agent can pick up one at a time.

Read the `CLAUDE.md` Architecture section first — it has the rationale and the
full migration map. This file is the *how* and the *order*.

> **Status:** Group A (A1, A2, A3) and Group B (B1, B2, B3) are **done and merged
> to `main`**. `app/services/` now holds only `cost_format.rb` and
> `price_format.rb` — the deferred decision below. The package sections are kept
> as the record of what each change did.

---

## The one rule that makes this safe

`config/application.rb` sets `config.autoload_lib(ignore: %w[assets tasks])`, and
`app/models`, `app/services`, and `lib` are all autoload paths. Zeitwerk resolves
a constant **by name, not by directory**.

So: **moving a class without renaming it requires zero caller changes.** `git mv`
the file, move its test to mirror, run the suite. Callers that say `PriceCatalog`
keep working whether the file is in `app/services/` or `app/models/`.

This splits the work into two kinds:

- **Pure moves (Group A)** — constant name unchanged. No caller edits. Low risk,
  parallel-safe, no merge conflicts between packages (each owns disjoint files).
- **Renames (Group B)** — `NewsClassifier` → `NewsItem::Classification`. These add
  an entity facade and edit every caller. Higher value (this is the actual
  "service object" smell), higher risk. Partitioned by entity so they don't
  collide.

Do Group A first. It shrinks `app/services/` to just the things that need real
thought, and proves the autoload assumption before any rename depends on it.

---

## Rules for every package

1. **Branch** off latest `main`: `claude/refactor-<slug>` (slug per package).
2. **No behaviour change.** These are moves and renames. If you find a bug, note
   it — don't fix it in the same package.
3. **Move the test too**, mirroring the new path: `test/services/foo_test.rb` →
   `test/lib/foo_test.rb` or `test/models/foo_test.rb`. `bin/rails test` globs
   `test/**/*_test.rb`, so location is free — keep it mirrored anyway.
4. **Use `git mv`** so history follows the file.
5. **Update doc references.** Grep `CLAUDE.md` and `docs/` for the old path/name
   and fix any that now point at the wrong place.
6. **Green gate before pushing**: run the `preflight` skill (RuboCop, Brakeman,
   bundler-audit, the full test suite, seed replant). Local green = CI green.
7. **One package per PR.** Small, reviewable, independently revertible.

`test/test_helper.rb` defines `stub_anthropic_key!` / `stub_admin_digest!` and
references `AnthropicClient` by constant — a pure move won't break it, but
re-run the credential-touching tests to be sure.

---

## Group A — pure moves (do first, parallel-safe)

Each package keeps the constant name, so callers are untouched. The "Files"
column is the complete edit surface.

### A1 — Transport → `lib/`  ·  branch `claude/refactor-transport-to-lib`

The five classes that are generic HTTP / webhook glue with no domain shape.

| Move | From | To |
|------|------|----|
| `AnthropicClient`        | `app/services/anthropic_client.rb`     | `lib/anthropic_client.rb` |
| `OpenRouter::Client`     | `app/services/open_router/client.rb`   | `lib/open_router/client.rb` |
| `HnAlgoliaFetcher`       | `app/services/hn_algolia_fetcher.rb`   | `lib/hn_algolia_fetcher.rb` |
| `NewsFeedFetcher`        | `app/services/news_feed_fetcher.rb`    | `lib/news_feed_fetcher.rb` |
| `SlackNotifier`          | `app/services/slack_notifier.rb`       | `lib/slack_notifier.rb` |

Tests: `test/services/*_test.rb` (+ `test/services/open_router/client_test.rb`)
→ mirror under `test/lib/…`.

Also: `CLAUDE.md` Secrets section references
`AnthropicClient.build (app/services/anthropic_client.rb)` — update the path to
`lib/anthropic_client.rb`.

Acceptance: `app/services/` no longer contains these five; suite green; grep for
`app/services/anthropic_client` returns nothing.

### A2 — Domain value objects → `app/models/`  ·  branch `claude/refactor-poros-to-models`

Plain-Ruby domain POROs (no `ActiveRecord::Base`) that already read like models.

| Move | From | To |
|------|------|----|
| `CostEstimate`  | `app/services/cost_estimate.rb`  | `app/models/cost_estimate.rb` |
| `PriceCatalog`  | `app/services/price_catalog.rb`  | `app/models/price_catalog.rb` |

Tests → `test/models/`. Callers (controllers, helpers, `feature_pattern.rb`)
reference the constants only — no edits needed. Confirm by grepping that no
caller hard-codes the old path.

Acceptance: both in `app/models/`; suite green.

### A3 — OpenRouter coordinator + digest → `app/models/`  ·  branch `claude/refactor-openrouter-to-models`

| Move | From | To |
|------|------|----|
| `OpenRouter::ModelSync`  | `app/services/open_router/model_sync.rb`  | `app/models/open_router/model_sync.rb` |
| `OpenRouter::SyncDigest` | `app/services/open_router/sync_digest.rb` | `app/models/open_router/sync_digest.rb` |

`ModelSync` is the one legitimate top-level coordinator (spans
Provider / AiModel / PricePoint). It stays a noun-named model; this is just the
move. Tests → `test/models/open_router/`.

> **Sequencing:** `model_sync.rb` line ~137 injects `ModelDescriptionGenerator.new`
> as its `describer:`. Package **B2** renames that constant and edits the same
> line. **Do A3 before B2, or assign both to the same agent.** Don't run them in
> parallel — they conflict on `model_sync.rb`.

Acceptance: `app/services/open_router/` empty (after A1 also moves `client.rb`);
suite green; daily sync job + rake task still resolve the constants.

---

## Group B — operation objects (renames + entity facades)

Higher value: these are the verb/`-er` names the style explicitly rejects. Each
becomes a noun under its entity's namespace, reached through a method on the
entity. Partitioned by entity → no file overlap between B-packages.

### B1 — `NewsClassifier` → `NewsItem::Classification`  ·  branch `claude/refactor-news-classification`

Cleanest of the three — the classifier already operates on a persisted
`news_item`.

- New `app/models/news_item/classification.rb` — `NewsItem::Classification`,
  a noun-named operation object holding the Claude tool-call (move the
  `TOOL_DEFINITION`, `MODEL`, `ClassifyError` here).
- New facade concern `app/models/news_item/classifiable.rb`:
  ```ruby
  module NewsItem::Classifiable
    def classify
      NewsItem::Classification.new(self).run   # returns { relevant:, kind:, rationale: }
    end
  end
  ```
  Include it in `NewsItem`.
- Callers: `app/jobs/news_scan_job.rb` and `app/jobs/release_watch_job.rb` each
  have a private `classify(item)` calling `NewsClassifier.classify(title:, source:)`
  and rescuing `NewsClassifier::ClassifyError`. Rewrite to `item.classify` and
  rescue `NewsItem::Classification::Error` (or keep the error class name).
- Tests: `test/services/news_classifier_test.rb` →
  `test/models/news_item/classification_test.rb`; update the two job tests'
  stubs/mocks.

Edit surface: both news jobs + their tests. **No other B-package touches these.**

Acceptance: `NewsClassifier` constant gone; `news_item.classify` works; job tests
green.

### B2 — `ModelDescriptionGenerator` → `AiModel::Description`  ·  branch `claude/refactor-model-description`

> **Depends on A3** (shared edit of `model_sync.rb`). Land A3 first.

Nuance: the generator runs during import on **unpersisted attributes**
(name / provider / context_window / source_text), and `ModelSync` injects it as a
`describer:` collaborator. So an *instance* facade (`ai_model.describe`) is the
wrong shape. Target instead a class-level operation under the namespace:

- New `app/models/ai_model/description.rb` — `AiModel::Description` with the same
  `.generate(name:, provider:, …)` entry point and `GenerateError`.
- Keep dependency injection: `ModelSync` constructs `AiModel::Description.new`
  (or passes the class) as its `describer:` — preserve the seam, just rename.
- Callers: `lib/tasks/openrouter.rake`, `app/services/open_router/model_sync.rb`
  (now at `app/models/...` after A3), and the model-sync test's `describer:` stub.
- Tests: `test/services/model_description_generator_test.rb` →
  `test/models/ai_model/description_test.rb`.

Acceptance: `ModelDescriptionGenerator` gone; sync + rake task green; the
`describer:` injection seam intact.

### B3 — `GuideCost` → `FeaturePattern::Cost`  ·  branch `claude/refactor-guide-cost`

`GuideCost` prices a `(model slug, token shape)` pair for a `FeaturePattern`
step — it belongs to that entity.

- New `app/models/feature_pattern/cost.rb` — `FeaturePattern::Cost`, same
  behaviour (resolve slug via `PriceCatalog`, build a `CostEstimate::Profile`,
  delegate to `price_with`). Preserve the AUDIT #1 cache-parity invariant
  (`cache: 0` **and** `cached: nil`) verbatim — it's load-bearing; copy the
  comment with it.
- Decide the seam: either a `FeaturePattern::Step#cost` method, or keep a
  module-level entry `FeaturePattern::Cost.for(slug:, shape:)`. The step method
  is more in-style if `Step` already carries the shape.
- Callers: `app/helpers/guide_helper.rb`, `app/controllers/guide_controller.rb`,
  `app/views/guide/show.html.erb`.
- Tests: `test/services/guide_cost_test.rb` →
  `test/models/feature_pattern/cost_test.rb`; check
  `test/integration/cost_removed_test.rb` for references.

Acceptance: `GuideCost` gone; guide page renders identical per-call figures;
cache-parity test still asserts the uncached basis.

---

## Deferred — decide before touching

### `CostFormat` / `PriceFormat`

Two tiny formatting modules (`app/services/cost_format.rb`,
`app/services/price_format.rb`), each used by exactly one helper
(`costs_helper`, `application_helper`). They're presentation, not domain — the
weakest fit for `app/models/`. **Lowest value; do last, or not at all.** Pick one:

- **(a)** Move to `app/models/` as plain format value modules (consistent with
  "domain-ish formatting in app/models"), or
- **(b)** Fold each into its sole caller helper, or
- **(c)** Leave them — they're already small, tested, and DRY.

Recommend (c) until there's a second caller, then (a). Flag the choice in the PR.

---

## Dependency graph & suggested order

```
A1 (transport→lib)        ─┐
A2 (POROs→models)         ─┼─ parallel, independent, no shared files
A3 (openrouter→models)    ─┘
                              │
B1 (news classification)  ───┤ parallel with each other (disjoint entities)
B3 (guide cost)           ───┤
B2 (model description)    ───┘ MUST follow A3 (shares model_sync.rb)

Deferred: CostFormat / PriceFormat  — last, optional
```

Recommended sequence for an orchestrator:

1. **Wave 1 (parallel):** A1, A2, A3 — three agents, three branches, no conflicts.
   Merge all three.
2. **Wave 2 (parallel):** B1, B3 — two agents. (B2 waits.)
3. **Wave 3:** B2 — after A3 is merged.
4. **Optional:** the `CostFormat`/`PriceFormat` decision.

When Group A + B land, `app/services/` is empty — delete the directory and its
`test/services/` mirror, and grep the repo for any lingering `app/services`
mention (docs, comments) to close it out.

---

## Sub-agent prompt template

> Implement package **<ID>** from `docs/ARCHITECTURE_REFACTOR_PLAN.md`. Read that
> file's package section and the **Architecture** section of `CLAUDE.md` first.
> Branch `claude/refactor-<slug>` off latest `main`. Make **only** the moves/
> renames described — no behaviour changes. Move tests to mirror. Run the
> `preflight` skill until green. Commit, push, and stop — do **not** open a PR or
> touch any file outside this package's edit surface.
