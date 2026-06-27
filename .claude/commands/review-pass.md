---
description: Full review pass on the current diff — correctness review, cleanup, then verify the app boots.
argument-hint: "[optional path or focus area]"
---

Run a complete review pass on the current working-tree diff$ARGUMENTS, in this
order. Do them as discrete steps and report what each one changed.

1. **Correctness** — run `/code-review --fix`. Surface and fix real bugs only:
   logic errors, N+1s, swallowed failures, broken edge cases. This project's
   data model is append-only (`PricePoint`s); flag anything that mutates history
   in place rather than adding a dated snapshot.

2. **Cleanup** — run `/simplify`. Reuse, simplification, efficiency. Hold the
   `CLAUDE.md` copy rules for any user-facing strings touched: cut filler, be
   specific, British spelling, no drama em-dashes.

3. **Verify** — run `/verify` (or `/run`) to boot the app and confirm the change
   works in the running app, not just that tests pass.

Stop and report immediately if step 3 fails — do not paper over a broken boot.

End with a short summary: what code-review fixed, what simplify changed, and the
verify result (pass/fail + how you confirmed it).
