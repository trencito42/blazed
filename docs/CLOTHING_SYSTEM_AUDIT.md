# Clothing System Audit — SunsetMP

**Date:** 2026-09-11  
**Scope:** Full repository audit before wardrobe / compatibility rewrite  
**Design target:** `server redesign/wardrobe.html` (Forza-style clothing UI — not yet integrated)

---

## Executive summary

The server has a **partial** appearance stack centered on `sunset_appearance/client/appearance_lib.lua`, but clothing is applied through **multiple independent paths** that do not share one catalog or one atomic outfit applier. Upper-body rendering depends on the GTA combination **component 3 (UPPR) + component 8 (ACCS) + component 11 (JBIB)**. The current code often sets **only component 11** (shop preview) or sets **11 + hardcoded 3/8** (faction) without validating pairs against live ped capabilities or collection-local indices.

**Root cause class for transparent torso / missing chest (screenshot bug):**  
**Type A — invalid outfit combination** (wrong UPPR for selected JBIB, or preview without torso sync). This is the most likely cause for civilian clothing and LEO freemode uniforms.

**Type B — missing addon asset** (EMS tops 250+, fire tops 314+, etc. with no streamed `.ydd`/`.ytd`/`.ymt` in repo). `SetPedComponentVariation` may succeed while nothing renders.

**No custom clothing stream packs exist in this repository.** Faction EMS/fire drawable IDs assume external assets that are not shipped.

---

## 1. Resources and files map

### Appearance core
| Resource | Path | Role |
|----------|------|------|
| `sunset_appearance` | `client/appearance_lib.lua` | Normalize, apply, editor fields, `syncTorso`, `setComponentSafe` |
| | `client/torso_data.lua` | Loads `data/besttorso_*.json` |
| | `data/besttorso_male.json`, `besttorso_female.json` | Top texture → best torso drawable (global IDs) |
| | `client/main.lua` | First-spawn studio, `/relook`, camera, save |
| | `server/main.lua` | `sunset:saveAppearance` → `characters.appearance` |

### Clothing / barber shops
| Resource | Path | Role |
|----------|------|------|
| `sunset_clothing` | `client/main.lua` | Shop open, snapshot, preview, persist, restore |
| | `server/main.lua` | `sunset:payAppearance` ($50, proximity) |
| | Inlines `appearance_lib.lua` via shared copy in fxmanifest |

### Faction uniforms
| Resource | Path | Role |
|----------|------|------|
| `sunset_core` | `shared/faction_outfits.lua` | `leoOutfit()`, grade builders, `FactionSkins` |
| | `shared/factions.lua` | 10 factions, `loadout` wiring |
| `sunset_factions` | `client/loadout.lua` | Duty on/off, freemode components OR NPC ped swap |

### Persistence & spawn
| Resource | Path | Role |
|----------|------|------|
| `sunset_core` | `server/player.lua`, `server/main.lua` | `characters.appearance` JSON column |
| `sunset_characters` | `client/main.lua` | Empty appearance → editor required |
| `sunset_spawn` | `client/main.lua` | Freemode model + `ApplyAppearance` |

### World interaction
| Resource | Path | Role |
|----------|------|------|
| `sunset_world` | `client/main.lua` | Clothing/barber zones → events |
| `sunset_core` | `shared/items.lua` | `Sunset.ClothingShops`, `Sunset.BarberShops` coords |

### UI (implemented — primitive)
| Resource | Path | Role |
|----------|------|------|
| `sunset_ui` | `web/index.html` `#clothing`, `#appearance-studio` | Legacy panels |
| | `web/js/panels.js` | `showClothing()` — top drawable ◀/▶ only |
| | `web/css/panels.css` | Basic clothing styles |

### UI (design — not wired)
| Path | Role |
|------|------|
| `server redesign/wardrobe.html` | Full Forza wardrobe: categories, model/texture sliders, hold-to-buy, camera hints |

### Custom clothing assets
**None found.** Zero `.ydd`, `.ytd`, `.ymt` files. No `[clothing]` resource folder. No `SHOP_PED_APPAREL_META_FILE` manifests in repo.

---

## 2. GTA component model (what the rewrite must respect)

