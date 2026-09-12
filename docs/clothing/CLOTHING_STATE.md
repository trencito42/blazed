# CLOTHING_STATE — Resumable Checkpoint

**Status (2026-09-12, commit 838260a+, DEPLOYED to VPS):** Phases C1-C11 DONE (C4 = rules system live, blocked-lists populated via /clothingdebug as holes are found in-game). C12 static side done; runtime matrix in CLOTHING_IMPLEMENTATION_REPORT.md �10 (user tests). See CLOTHING_IMPLEMENTATION_REPORT.md for the full report.

## What is DONE (deployed, static-checked green)

- **Root cause of "hat stays after duty" FIXED:** props (hats/glasses/watches/bracelets/ears) were never applied by `SunsetAppearance.apply` — only components. Added `applyProps` + `setPropSafe` (validation, -1=ClearPedProp). This was THE bug the user reported.
- **C2/C3 canonical helpers:** `GetClothingSnapshot`/`ApplyClothingSnapshot` exports (components 0-11 + props 0,1,2,6,7). Server-side `sanitizeAppearance`/`ValidateAppearance` (B1 CRIT: saveAppearance no longer stores hostile JSON).
- **C4 top↔torso:** besttorso JSON auto-sync was ALREADY present and works for base-game tops; torso_data JSON load path fixed (broke when @-included). Undershirt now user-facing (C5). Remaining: DLC/collection tops beyond base besttorso still need manual entries via /clothingdebug (C11 done).
- **C5 categories:** undershirt(8), vest(9), ears(prop2), watch(prop6), bracelet(prop7) added; were missing.
- **C6 preview transaction:** snapshot/restore existed; ADDED death/disconnect/resource-stop cleanup (forceCloseAll) + walk-away close + refund-on-save-fail (B4).
- **C7 purchase:** server-authoritative price + proximity (existed); refund path added.
- **C8 saved outfits:** NEW table `character_outfits` (sql/45), `/outfits list|save|wear|delete`, server-validated, max 8, own-char only.
- **C9 faction uniforms:** lifecycle fixed — exact civilian snapshot before uniform, restore after; respawn/restart re-apply; duty refused while shopping.
- **C11 /clothingdebug:** admin-4+ tool, dumps state + prints compat JSON.
- **UX:** player-friendly names ("Top 032"/"None"), blacklist hooks.

## What is NOT done / remaining (honest)

- **C10 collection/add-on clothing:** NOT implemented. Still zero `SetPedCollectionComponentVariation` usage. If you add streamed custom clothes later, they won't be selectable until this is built. (No custom clothes shipped today, so not blocking.)
- **C12 runtime regression:** the 19-scenario test matrix (male/female × tops/jackets/undershirts/textures, preview cancel, duty on/off, death, restart) is NOT executed — needs a real client. Static checks pass; visual/behavioral confirmation pending YOUR in-game test.
- **NUI outfit panel:** outfits are command-driven (`/outfits`), not a fancy UI panel. Functional, not polished.
- **Undershirt compatibility filtering:** undershirt is now selectable but NOT yet filtered to "only undershirts compatible with current top" — it relies on torso auto-sync. True allowed-undershirts-per-top metadata (the brief's example model) is NOT built; would need authored data.
- **Clipping guarantee:** eliminated the KNOWN broken path (props never applied + uniform absorbed). Cannot guarantee zero clipping on all GTA anims (brief acknowledges this is impossible).

## Resume instructions
1. Read this + CLOTHING_AUDIT.md.
2. Next work = C10 (collections) only if adding custom clothes; otherwise C12 runtime testing by user, then close.
3. Do NOT rewrite sunset_appearance/clothing — evolve. Static checks: `node scripts/check-nui-bridge.js`, `check-db-writes.js`, luaparse harness.
