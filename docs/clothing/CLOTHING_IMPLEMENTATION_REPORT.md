# CLOTHING_IMPLEMENTATION_REPORT — Final (2026-09-12)

**Status:** C1-C11 complete (C4 partial-by-design, see §Compatibility). C12 test matrix below — runtime rows pending user in-game verification.

## 1. Original architecture

- `sunset_clothing` = thin shop shell; all component logic lives in `sunset_appearance` shared libs (`appearance_lib.lua` apply/normalize/setComponentSafe, `clothing_compat.lua` categories/catalog/preview, `torso_data.lua` + community `besttorso_*.json`).
- Persistence: single `characters.appearance` JSON column (v2: headBlend/hair/overlays/components 1,3,4,5,6,7,8,11/props 0,1,2). No ownership concept — flat $50 "save look" fee at shop (server-authoritative price + 15m proximity).
- Faction uniforms: component-slot maps per faction/grade/gender in `sunset_core/shared/faction_outfits.lua`, merged over civilian appearance via `ApplyFactionOutfit` (torso synced).

## 2. Original bugs (root causes)

| Bug | Root cause | Fix |
|---|---|---|
| **Hat/accessories stay after off-duty; lost on relog** | `SunsetAppearance.apply` NEVER applied props (0,1,2,6,7) — only components | `applyProps` added + wired into `apply()` |
| **Uniform absorbed into civilian clothes** | Shopping while on duty snapshotted the ped (uniform) as the civilian baseline | Shop refuses while on duty |
| **saveAppearance injection (CRIT)** | Server blindly json.encode'd ANY client JSON into DB | Full `sanitizeAppearance` (bounded components/props/headBlend/hair/overlays, ownership check, 8KB cap); exposed as `ValidateAppearance` export (outfits reuse it) |
| **Money lost on save failure** | pay-then-save without refund | `refundAppearance` callback with pending-flag guard |
| **Stuck camera/focus on death/disconnect/restart** | no cleanup handlers | `forceCloseAll` + death watchdog + onResourceStop + walk-away close |
| **Barber raw hair** | unclamped NUI value applied+persisted | clamped to real drawable range |
| **Chest holes on some tops** | besttorso covers base-game only; fallback torso wrong for uncovered tops; stale undershirt kept on top change | Compatibility rules system (§4) — top change now re-resolves torso AND snaps incompatible undershirts |
| **Female defaults used male drawables** | defaults mixed | normalize + clamp (existing) + rules resolve per gender |
| pants drawable 0 impossible | forced ≥1 | documented; kept (engine quirk: pants 0 = underwear glitch on many peds) |

## 3. New architecture

```
sunset_appearance/
  client/torso_data.lua      community besttorso loader (resource-safe paths)
  client/clothing_rules.lua  NEW: top→torso→undershirt compat rules + RegisterTopCompatibility
  client/appearance_lib.lua  apply/applyProps/setPropSafe/snapshot/restore + syncTorso(combo-aware)
  client/clothing_compat.lua categories (13 incl. undershirt/vest/ears/watch/bracelet), catalog, preview, itemName
  server/main.lua            sanitizeAppearance (hardened) + ValidateAppearance export
sunset_clothing/
  client/main.lua            shop/barber flows + duty/death/walkaway/refund handling
  client/debug.lua           /clothingdebug (admin 4+): dump state, walk combos, print compat JSON entries
  server/outfits.lua         /outfits save|wear|delete (character_outfits, max 8, sanitized, own-char)
sunset_factions/client/loadout.lua
                             exact civilian snapshot before uniform, restore after (props included),
                             respawn/restart re-apply
```

Public API: `ApplyAppearance`, `GetClothingSnapshot`, `ApplyClothingSnapshot`, `RegisterClothingCollection`, `ApplyComponent`, `ValidateAppearance` (server), `ResolveTorso`.

## 4. Compatibility system (C4)