| ID | Internal name | Player-facing category |
|----|---------------|------------------------|
| 0 | HEAD | Face (head blend, not component variation in current system) |
| 1 | BERD | Masks |
| 2 | HAIR | Hair |
| 3 | **UPPR** | **Upper body / arms / sleeve geometry** |
| 4 | LOWR | Pants |
| 5 | HAND | Bags / parachute |
| 6 | FEET | Shoes |
| 7 | TEEF | Neck accessories |
| 8 | **ACCS** | **Undershirt / inner layer** |
| 9 | TASK | Armor / vest |
| 10 | DECL | Decals / badges |
| 11 | **JBIB** | **Outer top / jacket / shirt** |

Props: 0 hat, 1 glasses, 2 ears, 6 watch, 7 bracelet.

**Critical rule:** JBIB alone does not define the visible torso. UPPR + ACCS + JBIB must be resolved as one **upper-body outfit**.

---

## 3. Current appearance JSON schema (v2)

Stored in MySQL `characters.appearance`:

```json
{
  "version": 2,
  "headBlend": { "shapeFirst", "shapeSecond", "shapeThird", "skinFirst", "skinSecond", "skinThird", "shapeMix", "skinMix", "thirdMix" },
  "hair": { "drawable", "texture", "color", "highlight" },
  "overlays": { "1": { "index", "opacity", "color" }, "2": { ... } },
  "components": {
    "3": { "drawable", "texture" },
    "4": { "drawable", "texture" },
    "6": { "drawable", "texture" },
    "8": { "drawable", "texture" },
    "11": { "drawable", "texture" }
  }
}
```

**Missing from persistence:** collection names, local drawable indices, props, masks (1), bags (5), accessories (7), vests (9), decals (10), face features, eye color, tattoos.

**Gender:** `characters.gender` (0 male / 1 female) → `mp_m_freemode_01` / `mp_f_freemode_01`.

---

## 4. `SetPedComponentVariation` call sites

| Location | Slots | Palette | Notes |
|----------|-------|---------|-------|
| `appearance_lib.lua` `setComponentSafe` | 3,4,6,8,11 | 2 | Clamps + nearest usable drawable |
| `appearance_lib.lua` `applyHair` | 2 | 2 | |
| `sunset_clothing` `applyPreview` | 11 or 2 | **0** | **No torso sync, no clamp** |
| `loadout.lua` `applyOutfitComponents` | 1,3,4,6,8,11 | 2 | Clamp max only; no `setComponentSafe` |
| `trucker_npc.lua` | 1,3,4,6 | 0 | Static NPC |

**No usage of collection natives** (`SetPedCollectionComponentVariation`, `GetPedDrawableVariationCollectionLocalIndex`, etc.) anywhere in repo.

---

## 5. Current apply order (`SunsetAppearance.apply`)

1. `applyClothes`: pants (4) → shoes (6) → undershirt (8) → `syncTorso` → upper body (3) → outer top (11)
2. Hair component + colors
3. Head overlays (beard, eyebrows)
4. Head blend **last** (face/hands skin sync)

**Faction duty path bypasses this:** `loadout.lua` applies saved face/hair via `ApplyAppearance`, then overwrites slots piecemeal with `applyOutfitComponents` — order is mask, arms, pants, shoes, undershirt, top (numeric keys).

---

## 6. Torso compatibility (only existing engine)

**Files:** `sunset_appearance/data/besttorso_male.json`, `besttorso_female.json`

**Structure:**
```json
"<topDrawable>": {
  "<topTexture>": {
    "BestTorsoDrawable": <int>,
    "BestTorsoTexture": <int>
  }
}
```

**API:** `TorsoData.getBestTorso(gender, top, topTexture)` → used by `SunsetAppearance.syncTorso` when slot 8 or 11 changes.

**Limitations:**
- Global drawable IDs only (no collection)
- Many entries are `BestTorsoDrawable: -1` (no mapping)
- **No undershirt compatibility table** — undershirt is never auto-resolved from top
- **No validation** that resolved torso is valid for current ped after game updates
- Shop preview **does not call** `syncTorso` until purchase

---

