# Compare-from-table — build spec

*Design spec for selecting models in the price table and comparing them side by side without
leaving the page. This is the "Concept A" direction from the design exploration: row selection →
a sticky compare tray → a native `<dialog>` holding an N-way comparison grid. Copy notes follow
the house voice in `CLAUDE.md`.*

---

## 1. Goal

A developer scanning the price table wants to put two-to-four models next to each other —
"Opus vs GPT-5 vs Gemini, what do they each cost" — without first navigating away to pick them
one at a time. Today that journey exists only on `/compare`, which is **pairwise** and starts
from empty selectors. The table is where the models already are; the comparison should start
from there.

The build adds a selection affordance to the table, a tray that collects the picks, and a modal
that shows the comparison. It does **not** replace `/compare` — that page stays the canonical,
linkable, SEO-bearing surface, and the modal links out to it.

## 2. What already exists (and what we reuse)

- **`/compare?a=&b=`** (`ComparisonsController#show`, `comparisons/show.html.erb`) — a polished
  **two-model** grid with winner highlighting (cheaper price / larger context gets a green
  check), built from server-side pricing logic. The row math (`winner_for`, the `numeric_rows` /
  `text_rows` tables) is exactly what the modal needs, generalized from 2 columns to N.
- **The table** (`models/index.html.erb`) — rows are single clickable navigation targets
  (`onclick → model_path`), Russian-doll cached on `[model, current_price.updated_at, sort_col]`,
  and rendered **inside** `turbo_frame_tag "models"`, which re-renders on every filter/sort.
- **Native platform patterns** — the codebase uses the **Popover API** (`popover_controller.js`
  is just positioning glue), `<details>` for facets, and the `.tp-check` pill checkbox for the
  provider filter. There is **no `<dialog>` in the app yet**; this feature introduces the first
  one, the same way the popover was introduced — native element, thin Stimulus glue.

Two constraints fall directly out of the above and shape the whole design:

1. **Selection state can't live in the cached row markup.** The row is server-cached, so the
   checkbox renders in its default (unchecked) state and selection is expressed as a *client-side
   class*, never re-rendered HTML.
2. **Selection state must survive Turbo-frame reloads.** Filtering or re-sorting replaces the
   `models` frame wholesale. The controller that owns the selection set therefore lives on an
   element **outside** that frame and re-applies checked state on `turbo:frame-load`.

## 3. The flow

1. **Select.** A checkbox sits at the left edge of each row. On desktop it's revealed on
   row hover/focus (and stays visible once checked); on touch it's always present. Ticking it
   adds the model to the selection; it does **not** navigate (the checkbox cell stops click
   propagation, the rest of the row still links to the model page).
2. **Collect.** The first selection slides up a **sticky compare tray** pinned to the bottom of
   the viewport: the provider squares of the picked models, a count, a **Clear**, and a primary
   **Compare (N)** button. The tray sits above the price ticker if both are present.
3. **Compare.** **Compare (N)** opens a native `<dialog>` whose body is a `<turbo-frame>` pointed
   at the comparison grid for the selected slugs. The server renders the N-way grid; the dialog
   shows it in the top layer.
4. **Act.** The dialog footer carries an **"Open full comparison →"** link to
   `/compare?models=…` (the shareable, linkable page) and a **Close**. Closing returns the user to
   the table with their selection — and the tray — intact.

## 4. Interaction detail

### 4.1 The row checkbox

- Markup: the existing `.tp-check` pill pattern, in a new leading `<td>` / `<th>`. It renders
  **stateless** (always unchecked) so it's safe inside the row cache.
- A `change` on the checkbox calls the selection controller; `click` on the checkbox cell stops
  propagation so the row's `onclick` navigation doesn't fire.
- Checked rows also get a subtle full-row tint (reuse the `tp-col-highlight` accent family) so the
  selection reads at a glance while scrolling.
- Keyboard: the checkbox is a real focusable input; Space toggles it. The row link remains
  separately tabbable.

### 4.2 The selection cap

- Cap selection at **4 models** — past four the comparison grid's columns get too narrow to read,
  and four covers the realistic "which of these should I use" question.
- At the cap, unchecked checkboxes go `disabled` with a tooltip ("Compare up to 4 models"); the
  tray's count reads `4 / 4`.

### 4.3 The tray

- A bottom-pinned bar, hidden at zero selections, sliding in on the first pick. Contents:
  - left: up to four provider squares + truncated model names, with a small `×` per chip to
    deselect individually;
  - right: **Clear** (ghost) and **Compare (N)** (primary, disabled at N < 2).
- Coexists with the price ticker: when `body.has-ticker` is present, the tray stacks above it (or
  the ticker yields while a selection is active — decide during build; stacking is simpler).
- The tray controller is mounted on a layout-level element outside the `models` frame so it
  persists across filter/sort reloads.

### 4.4 The modal

- A native `<dialog>` (`showModal()`), light-dismiss on backdrop click and `Esc` handled by the
  element itself; Stimulus only opens it and sets the frame `src`.
- Body is a `<turbo-frame id="comparison">` whose `src` is set to the grid endpoint for the
  selected slugs when the dialog opens. The frame shows a skeleton/loading row until it resolves.
- The grid is the **same partial** the `/compare` page renders (see §5), so the two surfaces can
  never drift.
- Footer: **"Open full comparison →"** (`/compare?models=…`) and **Close**.

### 4.5 Winner highlighting at N models

The current `winner_for` lambda is pairwise. Generalize it: for each numeric row, find the
extreme across the N present values — the minimum for `:lower_better` (input/output/cached price),
the maximum for `:higher_better` (context). Highlight every cell that matches the extreme. Keep
the current "all-equal ⇒ no winner" behaviour (if every value is equal, or only one model has a
value, highlight nothing). Missing values never win (they sort to ±∞ exactly as today).