Resolution order per top selection: **authored Overrides → besttorso JSON → gender safe default**.
- Changing a top: auto-applies correct torso AND replaces the undershirt with the rule default when the current one is in the top's blocked list. Torso is never user-facing.
- Undershirt IS user-facing (category added); players can pick any non-blocked undershirt with live preview.
- New combos authored via `/clothingdebug` → "print compat entry" → paste into `clothing_rules.lua Overrides` (or `RegisterTopCompatibility` export for addon packs at runtime).
- **Honest limitation:** besttorso data is torso-only. Undershirt-blocked lists are empty by default and grow from observed holes via the debug tool — automatic inference of visual compatibility is impossible (brief acknowledges this).

## 5. Persistence & migrations

- v2 JSON kept (backward compatible); optional per-component `collection` field added (validated `^[%w_%-]+$` ≤64). Absent collection = base-game drawable (all existing characters unaffected).
- `sql/45-outfits.sql`: `character_outfits` (uk char+name, FK cascade).

## 6. C10 — streamed/addon clothing

`RegisterClothingCollection(def)` + `ApplyComponent(ped, comp, drawable, texture, collection)` route through `SetPedCollectionComponentVariation`/`SetPedCollectionPropIndex` when a collection is present, with automatic fallback to base drawables when the pack isn't streamed (never naked peds). No addon packs exist on this server today — infrastructure ready, zero behavior change until a pack registers.

## 7. Faction uniform lifecycle

On duty: exact snapshot (components 0-11 + props) → model switch if needed → uniform merge (torso synced) → weapons/armor. Off duty: snapshot restore (consumed; re-snapshotted next cycle) + appearance re-apply. Also re-applied after: hospital respawn/revive, client resource restart while on duty, death. Jail intake force-duty-off strips uniform. Uniforms never persisted to DB.

## 8. Files modified (clothing scope)

appearance: appearance_lib.lua, clothing_compat.lua, torso_data.lua, main.lua (client), main.lua (server), fxmanifest.
clothing: client/main.lua, client/debug.lua (new), server/main.lua, server/outfits.lua (new), fxmanifest.
factions: client/loadout.lua. ui: wardrobe.js (item names), index.html. sql/45.

## 9. Tests performed (static/automated)

- luaparse: all 274 Lua files PASS. JS parse: all PASS. nui-bridge: 165/165. db-writes: 0 new violations. forward-refs: 0.
- VPS deploy: 54 resources, 0 script errors, testdriver 56/56 PASS.

## 10. Runtime tests STILL NEEDED (user, in-game)

| # | Test | Expect |
|---|---|---|
| 1 | Duty on with hat/glasses → duty off | hat/glasses restored exactly |
| 2 | Shop while on duty | refused with message |
| 3 | Buy clothes → ESC | pre-shop look restored |
| 4 | Buy → walk away mid-preview | auto-close + restore |
| 5 | Die with shop open | camera/focus released, snapshot restored |
| 6 | Change top repeatedly (esp. jackets over t-shirts) | no chest holes for base-game tops; note any broken ones + run /clothingdebug to author the fix |
| 7 | Undershirt category | selectable, preview live |
| 8 | /outfits save/wear/delete | persists across relog |
| 9 | Barber: extreme hair values via NUI | clamped |
| 10 | restart sunset_clothing with shop open | no stuck camera/focus |
| 11 | Female character: tops/undershirts | correct female drawables |
| 12 | Respawn at hospital on duty | uniform re-applied |

## 11. Known GTA clipping limitations

Zero-clipping across all animations is physically impossible in GTA V (brief acknowledges). The system eliminates BROKEN combos (holes via torso rules, wrong-sex IDs, invalid textures, stale state); minor intersection during unusual animations can remain for specific top/undershirt pairs — author blocks via /clothingdebug as they're found.

## 12. Backlog

- Undershirt blocked-lists population (needs in-game observation via /clothingdebug).
- Per-item pricing model (currently flat $50/outfit change — server-side constant, trivial to extend).
- NUI wardrobe panel polish (owned-item indicators need an ownership model decision first).
- C12 female/male 20+ tops matrix (runtime, user).