## 7. Clothing store flow (current)

```
[E] at shop (sunset_world)
  → sunset:world:openClothing
  → captureSnapshot()
  → clothingShow { type: 'clothing', drawable: current top }
  → UI: component 11 only, drawable 0–40 hard cap, no texture picker
  → clothingPreview → SetPedComponentVariation(11, drawable, 0, 0)  // broken preview
  → clothingApply → pay $50 → persist → syncTorso → full apply
  → clothingClose → restoreSnapshot()
```

**Barber:** hair slot 2 only, same $50 flow.

---

## 8. Faction uniform system

### Config builders (`faction_outfits.lua`)

`leoOutfit(top, pants, opts)` produces:
```lua
{
  [1] = mask,
  [3] = arms,      -- opts.arms, often 0 for LSPD grade 0
  [4] = pants,
  [6] = shoes,
  [8] = undershirt, -- often 58 (LEO) or 15
  [11] = top,
}
```

### LEO example (male grade 0 LSPD)
- Top JBIB: **55**
- UPPR: **0** (default in `leoOutfit`)
- ACCS: **58**
- LOWR: **35**

**Risk:** `arms = 0` with top 55 is a **known high-risk combination** on freemode without per-top validation. Sheriff uses `arms = 19`; FIB grade 0 uses `arms = 12`.

### EMS / Fire (addon-dependent)
| Faction | Male top range | Female top range | UPPR in config |
|---------|----------------|------------------|----------------|
| medic | 250–257 | 258–265 | 85 / 109 |
| lsfd | 314–321 | 322–329 | 85 / 109 |

**Without addon packs these drawables do not exist on vanilla freemode** → invisible or fallback mesh.

### Dual duty visual systems
1. **Freemode + components** when `loadout.gradeOutfits` exists (default for LEO/EMS/fire with grade tables)
2. **NPC ped swap** via `Sunset.FactionSkins` + `/fskin` (SWAT, paramedic ped, etc.)

### Civilian restore on off-duty
`ClearFactionLoadout()` removes duty weapons, resets freemode model, calls `applySavedAppearance()` — **does not explicitly restore pre-duty component snapshot**. If duty overwrote `characters.appearance` in DB, civilian clothes would be lost (currently duty does **not** write appearance to DB; only runtime ped state changes).

### Bugs found
| Issue | Detail |
|-------|--------|
| `lssi` preset missing | `BuildServiceLoadout('lssi')` → falls back to **mechanic** outfits |
| Numeric vs string keys | Faction `[11]` vs appearance `["11"]` |
| No server-side uniform validation | Grade/faction checks exist for weapons, not outfit component validity |
| No curated variant IDs | One top per grade index, not named variants (Patrol, SWAT, etc.) |

---

## 9. All factions (from `Sunset.Factions`)

| ID | Label | Loadout builder |
|----|-------|-----------------|
| `police` | LSPD | `BuildLawEnforcementLoadout('lspd')` + `BuildLeoGradeOutfits('lspd')` |
| `sheriff` | San Andreas Sheriff | LEO sheriff style |
| `fib` | FIB | LEO + extra grade weapons |
| `medic` | Pillbox EMS | `BuildEmsGradeOutfits()` |
| `taxi` | Downtown Cab Co. | `BuildServiceLoadout('taxi')` |
| `mechanic` | LS Customs | `BuildServiceLoadout('mechanic')` |
| `lsfd` | LS Fire Department | `BuildFireGradeOutfits()` |
| `lssi` | LSSI | `BuildServiceLoadout('lssi')` **→ mechanic fallback** |
| `sunset_cartel` | Sunset Cartel | `BuildServiceLoadout('cartel')` |
| `night_syndicate` | Night Syndicate | `BuildServiceLoadout('syndicate')` |

---

## 10. Screenshot bug analysis (transparent torso / jacket)

**Symptom:** Jacket visible but chest/torso transparent; body geometry visible through clothing.

**Most likely mechanism:**
1. Player selects or spawns with **JBIB (11)** set to a jacket drawable
2. **UPPR (3)** does not match that jacket (wrong arms/torso mesh, or default 0/15)
3. **ACCS (8)** may clash (wrong undershirt under open jacket)
4. Shop **preview** applies only slot 11 → player sees broken state before purchase
5. Faction **LEO grade 0** uses `arms = 0` with tops 55+ without `besttorso` lookup in loadout path

