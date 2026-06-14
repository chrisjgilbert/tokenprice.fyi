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

## Testing

- Run the suite with `bin/rails test`.
- The master key isn't present on CI, so tests that touch credentials stub them:
  `stub_admin_digest!` and `stub_anthropic_key!` (see `test/test_helper.rb`).
