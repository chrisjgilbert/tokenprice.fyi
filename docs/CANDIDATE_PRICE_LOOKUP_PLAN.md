# Candidate price lookup — plan

> Turn an unpriced model candidate into a **sourced, human-verified price** at
> review time. The extractor only sees a launch headline and a short RSS excerpt,
> where a price is rarely stated — so most candidates arrive unpriced and the
> price has to be hunted down separately in the admin price-point form after
> approval. This closes that gap: look up the price from its real source, show it
> and its citation in the review queue, let the reviewer verify or correct it, and
> write it on approve. Human-verified; never auto-published.

## The gap this closes

`NewsItem::ModelExtraction` is deliberately conservative: its prompt returns a
price **only** when the item states it, never guesses, and lowers confidence and
omits instead. Combined with the fact that it reads only `title` + a ~200-word
`excerpt_section`, most launch announcements yield an identity-only candidate —
the number lives on the provider's pricing or docs page, not in the launch blurb.

Today that leaves two separate steps with nothing connecting them:

1. Approve the candidate → an unpriced `AiModel` row ("not yet tracked").
2. Separately open `admin/models/:slug/price_points`, hunt the price yourself,
   and add a snapshot.

The reviewer is the only bridge, and at the moment of decision there's nothing in
front of them to check. This plan folds the price — with its source and
confidence — into the review row, so verification happens where the approve
button is.

```
candidate (unpriced)  --price lookup-->  proposed price + source URL + confidence
                                                  ↓ reviewer verifies / edits in queue
                                          approve --> AiModel priced from confirmed value
```

## Precedent to reuse

The transport already exists. `AnthropicClient.search_call` runs a web-search-
grounded generation and returns `{ text:, citations: }`, where each citation is a
`{ "url", "title" }` hash — string-keyed so it survives a JSON-column round trip,
deduped, and limited to `http(s)` links. That is nearly the whole enrichment
machinery: it can find the current price *and* hand back the URLs it read it from.
The `pause_turn` resume loop and citation sanitising are handled there — the
lookup does not reinvent web fetching.

## Design

### 1. Operation object — `ModelCandidate::PriceLookup`

A noun-named operation under the entity's namespace (house style; mirrors
`NewsItem::ModelExtraction` and `ModelCandidate::Acceptance`), reached through a
method on the candidate:

```ruby
# app/models/model_candidate/price_lookupable.rb  (facade concern)
module ModelCandidate::PriceLookupable
  def look_up_price = ModelCandidate::PriceLookup.new(self).run
end
```

`run` does two passes, reusing both existing `AnthropicClient` helpers rather than
inventing a combined web-search-plus-tool call:

1. **Ground it.** `AnthropicClient.search_call` with a prompt naming the model,
   its provider, and category, asking for the *current public API price* in the
   category's native shape. Returns prose + `citations`.
2. **Structure it.** `AnthropicClient.tool_call` over that prose (plus the launch
   `source_url` text) with a pricing-extraction tool whose schema is the same
   shape the extractor already writes into `pricing` — `input`/`output` for
   per-token, `pricing_model` + `price_summary` / `native_price_usd` +
   `native_price_unit` for native — **plus** `price_source_url` (which of the
   citations the number came from) and `confidence` (H/M/L). The same never-guess
   rule as the extractor: return nothing rather than a fabricated number.

The operation writes onto the candidate but does **not** approve anything:

- `pricing` ← the structured price hash (or left unchanged if nothing found)
- `price_source_url` ← the citation the number came from (new column)
- `confidence` ← the looked-up confidence
- `price_looked_up_at` ← timestamp (new column), so the UI distinguishes
  "looked up, found nothing" from "not yet looked up", and a re-run is a choice

Best-effort and idempotent in spirit: a transport failure leaves the candidate
untouched (still approvable unpriced), mirroring how extraction failures are
handled. Model choice: the extractor uses Haiku; a grounded price lookup is
accuracy-sensitive, so this is a reasonable place to spend Sonnet — decide when
building, but default to the more capable model for the number that ships.