## 5. Architecture (house-style fit)

The guiding principle: **keep the pricing/winner logic on the server, where it already lives.**
The modal must not reimplement any of it in JavaScript.

- **Shared grid partial.** Extract the comparison grid (selectors aside — just the
  `.cmp-table` rows + the winner math) from `comparisons/show.html.erb` into
  `comparisons/_grid.html.erb`, taking an ordered `models:` array of any length. Both the full
  page and the modal frame render it. This is the change that makes 2-way and N-way the same code.
- **N-aware controller action.** Teach `ComparisonsController#show` to accept `?models=a,b,c,d`
  (ordered slug list) alongside the existing `a`/`b` params, which stay as the canonical pairwise
  form. A `layout=modal`/frame request renders just the grid partial inside the `comparison`
  frame; a normal request renders the full page. Cap-enforce N ≤ 4 server-side too.
- **Thin Stimulus.** One new controller, `model_selection_controller.js`, owns the selection set
  (an ordered list of slugs), toggles the tray, re-applies checked + row-tint state on
  `turbo:frame-load`, enforces the cap, builds the grid/compare URLs, and calls `dialog.showModal()`.
  The `<dialog>` itself handles focus trap, top-layer, and dismiss — no bespoke modal machinery,
  matching how `popover_controller` leans on the Popover API.
- **No new model objects.** This is presentation over existing `AiModel` / `PriceCatalog` data;
  nothing new belongs in `app/models/`. The controller stays thin (load the listed models, pick
  the requested slugs in order, render).

Sketch of where things land:

```
app/
  controllers/
    comparisons_controller.rb       # accepts ?models=a,b,c; renders page or grid frame
  views/
    comparisons/
      show.html.erb                 # full page — now renders _grid for [left, right]
      _grid.html.erb                # NEW shared N-column grid + generalized winner math
    models/
      index.html.erb                # + leading checkbox cell, tray, <dialog> + frame
  javascript/controllers/
    model_selection_controller.js   # NEW selection set, tray, cap, dialog open, frame src
```

## 6. State, persistence, sharing

- **In-session:** the selection set lives in the Stimulus controller, re-applied after frame
  reloads. This is enough for the core "pick → compare → close → keep browsing" loop.
- **Shareable (fast-follow, optional):** mirror the set into a `?compare=slug,slug` URL param so a
  comparison is linkable and survives refresh — consistent with how `/compare` already
  canonicalizes its permutations. Not required for v1; the "Open full comparison →" link already
  gives a shareable artifact via `/compare?models=…`.

## 7. Mobile

- The checkbox is always visible (no hover affordance) and gets a comfortable tap target.
- The table already scrolls horizontally; the comparison **grid** would too at 3–4 columns.
  Prefer a **transposed** layout in the dialog on narrow viewports: metric labels run down a
  fixed left column, each model is a horizontally-scrolling column — so the labels stay anchored
  while the user swipes across models. (Desktop keeps the current label-left, models-across grid.)
- The tray collapses to count + **Compare (N)**; individual chips scroll horizontally.

## 8. Accessibility

- Checkboxes are real `<input type="checkbox">` with per-row `aria-label` ("Select {model} to
  compare"); Space toggles, independent of the row link in the tab order.
- The tray is an `aria-live="polite"` region announcing "{n} models selected".
- `<dialog>` + `showModal()` gives focus trapping, `Esc`-to-close, and inert background for free;
  focus returns to the **Compare** button on close. Dialog has `aria-label` "Model comparison".
- Winner cells keep a non-colour cue (the existing check mark), not colour alone.

## 9. Copy (house voice — describe, don't prescribe)

- Tray button: **`Compare (3)`** — not "Compare now" or "Compare these 3 amazing models".
- Tray empty/secondary: the tray simply isn't shown at zero; no "Select models to get started"
  nudge.
- Cap tooltip: **`Compare up to 4 models`** — the fact, not an apology.
- Dialog title: **`Comparing 3 models`**.
- Footer link: **`Open full comparison →`** (states the destination, per the cross-link rule).
- Checkbox label: **`Select {model} to compare`**.

## 10. Open questions

1. **Tray vs ticker stacking.** Stack the tray above the ticker, or have the active tray replace
   the ticker for the duration of a selection? Stacking is simpler and less surprising.
2. **N cap.** 4 is the proposed ceiling; confirm that's the right cap for the grid's readability.
3. **Shareable URL in v1?** Ship the `?compare=` table-state param now, or defer and rely on the
   "Open full comparison →" link for shareability?
4. **Modal vs straight-to-page.** Keep the in-place `<dialog>` (recommended — stays in the
   browsing context), or have **Compare** navigate directly to `/compare?models=…`? The dialog is
   the better feel; the page is less to build.

## 11. Build phases

1. **Shared grid partial + N-way controller.** Extract `_grid.html.erb`, generalize `winner_for`,
   teach `comparisons#show` the `?models=` form. `/compare` keeps working unchanged. Fully
   testable server-side before any table UI exists.
2. **Table selection + tray.** Add the checkbox cell (stateless, cache-safe), the
   `model_selection_controller`, and the sticky tray with cap + frame-reload persistence.
3. **The dialog.** Native `<dialog>` + `comparison` turbo-frame wired to the grid endpoint;
   footer link to the full page.
4. **Mobile + a11y polish.** Transposed grid on narrow viewports, live-region announcements,
   focus return.
5. **(Optional) shareable `?compare=` table state.**
