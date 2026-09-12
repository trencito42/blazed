# CLOTHING_STATE — Resumable Checkpoint

**Status:** PHASE C1 (audit) COMPLETE — implementation NOT started. Work PAUSED at user request to finish the prior plan (Phases 3-9: quests/jobs/factions/UI streams), then RESUME clothing from Phase C2.

**Priority when resumed:** C4 top↔torso↔undershirt compatibility is the highest priority (user-visible broken outfits: chest holes, wrong layering).

## Audit results (C1) — full details in subagent report summary below

Key facts discovered (all verified with file:line in CLOTHING_AUDIT.md):
- sunset_clothing has NO own component logic; it @-includes sunset_appearance/client/appearance_lib.lua + clothing_compat.lua.
- Torso auto-sync ALREADY EXISTS: `SunsetAppearance.syncTorso` via besttorso_male/female.json (`TorsoData.getBestTorso`), triggered on component 11/8 change. Fallback M=15/F=14.
- Categories exposed: hat(prop0), mask(1), glasses(prop1), accessory(7), top(11, syncTorso), pants(4), shoes(6), bag(5). NOT exposed: undershirt(8), armor(9), decals(10), ears(prop2).
- Persistence: single `characters.appearance` JSON column (v2 format: headBlend/hair/overlays/components/props). No outfits/clothes tables exist. No ownership concept — flat $50 "save the look" fee.
- Preview: applied LIVE to networked ped (others see unpaid clothes); DB written only on purchase. Snapshot/restore exists for ESC/cancel, but NO death/disconnect/onResourceStop cleanup.
- Faction uniforms: sunset_core/shared/faction_outfits.lua — component-slot maps {1,4,6,8,11(+3)} per grade/gender; applied via ApplyFactionOutfit merge over civilian appearance; restore from char.appearance cache (no explicit snapshot).
- Server validation: `sunset:saveAppearance` accepts ANY client JSON (no schema validation, no proximity check) — CRIT security issue (arbitrary appearance injection).
- Known bugs (16 listed in audit): flat pricing regardless of items; pay-then-save failure loses money; uniform absorbed into civilian baseline if shopping while on duty; hospital respawn doesn't re-apply appearance; duty weapon leak on client restart; server-restart uniform stuck; raw drawables in UI; female defaults use male-ish drawables; pants forced >=1; barber hair raw unclamped apply.

## Phases remaining

| Phase | Description | Status |
|---|---|---|
| C1 | Audit | DONE |
| C2 | Canonical representation + compat model design | PENDING (start here) |
| C3 | Validation + catalog module (server-side schema validation of saveAppearance is part of this) | PENDING |
| C4 | Top↔torso↔undershirt compat (HIGHEST PRIORITY) | PENDING |
| C5 | Full categories (undershirt user-facing w/ compat filter, armor, decals, ears, watches, bracelets) | PENDING |
| C6 | Preview transaction (local ped only, not networked; death/disconnect/restart restore) | PENDING |
| C7 | Purchase/persistence (per-item pricing server-side, refund on save failure) | PENDING |
| C8 | Saved outfits/wardrobe (new table `character_outfits`) | PENDING |
| C9 | Faction uniforms via clothing engine (validated presets) | PENDING |
| C10 | Collection/add-on support (SetPedCollectionComponentVariation path) | PENDING |
| C11 | /clothingdebug dev tool (admin-gated) | PENDING |
| C12 | Regression + CLOTHING_IMPLEMENTATION_REPORT.md | PENDING |

## Resume instructions

1. Read this file + docs/clothing/CLOTHING_AUDIT.md.
2. Do NOT rewrite from scratch — evolve sunset_appearance (compat lib) + sunset_clothing (shop/wardrobe) per the brief's absolute rule.
3. Design decisions pending (C2): snapshot format extension (add `version:3` with collections support?), outfit table schema, pricing model (per-component vs per-outfit), UI naming strategy (generic "Jacket 032" names).
4. After each phase: lua/js syntax check + update this file + commit.