### 2. Schema changes

One migration on `model_candidates`:

- `price_source_url` (string) — where the number was read, distinct from the
  launch `source_url`. `ModelCandidate::Acceptance` prefers it when present so the
  created `PricePoint` / model `price_source` cites the pricing page, not the
  press story.
- `price_looked_up_at` (datetime) — lookup ran-at stamp.

No change to how `pricing` is stored — it stays the same JSON shape both the
extractor and acceptance already speak, so `Acceptance#build_model` /
`apply_token_price` need no rewrite beyond preferring `price_source_url`.

### 3. Review queue — verify and edit inline

The pending row becomes an editable price form rather than a read-only
`price_preview` cell. Prefer the platform: a plain form with number inputs and a
`<details>` for the native fields, no bespoke Stimulus.

- **"Look up price"** button → `PATCH lookup` member action → runs
  `look_up_price`, re-renders the row with the found values filled in and the
  **citation rendered as a clickable link** beside the confidence badge. The
  reviewer clicks through to confirm the number matches its source.
- **Editable price fields** — input / output (per-token) or
  price_summary / native_price_usd / native_price_unit (native), plus
  `price_source_url` and `confidence`. If the lookup read the batch tier or missed
  a cached rate, the reviewer corrects it here. This is what makes it verification
  and not rubber-stamping.
- **"Approve"** submits the form values: a new `update` action persists the edited
  `pricing` / `price_source_url` / `confidence` onto the candidate, then
  `accept!` reads them unchanged. (Or fold both into the accept form's params —
  decide during build; the two-action split keeps `accept` as it is today.)

Nothing lands unseen: the price only becomes a real `AiModel` price on the
approve click, from whatever value the reviewer confirmed.

### 4. Routes

```ruby
resources :model_candidates, only: :index do
  member do
    patch :lookup     # run the price lookup, re-render the row
    patch :update     # persist edited pricing before approving
    patch :accept
    patch :dismiss
  end
end
```

Standard actions where possible; `lookup` is a named member verb justified the
same way `market_events#publish` is — a genuine operation with no seven-action
equivalent — and documented as such.

## What this is not

- **Not auto-pricing.** The lookup proposes; the human disposes. A found price is
  a draft on the candidate until an approve click, exactly like the candidate
  itself is a draft until approval.
- **Not a replacement for the OpenRouter sync.** Language launches that later
  appear on OpenRouter are better linked via `openrouter_id` so the daily sync
  keeps them current (a separate, complementary improvement). The lookup is the
  one-time, at-review price — most valuable for native-priced categories
  (image / video / speech) that never hit OpenRouter.
- **Not a guess.** Same discipline as the pricing docs and the extractor: carry
  the source URL and confidence, or return nothing.

## Testing

- `ModelCandidate::PriceLookup` with a stubbed `AnthropicClient` (both
  `search_call` and `tool_call`) — found per-token, found native, found nothing,
  transport error leaves the candidate untouched. Use `stub_anthropic_key!`.
- `Admin::ModelCandidatesController` — `lookup` populates the row; `update`
  persists edited pricing; `accept` after an edit creates a priced row citing
  `price_source_url`.
- `ModelCandidate::Acceptance` — prefers `price_source_url` over the launch
  `source_url` for the created snapshot's source.

## Rough sequence

1. Migration: `price_source_url`, `price_looked_up_at`.
2. `ModelCandidate::PriceLookup` + `PriceLookupable` facade, with tests.
3. `Acceptance` prefers `price_source_url`.
4. Controller `lookup` / `update` actions + routes.
5. Review-queue row: editable price form, "Look up price" button, citation link.
6. Retire the now-worse read-only `price_preview` cell (kept as the display
   fallback for a not-yet-looked-up row).
