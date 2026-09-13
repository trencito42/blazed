# NUI Performance Diagnosis — login freeze / "FiveM Not Responding" (~5s) + sluggish UI

**Symptom:** After the loadscreen closes and the login page appears, the whole PC freezes for
~5 seconds, FiveM shows "Not Responding", and the UI feels slow/heavy afterwards.

**Root cause (summary):** `sunset_ui`'s NUI page is a monolith. At the exact moment CEF switches
from loadscreen to the NUI page, Chromium parses a 245 KB HTML file with ~1,180 divs, ~50 CSS
stylesheets (incl. a 243 KB icon CSS), and ~47 synchronous JS modules — while simultaneously
decoding ~1.5 MB of background images and ~1.9 MB of TTF fonts. This blocks the CEF render
thread; FiveM's main thread waits on the NUI surface → freeze + "Not Responding".

---

## Findings (measured)

### F1. index.html loads everything up-front
`resources/[sunset]/sunset_ui/web/index.html`:
- 245 KB HTML, ~1,179 `<div>` elements, all panels/screens for the entire game in one page.
- ~50 `<link rel="stylesheet">` in `<head>` (all render-blocking).
- ~47 `<script src>` **without `defer`/`async`** at the end of `<body>`.
- Only ~3 JS modules are needed for the auth screen (`app.js`, `auth_*.js`, maybe `panels.js`),
  but phone (57 KB), mdc_tablet (61 KB), panels (88 KB), chat (43 KB), leaflet (144 KB),
  dealership, clans, factions, atm, battlepass etc. all load and execute at boot.

### F2. phosphor.css = 243 KB, Phosphor.ttf = 477 KB
- The full Phosphor icon set (thousands of icon classes) is loaded for the ~30 icons actually used.
- `.ttf` font files are uncompressed; `Phosphor.woff2` (144 KB) already exists alongside but
  check which `@font-face` src order wins in `assets/phosphor/phosphor.css` — TTF must not be first.

### F3. Fonts: 4× Rajdhani TTF (343–364 KB each ≈ 1.4 MB) + chakra-petch TTFs
- TTF decoding is much heavier than woff2. Convert to woff2 (~70% smaller, faster parse).

### F4. `preloadEntryBackgrounds()` at DOMContentLoaded (app.js:1155)
- Decodes 3 backgrounds simultaneously exactly at the critical transition:
  `bg.webp` (531 KB), `bg_loading.webp` (531 KB), `bg_login.webp` (414 KB).
- The `<link rel="preload" href="assets/bg_loading.webp">` in index.html adds a 4th fetch.

### F5. Loadscreen assets unoptimized
- `sunset_loadscreen/assets/sunset.png` = **2.1 MB** PNG (logo.webp equivalent already exists).

### F6. Everything is one CEF page for the whole session
- Even after login, all 50 CSS files stay in the style-recalc graph. Any DOM churn
  (HUD updates, chat messages) re-evaluates against all of them → "UI pare slow/heavy" permanent.

---

## Fix plan (ordered by impact/effort)

### Phase 1 — quick wins (no restructuring, biggest impact on the freeze)

1. **Add `defer` to all game-phase scripts in index.html.**
   Keep synchronous only what the auth screen needs:
   `app.js`, `auth_accounts.js`, `auth_email.js`, `auth_loading.js`, `auth-forza.js`,
   `characters.js`, `spawn.js`, `overlays.js` (verify order deps — `defer` preserves order,
   so simply adding `defer` to ALL scripts is safe as long as nothing relies on being
   executed before `DOMContentLoaded` listeners registered by later scripts).

2. **Lazy-load non-auth modules until after login.** Two options:
   - a) inject `<script defer>` on `sunset:client:authenticationComplete` / `playerReady` NUI msg; or
   - b) keep `defer` (step 1) — often enough, since deferred scripts no longer block first paint.

3. **Defer background preloading.** In `app.js`, change `DOMContentLoaded → preloadEntryBackgrounds()`
   to preload only the CURRENT screen's bg, and `requestIdleCallback(() => warm rest, 2000ms delay)`.
   Drop the `<link rel="preload">` for `bg_loading.webp` from index.html (the `<img>` already loads it).

4. **Convert fonts to woff2 and subset them.**
   - Rajdhani 400–700 + chakra-petch: `pyftsubset` or online converter → woff2 (~1.4 MB → ~350 KB).
   - Phosphor: subset to used glyphs (`ph-*` classes actually referenced in html/js/css) → 477 KB TTF → ~10–20 KB woff2. Keep `font-display: swap`.

5. **Optimize sunset.png (2.1 MB) → webp** in sunset_loadscreen (there is already a
   `logo.webp`; if sunset.png is the hero art, convert it: expect ~200–300 KB).

6. **Shrink backgrounds:** bg.webp / bg_loading.webp / bg_login.webp at 414–531 KB are large for
   1080p webp; re-encode at quality ~72–78 → ~150–200 KB each. `gta-map.jpg` (654 KB) → webp too.

### Phase 2 — structural (removes the permanent heaviness)

7. **Load CSS per-phase.** Split index.html's 50 stylesheet links: keep only
   `fonts/style/theme/_cef_overrides/auth-forza/auth_loading/nui_loading` in `<head>`;
   inject the rest via JS (`document.head.appendChild(<link>)`) grouped by system,
   triggered on first use (phone → phone.css, mdc → mdc_tablet.css, etc.).

8. **phosphor.css pruning:** generate a CSS with only the used `.ph-*`/`.ph-bold`/`.ph-fill` classes
   (grep the codebase for class names; the full file has thousands of unused selectors that
   inflate every style recalc).

9. **Consider splitting the auth screen into its own tiny ui_page** shown before login and the
   full `sunset_ui` page initialized only after `playerReady` (bigger refactor; only if
   Phase 1+2 aren't enough).

### Phase 3 — verification

10. After deploy, reproduce the connect flow and watch:
    - Freeze should disappear from the loadscreen→login transition.
    - In-game: open phone/menu/chat and confirm no hitch on first open.
    - `docker logs blazed-fivem-1 --since 3m | grep -i testdriver` → `all: 56 checks, 0 failed`.
    - Static checks before commit (see AGENTS.md): `node scripts/check-nui-bridge.js` etc.

---

## Expected gains

| Fix | Login freeze | Ongoing UI |
|---|---|---|
| defer + lazy scripts (1–3) | −2–3 s | snappier first paints |
| font subsetting (4) | −0.5–1 s | less memory |
| image optimization (5–6) | −0.5–1 s | faster bg swaps |
| CSS split + phosphor prune (7–8) | −0.5–1 s | big: fewer style recalcs |

Combined: the ~5 s freeze should drop to under ~1 s.

## Notes

- All changes are in `sunset_ui/web/*` + `sunset_loadscreen/assets/*` — **client-side only,
  no Lua logic changes required** except none. `check-nui-bridge.js` must still pass.
- `phosphor.css` MUST keep the `_cef_overrides.css` last-in-order rule (see index.html comment:
  backdrop-filter disabled for FiveM Chromium).
- When subsetting fonts, keep Romanian diacritics coverage (ș/ț/ă/â/î) for staff-facing text.
- ⚠️ Coordinate with any running agent session: `app.js`, `store247.js` are currently being
  edited by another agent (Store247 work). Apply Phase 1 items 1–3 to `app.js` only after that
  work is committed.
