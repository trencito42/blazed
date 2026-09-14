# CASINO DISCOVERY — Phase 1 (asset audit)

**Status:** PARTIAL — static verification complete; runtime probe deployed (commit 89380a1) and awaiting in-game execution. External web verification was rate-limited/404, so prop/anim/wheel hashes remain UNKNOWN until the in-game probe runs. **No implementation started** — Phase 1 is discovery only, as required.
**Rule:** anything not verified from bob74_ipl source, the live container, or in-game probe output is marked **UNKNOWN**. No hash/coordinate/animation is invented.

---

## 1. Verified assets (from authoritative local sources)

### IPLs — source: `bob74_ipl/dlc_casino/casino.lua` (live container copy, read directly)

| IPL | Purpose | Verified |
|---|---|---|
| `hei_dlc_windows_casino` | exterior windows | YES (bob74 source) |
| `hei_dlc_casino_aircon` | exterior aircon | YES (bob74 source) |
| `vw_dlc_casino_door` | casino doors | YES (bob74 source) |
| `hei_dlc_casino_door` | casino doors | YES (bob74 source) |
| `vw_casino_main` | **MAIN FLOOR interior** (slot floor, tables) | YES (bob74 source) |
| `vw_casino_garage` | garage/vault (heist) | YES (bob74 source) |
| `vw_casino_carpark` | carpark | YES (bob74 source) |
| `vw_casino_penthouse` | penthouse | YES (bob74 source) |

### Loading state — VERIFIED LIVE

- `bob74_ipl` is started on the VPS and **already loads the casino by default**:
  `client.lua:144 → DiamondCasino.LoadDefault()` gated on `GetGameBuildNumber() >= 2060`.
- Server gamebuild: `sv_enforceGameBuild 3751` (server.cfg, verified) → gate passes → **all 4 casino IPLs (Building, Main, Carpark, Garage) are already active on every client**.
- Therefore the sunset_casino config's `RequestIpl('casino_main')` is **dead code** — that IPL name does not exist anywhere in bob74_ipl. This also explains why the old NUI casino never needed a real interior.

### Interior coordinates — from bob74 comments + user measurement

| Location | Coords | Source |
|---|---|---|
| Main floor center | 1110.20, 216.60, -49.45 | bob74 comment ("Normal Version") — MATCHES user's 1100/220/-50 audit area |
| interiorExit (doors) | 1089.63, 205.89, -49.00, h 280.29 | **user-measured, VERIFIED** |
| bar | 1108.45, 208.87, -49.44, h 260.81 | **user-measured, VERIFIED** |
| cashier | 1116.03, 219.69, -49.44, h 278.57 | **user-measured, VERIFIED** |
| Penthouse | 976.636, 70.295, 115.164 | bob74 comment |
| Garage/vault | 2516.765, -238.056, -70.737 | bob74 comment |

### Interior ID

| Value | Status |
|---|---|
| Main floor interiorId | **UNKNOWN statically** — must be read in-game via `GetInteriorFromEntity(ped)` at ~1110, 216, -49. Probe `/casinoprobe` prints it. (Penthouse = 274689 per bob74, for reference only — do NOT reuse for main floor.) |

### Entity sets (SetIplPropState / ActivateInteriorEntitySet)

| Set name | Status |
|---|---|
| Main floor entity sets | **UNKNOWN** — bob74's `casino.lua` has NO entity-set table for the main floor (unlike penthouse which has full `Interior.*` sets). Runtime probe + visual check required. Likely candidates seen in community sources (`Set_Slots`, `Set_Casino_Interior_01` etc.) are NOT in our verified sources → **UNKNOWN until probed**. |

### Lucky Wheel

| Item | Status |
|---|---|
| Why wheel position empty | **VERIFIED root cause candidate**: main floor props ship with `vw_casino_main`; if a wheel area appears empty it is either (a) an inactive interior entity set (UNKNOWN name — probe will reveal via RefreshInterior/entity-set listing) or (b) the wheel prop is a separate object not instantiated by the IPL. Probe `UNMATCHED` list will show actual hashes at the wheel location (near cashier/lounge, around 1108-1116, 210-225). |
| Wheel prop hash | **UNKNOWN** — candidate names to test deployed in probe: `vw_prop_vw_lucky_wheel_01a`, `prop_vw_lucky_wheel`. `/casinoprops` will confirm validity on build 3751. |

### Slot machines / tables / chairs

| Item | Status |
|---|---|
| Slot prop hashes | **UNKNOWN** — probe tests `vw_prop_vw_slot_01a..08a`, `prop_vw_slot_01..03`, etc. In-game `/casinoscan 60` from the slot floor dumps ALL CObject hashes near the player; matched candidates print names, unmatched print raw hashes + positions (identify visually). |
| Chair prop hashes | **UNKNOWN** — probe tests `vw_prop_casino_stool_01a/02a`, `vw_prop_casino_chair_01a..03a`. |
| Blackjack table | **UNKNOWN** — probe tests `vw_prop_vw_table_casino_short_01/02`. |
| Roulette table | **UNKNOWN** — probe tests `vw_prop_casino_roulette_01/01b`. |

### Animation dictionaries