**To reproduce and fix (required before claiming resolved):**
1. Add `/validateoutfit` / `/clothinglab` (planned)
2. Log live values: ped model, components 3/8/11 collection + local + global indices
3. Classify as Type A (combination) vs Type B (asset)

---

## 11. Gap analysis vs requested architecture

| Requirement | Current state | Gap |
|-------------|---------------|-----|
| Central `ClothingCatalog` | None | **Build new** |
| `ClothingCompatibilityResolver` | `syncTorso` only (top→3) | **Extend** 8, 9, validation |
| Collection-based IDs | Not used | **Migration layer** |
| `ApplyOutfit(ped, outfit)` atomic | `SunsetAppearance.apply` partial; loadout piecemeal | **Unify** |
| Manual `Compatibility.Register()` | None | **Build** |
| `/clothinglab`, `/validateoutfit` | None | **Build** |
| Faction curated complete outfits | Per-grade tables, unvalidated | **Audit + fix** |
| Duty civilian snapshot restore | Runtime appearance re-apply only | **Explicit snapshot** |
| Wardrobe UI (`wardrobe.html`) | Not integrated | **Port to sunset_ui** |
| Smart filtered undershirts | All drawables in editor | **Filter by top** |
| Preview transactions | Shop has snapshot | **Extend to wardrobe** |
| `docs/FACTION_UNIFORM_AUDIT.md` | Not yet | **Generate after resolver** |
| Performance | No per-frame clothing loops | OK |

---

## 12. Recommended rewrite architecture

```
sunset_appearance/  (or new sunset_wardrobe/)
├── shared/
│   ├── clothing_catalog.lua      -- all items, tags, faction gates
│   ├── clothing_compat.lua       -- resolver + manual overrides
│   └── outfit_schema.lua         -- v3 outfit format (collection + local index)
├── client/
│   ├── outfit_apply.lua          -- single ApplyOutfit entry
│   ├── collection_adapter.lua    -- global ↔ collection translation
│   ├── clothing_lab.lua          -- /clothinglab, /validateoutfit
│   └── wardrobe_nui.lua          -- shop + preview
├── data/
│   ├── compat_overrides/         -- JSON/Lua per pack
│   └── faction_uniforms/         -- known-good complete outfits
└── server/
    └── uniform_validate.lua      -- rank/faction server checks
```

**Outfit v3 component entry (target):**
```lua
["11"] = {
  collection = "blaze_pd",  -- "" = base game
  drawable = 5,             -- local index when collection set
  texture = 0,
  globalDrawable = nil,       -- cached at apply time for legacy
}
```

**Apply order (target):**
upperBody (3) → undershirt (8) → outerTop (11) → pants (4) → shoes (6) → accessories (7) → vest (9) → decals (10) → bags (5) → props → verify

---

## 13. `wardrobe.html` integration plan

Design file: `server redesign/wardrobe.html`

**Port to production:**
1. `sunset_ui/web/css/wardrobe-forza.css` — extract styles (English labels)
2. `sunset_ui/web/js/wardrobe.js` — category state, model/texture sliders, preview posts
3. Replace `#clothing` panel in `index.html` with wardrobe markup
4. Wire `sunset_clothing` → `wardrobeShow` with catalog payload from server/client
5. Hide HUD chrome (`hud-chrome-hidden`) while wardrobe open — same pattern as inventory
6. Hold ENTER to purchase — match design interaction

**Categories (design → component mapping):**
| UI label | Component / prop |
|----------|------------------|
| Hats | prop 0 |
| Masks | 1 |
| Glasses | prop 1 |
| Accessories | 7 |
| Tops | 11 (+ auto 3, 8) |
| Pants | 4 |
| Shoes | 6 |
| Bags | 5 |

Player never sees UPPR/ACCS/JBIB labels — resolver runs on top selection.

---

## 14. Migration strategy (do not break saves)

