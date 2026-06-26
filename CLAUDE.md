# CLAUDE.md

Guidance for working in this repository.

## Secrets

Two kinds of secrets, two homes:

- **Runtime secrets** — anything the running app reads (e.g. `anthropic_api_key`,
  `honeybadger_api_key`, `slack_webhook_url`) — go in **Rails encrypted
  credentials**. Edit with `bin/rails credentials:edit`; read in code via
  `Rails.application.credentials.<key>`. They are decrypted at runtime with
  `RAILS_MASTER_KEY` and are **not** injected as environment variables.

- **Deploy-only secrets** — secrets only Kamal needs and the app never reads
  (e.g. `RAILS_MASTER_KEY`, `KAMAL_REGISTRY_PASSWORD`) — go in the gitignored
  **`.kamal/secrets.local`** (dotenv format, unquoted values). The committed
  `.kamal/secrets` must never contain real values, but it is not just
  documentation: Kamal only loads `.kamal/secrets-common` and `.kamal/secrets`,
  **not** `.kamal/secrets.local`, so the committed file resolves each value
  itself — preferring an exported env var (how CI injects them) and otherwise
  falling back to `.kamal/secrets.local` (and `config/master.key` for the master
  key). Note Kamal's dotenv does not support `${VAR:-default}`, so the fallback
  is written explicitly with a command substitution.

Practical consequences:

- Don't add a runtime secret to `config/deploy.yml`'s `env.secret` list — read it
  from credentials instead. The only entry that belongs there is
  `RAILS_MASTER_KEY` (which unlocks everything else).
- When code needs the Anthropic API, build the client via
  `AnthropicClient.build` (`lib/anthropic_client.rb`). It reads the key
  from credentials and fails fast with a clear error if it's missing or blank,
  rather than sending a blank key and surfacing a confusing 401.

## Architecture

