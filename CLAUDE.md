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

Voice: a developer who built this tool and uses it themselves, writing for peers.
Not a marketing team. Not a chatbot.

Rules:
- **Cut filler.** If a sentence restates what the user can already see, delete it.
- **Don't explain the obvious.** "Compare LLM prices" as a description of a table of LLM prices adds nothing.
- **Be specific.** "Updated daily" beats "up-to-date". "40+ models" beats "comprehensive". If you can name the number, name it.
- **No em-dashes for drama.** No rhetorical questions. No "Whether you're a startup or an enterprise…" constructions.
- **Plain declaratives.** Short sentences are fine. Fragments are fine if they carry weight.
- **Trust the reader.** This is a reference tool, not a landing page. Copy should inform, not persuade.

What this looks like in practice:
- Hero subtitle: one specific sentence, not a paragraph selling the idea
- Section headers: say what's there, not what the user will "discover" or "learn"
- CTAs: `"Price your workload"` not `"Ready to price your workload?"`
- Empty/loading states: functional, not cute
- Tooltips: the fact, not an intro to the fact

## Testing

- Run the suite with `bin/rails test`.
- The master key isn't present on CI, so tests that touch credentials stub them:
  `stub_admin_digest!` and `stub_anthropic_key!` (see `test/test_helper.rb`).