1. **Read v2** `components["N"].drawable/texture` as global indices
2. On load, resolve to collection + local via `GetPedDrawableVariationCollectionName` at apply time
3. On save, prefer collection format when known; keep global fallback
4. Faction uniforms: migrate `leoOutfit` tables to `FactionUniform` records with validated triples
5. Run `FACTION_UNIFORM_AUDIT.md` script against every grade × gender × faction

---

## 15. Immediate fixes (pre-rewrite hotfixes)

These are small but reduce visible bugs before full rewrite:

| Priority | Fix |
|----------|-----|
| P0 | Shop preview must call `syncTorso` + `setComponentSafe` path, not raw `SetPedComponentVariation` palette 0 |
| P0 | `loadout.lua` use `SunsetAppearance.apply` merge or shared `ApplyOutfit` after setting uniform components |
| P0 | LEO `arms = 0` → resolve via `besttorso` or curated map per top 55–62 |
| P1 | Remove hardcoded drawable max 40 in `panels.js` — use `SunsetAppearance.maxDrawable` |
| P1 | EMS/fire: either add clothing packs or switch duty to `FactionSkins` NPC models until packs exist |
| P1 | Fix `lssi` → add `SERVICE_OUTFIT_PRESETS.lssi` |
| P2 | Integrate `wardrobe.html` UI |
| P2 | `/clothinglab` for configuring custom compat |

---

## 16. Test matrix (for rewrite sign-off)

- Male/female freemode
- Base GTA jacket + t-shirt + open jacket
- Custom addon top (when packs added)
- Vest + shirt, vest + jacket
- Faction duty → off duty → reconnect
- Resource restart with saved outfit
- Views: front/back/sides, arms raised, vehicle entry
- Failures: transparent torso, missing arms/hands, undershirt clip, neck/wrist gaps

---

## 17. Unresolved broken assets (repo scan)

| Asset class | Status |
|-------------|--------|
| EMS tops 250–265 | **No stream files** — treat as broken until pack added |
| Fire tops 314–329 | **No stream files** — treat as broken until pack added |
| All other faction tops 55–62 etc. | Vanilla-range — validate combinations (Type A) |

---

## 18. Related UI fix (business panel)

**Issue:** `/mybusiness` panel left chat, location HUD, and top-right HUD visible (screenshot 2026-09-11).

**Fix applied:** `body.business-panels-open` added to HUD chrome hide rules in `sunset_ui/web/css/style.css` (same as inventory/tuning).

---

## 19. Next deliverables (per project request)

1. ✅ `docs/CLOTHING_SYSTEM_AUDIT.md` (this document)
2. ⬜ `docs/FACTION_UNIFORM_AUDIT.md` — after resolver + validation tool
3. ⬜ `docs/CLOTHING_SYSTEM_IMPLEMENTATION.md` — after rewrite
4. ⬜ Production code: catalog, resolver, ApplyOutfit, wardrobe UI, clothing lab, faction uniform migration

**Do not mark uniform or civilian combinations as fixed until component 3/8/11 values are traced and validated in-game.**

---

## Appendix A — File index for implementers

```
resources/[sunset]/sunset_appearance/
resources/[sunset]/sunset_clothing/
resources/[sunset]/sunset_factions/client/loadout.lua
resources/[sunset]/sunset_core/shared/faction_outfits.lua
resources/[sunset]/sunset_core/shared/factions.lua
resources/[sunset]/sunset_ui/web/js/panels.js          -- showClothing
resources/[sunset]/sunset_ui/web/index.html            -- #clothing
server redesign/wardrobe.html                          -- design reference
docs/CLOTHING_SYSTEM_AUDIT.md                          -- this file
```

## Appendix B — Collection natives to adopt (FiveM)

Investigate and wrap:
- `SetPedCollectionComponentVariation`
- `GetPedCollectionName` / `GetPedCollectionsCount`
- `GetPedDrawableVariationCollectionName` / `GetPedDrawableVariationCollectionLocalIndex`
- `GetPedDrawableGlobalIndexFromCollection`
- `GetNumberOfPedCollectionDrawableVariations`
- `IsPedCollectionComponentVariationValid`
- Prop collection equivalents

---

*End of audit.*
