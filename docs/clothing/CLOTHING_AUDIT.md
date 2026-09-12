# CLOTHING_AUDIT — Phase C1 (2026-09-12)

Audit of the clothing/wardrobe/appearance implementation. All claims file:line verified via explore subagent. Commit at audit time: `2b5850e` (+ uncommitted sunset_quests WIP).

## 1. Architecture map

**sunset_clothing** (client/main.lua 330L, client/wardrobe.lua, server/main.lua 41L) — thin shop shell. Includes `@sunset_appearance/client/appearance_lib.lua` + `clothing_compat.lua` (fxmanifest.lua:18-19). Deps: core, ui, world, appearance.

**sunset_appearance** — owns the clothing application library used by EVERYONE:
- `appearance_lib.lua`: `SunsetAppearance.default/normalize/apply/setComponentSafe/syncTorso/buildEditor`; safe setter clamps drawables/textures via `GetNumberOfPed*Variations` (:66-100).
- `clothing_compat.lua`: category table (:5-14), catalog builder (:196-210), preview apply (:132-169), `syncFromPed` (:231-253), faction outfit merge (:213-229).
- `torso_data.lua` + `data/besttorso_male.json`/`besttorso_female.json`: top-drawable→torso-drawable mapping (community besttorso data). `getBestTorso(gender, top.drawable, top.texture)` (:15-29), fallback M=15/F=14 (appearance_lib.lua:200).

**Flow trace:** world zone E (`Sunset.ClothingShops`, core/shared/items.lua:202-210) → `sunset:world:openClothing` → `openWardrobe()` (clothing main.lua:188) → snapshot from `char.appearance` + `syncFromPed` (main.lua:19-32,121) → NUI `wardrobeShow` catalog (main.lua:134) → JS `wardrobe.js` (+/- raw drawables) → `sunset:nui:wardrobePreview` → `setCategorySelection` (clamp+IsPedPropValid, clothing_compat.lua:76-108) → `applyPreviewToPed` LIVE on networked ped → purchase (hold-to-confirm) → `sunset:payAppearance` (server $50 flat, proximity 15m, cash-then-bank; server/main.lua:22-41) → `sunset:saveAppearance` → `UPDATE characters SET appearance=?, gender=?` (appearance server/main.lua:23-28).

**Restore paths:** ESC/close → `restoreSnapshot` re-applies saved appearance (main.lua:19-39,82-97). Login/spawn → sunset_spawn `ApplyAppearance` (spawn client/main.lua:77-80). Duty on → `ApplyFactionLoadout` merge uniform over civilian (loadout.lua:157-166). Duty off → `ClearFactionLoadout` re-applies `char.appearance` client cache (loadout.lua:216-232).

## 2. Persistence format (v2, characters.appearance JSON)

