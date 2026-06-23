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
  **`.kamal/secrets.local`**. The committed `.kamal/secrets` is documentation
  only and must never contain real values.

Practical consequences:

- Don't add a runtime secret to `config/deploy.yml`'s `env.secret` list — read it
  from credentials instead. The only entry that belongs there is
  `RAILS_MASTER_KEY` (which unlocks everything else).
- When code needs the Anthropic API, build the client via
  `AnthropicClient.build` (`app/services/anthropic_client.rb`). It reads the key
  from credentials and fails fast with a clear error if it's missing or blank,
  rather than sending a blank key and surfacing a confusing 401.

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