The house style is **vanilla Rails, 37signals flavour**: keep `app/` small, put
logic on records, and don't reach for a generic "service object" bucket. The
canonical statement is Jorge Manrubia's
[*Vanilla Rails is plenty*](https://dev.37signals.com/vanilla-rails-is-plenty/);
the reference codebase is
[once-campfire](https://github.com/basecamp/once-campfire). When a convention
below is unclear, read how Campfire does it.

This is a **target, not the current state.** The repo today has an
`app/services/` directory — exactly the generic bucket the style rejects — so
this section doubles as the map for emptying it. New code follows the target;
touched code migrates toward it. It is a **starting point, not dogma** — deviate
when the convention genuinely doesn't fit, but say so in the PR or a one-line
comment. Don't deviate silently.

### Core principles

1. **MVC, for real.** Logic lives on rich models — both Active Record models
   *and* plain Ruby objects in `app/models/`. "Model" means *any* domain object,
   not just `ActiveRecord::Base`. `FeaturePattern`, `CostEstimate`, and
   `PriceCatalog` are already the right shape: plain-Ruby domain POROs (often
   `Data.define` + a frozen registry) that happen to live under `app/services/`
   today and belong in `app/models/`.

2. **Controllers stay thin.** They authenticate, load a record, call one method
   on it, and render. The read controllers (`models`, `providers`, `guide`,
   `learn`) already read *through* `PriceCatalog` rather than via ad-hoc
   `AiModel` queries — keep that seam.

3. **No generic service layer.** The two tactics that replace it are **concerns**
   (organise an entity's code by aspect, under `app/models/<entity>/`) and
   **operation objects** (a noun-named class encapsulating one complex operation,
   reached through a method on the entity — never called directly). Details
   below.

4. **Active Record as designed.** Scopes, validations, callbacks, associations —
   as the models already do (`AiModel#price_as_of`, the `chronological` /
   `listed` / `pending_digest` scopes). Avoid raw SQL except where AR is unfit.

5. **`lib/` is for generic, non-domain transport** — HTTP clients and
   infrastructure glue with no domain shape. `AnthropicClient`,
   `OpenRouter::Client`, `HnAlgoliaFetcher`, `NewsFeedFetcher`, and
   `SlackNotifier` are all transport and belong in `lib/`, not `app/services/`.

Note on side effects: the Campfire style has records broadcast their own changes
over Turbo. This is a read-mostly data site whose writes happen in background
ingestion jobs, so that principle mostly doesn't apply here — don't invent
broadcasting. The jobs (`NewsScanJob`, `OpenRouterSyncJob`, …) stay thin
schedulable wrappers that call one method on a model/coordinator.

### Replacing service objects

**Concerns** slice an aspect of one entity into `app/models/<entity>/`, included
into the model — *not* a separate extracted class. A concern can also be a pure
**facade**: one public method that delegates to an operation object.

```ruby
# app/models/news_item/classifiable.rb
module NewsItem::Classifiable
  def classify
    NewsItem::Classification.new(self).run
  end
end
```

**Operation objects** are noun-named classes under the entity's namespace,
holding one complex operation (validations, side-effects, external calls,
multi-record coordination). Callers go through the entity's method, never the
class. Naming is load-bearing: `NewsItem::Classification`,
`AiModel::Description` — *not* `NewsClassifier`, `ModelDescriptionGenerator`, or
anything ending `-Service`. The `-Service`/`-er` reflex is the thing this style
rejects.

Plain association CRUD straight from a controller stays as-is
(`current_account.things.create!`); only wrap it in a model method when the
operation means more than `create!`.

### Migration map for today's `app/services/`

| Current (`app/services/…`)            | Target                                               | Why                                              |
|---------------------------------------|------------------------------------------------------|--------------------------------------------------|
| `anthropic_client.rb`                 | `lib/anthropic_client.rb`                            | generic transport, no domain shape               |
| `open_router/client.rb`               | `lib/open_router/client.rb`                          | generic HTTP wrapper                             |
| `hn_algolia_fetcher.rb`               | `lib/hn_algolia_fetcher.rb`                          | generic HTTP fetcher                             |
| `news_feed_fetcher.rb`                | `lib/news_feed_fetcher.rb`                           | generic RSS/HTTP fetcher                         |
| `slack_notifier.rb`                   | `lib/slack_notifier.rb`                              | generic webhook transport                        |
| `cost_estimate.rb`                    | `app/models/cost_estimate.rb`                        | domain value object (already a PORO)             |
| `price_catalog.rb`                    | `app/models/price_catalog.rb`                        | domain read-model facade over value objects      |
| `cost_format.rb`, `price_format.rb`   | `app/models/` POROs (or view helpers)               | shared formatting value modules                  |
| `guide_cost.rb`                       | `app/models/feature_pattern/cost.rb` (operation)     | prices a (slug, shape) pair for a FeaturePattern |
| `news_classifier.rb`                  | `app/models/news_item/classification.rb` (operation) | reached via `news_item.classify`                 |
| `model_description_generator.rb`      | `app/models/ai_model/description.rb` (operation)     | reached via an `AiModel` method                  |
| `open_router/model_sync.rb`           | `app/models/open_router/model_sync.rb` (coordinator) | multi-entity process owned by no single record   |
| `open_router/sync_digest.rb`          | `app/models/open_router/sync_digest.rb`              | domain presentation of a sync `Result`           |

`OpenRouter::ModelSync` is the one legitimate **top-level coordinator**: it spans
Provider / AiModel / PricePoint and belongs to no single record. It stays a
noun-named model that pushes logic onto the records it touches and keeps only the
orchestration. Coordinators like this are rare but allowed.

### Controllers

Prefer the seven standard actions. When tempted by a custom verb, add a
namespaced sub-resource controller with standard actions instead — the admin
namespace already does this (`admin/models` nests `price_points`). The
`market_events#publish` member route is a deliberate, documented exception; new
custom verbs should justify themselves the same way.

### The Command pattern — narrow allowance

A verb-named class with a uniform `call` interface is permitted for one shape: a
genuine **dispatcher** iterating over interchangeable actions through one
contract (e.g. an LLM tool layer where a dispatcher picks one tool by name).
Today's Claude calls (`NewsClassifier`, `ModelDescriptionGenerator`, the
`EventCurationJob` tool-call) are each a *single* tool call, not a dispatch over
many — so they become operation objects, not commands. Reach for the command
pattern only if a real tool-dispatch surface appears.

### File-layout sketch (target)

```
app/
  models/
    ai_model.rb
    ai_model/
      description.rb          # operation object (noun)
    news_item.rb
    news_item/
      classifiable.rb         # facade concern → delegates
      classification.rb       # operation object (noun)
    feature_pattern.rb        # domain PORO (already idiomatic)
    feature_pattern/
      cost.rb                 # operation object
    price_catalog.rb          # domain read-model facade
    cost_estimate.rb          # domain value object
    open_router/
      model_sync.rb           # top-level coordinator (noun)
      sync_digest.rb
  controllers/
    models_controller.rb
    admin/
      models_controller.rb    # nested price_points sub-resource
lib/
  anthropic_client.rb         # generic transport
  open_router/client.rb
  slack_notifier.rb
```

When tests move with the code, mirror the layout under `test/models/…` (the
suite already has `test/services/` mirroring today's structure).

### Comments

Write no comments by default — names carry the meaning. Add one only when the
**why** is non-obvious and would surprise a future reader: a hidden constraint, a
subtle invariant, a bug workaround, a non-obvious design decision. The existing
models do this well (the `CHANGE_WINDOWS` step-function note, the `source_url`
`\z`-anchoring note). Never restate what the code does. Test: if you deleted the
comment, would a competent reader be confused? If no, delete it.

## Copy style

Voice: a developer who built this tool and uses it themselves, writing for peers who are also
trying to figure something out. The learn section is the reference register — explanatory,
methodical, unhurried. Everything else should feel like the same person wrote it.

### Principles

- **Describe; don't prescribe.** Tell the reader what's here, not what their situation is.
  The tool doesn't know their job. "Most AI features run as a chain of calls" is fine;
  "Your job is a pipeline" is not.
- **Specific over punchy.** Precision is more useful than rhythm. Write the number, not the mood.
  "Updated daily" beats "up-to-date". "40+ models" beats "comprehensive".
- **Calm starting points.** When the guide suggests a model, frame it as a starting point —
  not because of hedging instinct, but because it's true. Avoid "best", "perfect", or
  implied certainty about choices.
- **Give the reader room.** Ideas should unfold rather than compress. Resist shorthand that
  performs expertise instead of conveying it. If unpacking a concept takes two sentences,
  use two sentences.
- **Earn technical vocabulary.** Terms like "cost-driver step" are fine when they're doing
  real work. Cut them when they're just flavor or atmosphere.
- **No rhetorical devices.** No "Your X is Y." No fragments for drama. No questions that are
  actually statements. No "No fabricated X, no Y" disclaimers that double as marketing.
- **Cut filler.** If a sentence restates what the reader can already see, delete it. Section
  headers should say what's there, not what the reader will "discover" or "learn".

### What this looks like in practice

- **Hero:** state what the thing is and what it covers — not a tagline selling the idea.
  "LLM API pricing, tracked from launch" over "Compare pricing across N LLM APIs".
- **Guide headings:** "Starting models for [task], with per-call cost estimates" over
  "Best starting models for [task], priced per call".
- **CTAs:** `"Find a model for your task"` not `"Ready to find the perfect model?"`.
- **Cross-links:** say what the destination contains — "For model suggestions broken down by
  step, see the guide" — not shorthand that assumes the reader knows the product.
- **Empty/loading states:** functional, not cute.
- **Tooltips:** the fact, not an intro to the fact.

## Testing

- Run the suite with `bin/rails test`.
- The master key isn't present on CI, so tests that touch credentials stub them:
  `stub_admin_digest!` and `stub_anthropic_key!` (see `test/test_helper.rb`).