```json
{ "version": 2,
  "headBlend": {shapeFirst,shapeSecond,shapeThird,skinFirst,skinSecond,skinThird,shapeMix,skinMix,thirdMix},
  "hair": {drawable,texture,color,highlight},
  "overlays": {"1":{index,opacity,color},"2":{...}},
  "components": {"1":{drawable,texture},"3":{..},"4":{..},"5":{..},"6":{..},"7":{..},"8":{..},"11":{..}},
  "props": {"0":{drawable,texture},"1":{..},"2":{..}} }
```
Legacy v1 migrated by normalize (appearance_lib.lua:181-192). No tattoos. Components 0/2/9/10 not persisted as components. No outfit tables, no ownership tables (grep sql/*.sql: only 01-sunset.sql:33).

## 3. Faction uniforms (core/shared/faction_outfits.lua)

`leoOutfit(top,pants,opts)` → slots {1:{0,0}, 4, 6, 8, 11, opt 3}. LSPD grades 0-7: M tops 55-62, F tops 48-55, pants M35/F34, shoes 25, undershirt M58/F35 (:22-56). EMS M 250-257/F 258-265, pants M96/F99 (:58-70). Fire M 314-321/F 322-329 (:72-84). Service presets (mechanic/taxi/cartel/syndicate) :86-148. Alternative full ped-model skins `Sunset.FactionSkins` (:223-525). Torso IS synced on uniform merge (clothing_compat.lua:227) — uniforms don't suffer the hole bug.

## 4. Native inventory (all call sites)

SetPedComponentVariation: appearance_lib.lua:34 (hair), :98 (setComponentSafe); clothing main.lua:259 (barber raw!); loadout.lua:76 (fallback uniform); npc_lib.lua:41; trucker_npc.lua:194. SetPedPropIndex/ClearPedProp: clothing_compat.lua:112-122; npc_lib.lua:47-49; trucker_npc.lua:198-201. SetPedDefaultComponentVariation: appearance main.lua:75, loadout.lua:131, spawn main.lua:74. **Zero collection natives** (SetPedCollectionComponentVariation etc.) — base-game drawables only; streamed addon clothing unsupported.

## 5. Bugs & risks (numbered — feeds C2-C12 design)

| # | Sev | Bug | Evidence |
|---|---|---|---|
| B1 | CRIT | `saveAppearance` accepts ANY client JSON: no schema validation, no proximity, no rate limit → arbitrary appearance injection persisted; also client-controlled gender write | appearance server/main.lua:7-34 |
| B2 | HIGH | Preview applied to NETWORKED ped — all players see unpaid clothes; also preview baseline absorbs faction uniform if shopping while on duty → uniform persisted as civilian | clothing main.lua:121,229 |
| B3 | HIGH | No death/disconnect/onResourceStop cleanup: camera, inShop flag, ESC thread, `sunset:world:uiModalOpen` leak | clothing main.lua (absent handlers) |
| B4 | HIGH | Pay-then-save: if saveAppearance fails after payment, money lost (no refund) | clothing main.lua:240-251 |
| B5 | HIGH | Hospital respawn never re-applies appearance or duty uniform | death client/main.lua:32-68 |
| B6 | HIGH | Server-restart: OnDuty memory-only, no dutyState(false) to connected players → uniform+weapons stuck; client-restart: dutyWeapons table lost → weapons unremovable | factions core.lua:2-4, loadout.lua:1 |
| B7 | MED | Flat $50 regardless of items changed; duplicated price constants client/server | clothing_compat.lua:3, server/main.lua:1 |
| B8 | MED | Barber hair: raw unclamped NUI value applied + persisted | clothing main.lua:256-287 |
| B9 | MED | Undershirt not user-facing; editor component changes always texture 0; torso sync has no undershirt awareness (keys only on top) | clothing_compat.lua:5-14, appearance_lib.lua:350-358 |
| B10 | MED | Female defaults use male-ish drawables (8→15, 11→15 both genders) relying on clamp fallback | appearance_lib.lua:126-132 |
| B11 | LOW | Pants forced >=1 (can't store drawable 0); raw drawable numbers in UI; duplicate ESC paths; no walk-away close | appearance_lib.lua:218, wardrobe.js:146-151 |
| B12 | INFO | Categories missing: armor(9), decals(10), ears(prop2), watches(prop6), bracelets(prop7) | clothing_compat.lua:5-14 |

## 6. What ALREADY works (do not break)

- besttorso JSON mapping + syncTorso on top change (the core hole-prevention mechanism exists for the 8 exposed categories).
- setComponentSafe clamping on apply (invalid DB values can't crash appearance).
- Snapshot/restore on ESC/cancel.
- Server-authoritative price + proximity on purchase.
- Uniform merge keeps face/hair from civilian appearance.
- v1→v2 normalize migration pattern (template for v3).

## 7. Root cause of the user-reported holes

The besttorso data covers **base-game top drawables only**. Holes appear when: (a) tops from DLC/collection ranges are reached by raw numeric browsing beyond base counts (catalog max = `GetNumberOfPedDrawableVariations` includes merged DLC drawables, but besttorso JSON may lack entries → fallback torso 15/14 is WRONG for many DLC tops); (b) undershirt (8) is force-defaulted to 15 and never re-matched to the top (many tops need specific undershirt 0/none or a matched torso+undershirt pair); (c) editor path resets textures to 0, desyncing texture-keyed torso lookups. C4 must: extend compat data with undershirt-aware tuples (top → {torso, defaultUndershirt, allowedUndershirts}), validate against curated whitelist instead of raw full range, and provide the /clothingdebug authoring tool (C11) to extend mappings.