| Item | Status |
|---|---|
| Slot sit/spin anims | **UNKNOWN** — `/casinoanim` tests `anim_casino_slots@sit`, `anim_casino_slot_machine@base/sit`, `casino@slots@*`. GTA Online ships the casino game as streamed content; dicts are only valid if the client has them on build 3751. |
| Lucky wheel spin anim | **UNKNOWN** — tests `anim_casino@lucky7wheel@base/male/female`, `mp_casino@lucky7wheel@*`, `anim_casino_wof@*`. |
| Blackjack/roulette | **UNKNOWN** — tests `anim_casino_blackjack@*`, `anim_casino_roulette@*`. |
| Fallback (guaranteed generic) | Chair/stool sitting can ALWAYS be emulated with verified-generic dicts `amb@prop_human_seat_chair@base`-style seat tasks or `TaskStartScenarioAtPosition` with scenario `PROP_HUMAN_SEAT_CHAIR` — these are core GTA, not casino DLC. Marked as **emulation fallback** if casino dicts missing. |

### Sounds

| Item | Status |
|---|---|
| Slot win/lose jingles | **UNKNOWN** — GTA Online uses `CASINO_SLOT_MACHINE_*` frontend sound names/sets; probe cannot enumerate sound banks. Will test `PlaySoundFrontend(-1, 'Slot_Win', 'CASINO_SLOT_MACHINE_SOUNDS', true)` variants at implementation; fallback = generic `DLC_HEIST_HACKING_SNAKE_SOUNDS`/frontend sets already used elsewhere in the codebase. |

### Natives (verified present in FiveM client scripting)

All required natives are standard client API and already used in this codebase (verified by existing usage): `GetInteriorFromEntity`, `RefreshInterior`, `EnableIpl`, `SetIplPropState`, `GetGamePool`, `GetClosestObjectOfType`, `DoesObjectOfTypeExist`, `IsModelValid`, `IsModelInCdimage`, `CreateObject`, `RequestAnimDict`, `TaskPlayAnim`, `PlaySoundFrontend`, `GetOffsetFromEntityInWorldCoords`, `NetworkGetEntityOwner`. Server-side scripting has NO entity natives (verified: natives_server.lua lacks them) → all entity discovery/scenery is client-side; server keeps authority for reservations/payouts only.

---

## 2. Runtime probe (deployed, commit 89380a1)

Commands (all mirror output to `docker logs`):
- `/casinoprobe` — interior id + full entity dump around the player
- `/casinoscan [radius]` — entity scan, matches hashes against candidate prop names, prints UNMATCHED hashes with positions
- `/casinoanim` — tests each anim dict for load success on build 3751
- `/casinoprops` — tests each candidate prop model for validity/cdimage presence

**Procedure to complete discovery:**
1. Connect, teleport into the casino main floor (e.g. via admin `/tp 1110 216 -49`).
2. Run `/casinoanim` and `/casinoprops` once anywhere in the interior.
3. Stand at the slot bank → `/casinoscan 40`; walk to the table area → `/casinoscan 40`; stand at the Lucky Wheel spot → `/casinoscan 30`.
4. Operator copies the `[CASINOPROBE #id]` lines from `docker logs blazed-fivem-1`.
5. Fill the UNKNOWN rows below from that output → implement.

---

## 3. Implementation plan locked (pending discovery data)

1. **Chips economy** — `casino_chips` as a currency column or item via sunset_core/sunset_inventory owners (no cross-domain writes). Cashier converts cash↔chips server-side, atomic (single UPDATE with balance check, same pattern as `AddMoney`).
2. **Slots** — server reserves machine by entity handle+netId (one player per machine, `Machines[netId] = src`); client sits on the derived chair offset (from entity offsets discovered by probe); bet → server deducts chips → server result (`math.random` seeded by os.clock+entropy; server-only) → client animates reel prop/anim to result → settle exactly once (`settled` flag per reservation, cleared on stand/disconnect/restart).
3. **Lucky Wheel** — if probe shows wheel prop exists via IPL/entity set: activate entity set + `RefreshInterior(interiorId)`; else spawn verified wheel prop model at the verified wheel location with networked object owned by server-started resource. Spin = server result + client wheel anim (or SetEntityRotation interpolation if no anim — emulation, will be flagged).
4. **Blackjack/Roulette** — tables/chairs from probe data; existing server game logic (already written and sound) re-attached to physical seats; card/roulette props emulated via UI overlay on screen edge only if no native dealer scene exists (flagged as emulation).
5. **Bar** — interaction at verified bar coords; drinks = existing inventory items (`beer`, `soda`, `coffee`, `energy_drink` already in Sunset.Items) purchased with cash via sunset_economy shop pattern — no new domain writes.
6. **Exit** — teleport at verified `interiorExit` vector4.
7. **Cleanup** — reservation tables cleared on `playerDropped` + `onResourceStop`; at-most-once payout via per-reservation `settled` flag; cooldowns per source (existing pattern).

---

## 4. Emulation ledger (updated after probe)

| Feature | Native GTA Online? | Plan |
|---|---|---|
| Casino interior | YES (`vw_casino_main`, already loaded) | native |
| Slot machines | PROBABLE (props in IPL) — pending probe | native props; reels animated by native anim if dict exists, else prop rotation emulation (flagged) |
| Lucky Wheel | PARTIAL — pending probe (entity set or prop spawn) | native if entity set exists; spawned prop otherwise (still physical/synchronized, NOT NUI) |
| Dealer NPCs/scenes | UNKNOWN — GTA Online dealer behavior is script-driven, not a reusable scene | emulate with seated ped + generic anims (flagged) |
| Chip economy | N/A (server concept) | custom, server-authoritative |
| Blackjack/roulette gameplay | N/A (GTA Online logic is closed) | custom server logic + physical seats/tables |
| Win/lose sounds | PENDING probe | native frontend sounds if names verify; generic fallback otherwise |
