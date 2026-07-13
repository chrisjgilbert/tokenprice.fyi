---
name: verify
description: Boot the app and drive changed pages/features with a real browser (Playwright) before calling a change verified.
---

# Verifying tokenprice.fyi changes

## Boot

```bash
bin/rails tailwindcss:build   # REQUIRED if you touched app/assets/tailwind/application.css —
                               # `bin/rails server` alone does NOT compile Tailwind; only `bin/dev`
                               # (which also runs `tailwindcss:watch`) does. Skipping this means the
                               # browser silently falls back to UA-default styles with no error.
bin/rails server -p 3099 -d
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3099/up   # expect 200
```

## Drive it

Node + Playwright are globally installed but not in this repo's `node_modules`, so resolve manually:

```bash
NODE_PATH=/opt/node22/lib/node_modules node your_script.js
```

```js
const { chromium } = require('playwright');
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
```

For anything involving hover/popover/CSS: don't just curl the HTML — that only proves markup exists,
not that styles applied. Read `getComputedStyle()` on the actual element, not just `getBoundingClientRect()`
(a `:popover-open` UA-default and a correctly-styled popover can have suspiciously similar-looking
bounding boxes at a glance).

## Teardown

```bash
pkill -f "puma.*3099"
```
