# SunsetMP RPG Status (Canonical)

**Last updated:** 2026-09-05
**Code baseline:** runtime commit `e1836d3`, deployed to Coolify on 2026-09-05

## Faithful `onscreenhud.txt` integration (2026-09-05, not deployed)

- Replaced the permanent legacy HUD composition with the supplied three-module screen HUD: top-right clock/money/health/armor, bottom-left compass/street/zone, and bottom-right speed/gear/RPM/engine/fuel.
- Preserved the reference geometry, clipped glass panels, segmented bars, boot motion, fixed-width speed digits and speed/gear change animations while adapting purple accents to SunsetMP orange/amber.
- Added the previously undisplayed bank balance and a live eight-direction compass value from the player heading.
- Vehicle speed remains authoritative km/h from `sunset_vehicles`; RPM, engine condition and fuel now drive the reference bars with correct zero-value handling and low/critical states.
- Reduced `/hudedit` to the three visible modules and updated the default layout schema; stale keys from older saved layouts are harmlessly ignored.
- The HUD remains hidden with the pause menu and the contextual wanted indicator appears only when applicable.
- Static visual QA was performed at 1280 x 720. JavaScript, CSS, Lua parsing, unique HTML IDs and whitespace checks passed. No server restart/deployment was performed.

## Faithful `m_menu.html` integration (2026-09-05, not deployed)

- Replaced the previous themed dashboard with the actual `SUNSET OS` composition from the supplied `m_menu.html`: matching two-column geometry, clipped technical panels, tab rail, character summary, action tiles, scanlines/glitch motion and segmented status footer.
- Kept the reference layout while adapting purple accents to the server's orange/amber identity and extending it with real Armor, Fuel, owned-vehicle diagnostics, faction/civilian employment, progression and property data.
- Vehicle cards now clamp and display authoritative fuel, engine and body percentages, including valid zero values rather than silently replacing them with 100%.
- Centralized M-menu action routing. Inventory, Animations, Phone, Documents and Licenses no longer have competing event handlers that could open an overlay and immediately close it or leave it without focus.
- Extended the same visual language to job objectives, taxi meter, notifications, generic progress, scoreboard, chat input and the lower vehicle control HUD.
- Restored the missing generic progress-bar markup used by gameplay scripts and rebuilt notification markup with explicit state titles and safe text rendering.
- Visual comparison was performed directly against `m_menu.html` at 1280 x 720. JavaScript syntax, CSS validation, unique HTML IDs and whitespace checks passed. Server restart/deployment was intentionally not performed.

## Sunset OS UI and item-art pass (2026-09-05)

- Replaced emoji item definitions with validated asset basenames and vendored the complete 232-icon, 100 x 100 WebP Swisser FiveM inventory pack (CC0 1.0, license included).
- Inventory rows and all shop catalogues now render real item artwork with a safe local fallback; dynamic labels are assigned as text rather than interpolated HTML.
- Rebuilt 24/7/Ammunation browsing as a compact vertical catalogue with category filters, a dedicated scrollbar, weight/category metadata, price and an explicit purchase action.
- Added one final-loaded Sunset OS theme shared by character/auth screens, M menu, overlay panels, dealership, mission widgets and the phone wallpaper: dark technical panels, orange/amber identity, angular corners and consistent typography without the purple accent from the design reference.
- Browser visual QA covered the 24/7 catalogue and M menu at desktop resolution; all referenced item art loaded and the browser console had no errors or warnings.

## Dealership, vehicle and crafting pass (2026-09-05)

- Added a persistent Premium Deluxe Motorsport catalog with stock, pricing, availability, filters, 3D preview, timed test drives, server-authoritative purchases and owned-vehicle delivery to Legion Garage.
- Added an Admin 3+ catalog manager (`/dealershipadmin`) for adding, editing and deleting catalog entries; administrative changes have a database audit trail.
- Vehicle engines now remain off until explicitly started with `2`; accelerator/brake input cannot silently override the selected engine state.
- Hard crashes without a seatbelt now use a reliable ejection fallback. Self-inflicted collision damage is excluded from faction friendly-fire handling, so a crash no longer produces the misleading same-faction warning.
- Crafting now validates station proximity server-side, displays owned/required material counts, explains locked recipes, and provides `/crafting` GPS guidance.
- Corrected the admin coordinate helper nil call, post-delivery Trucker partial-pay exploit, immortal job vehicles, orphaned failed-shift trucks, faction-leader leave ordering, and unpurchased barber preview retention.

## Live vehicle/menu corrections (2026-09-04)

- Personal-vehicle storage is now server-authorized before the client deletes the entity; failed ownership/driver checks return an explicit error and no longer produce a false success.
- The M-menu vehicle card overlays fuel, engine and body health from the currently driven owned entity, instead of showing stale database values until storage.
- M-menu faction info closes the NUI before opening the chat panel, so the result is visible.
- Duty notifications always use a boolean state and a faction label; faction leave no longer adds a duplicate generic notification.
- Fuel-pump input is edge-triggered after each fill. Holding E when the tank reaches 100% cannot reopen the pump and spam "Tank is already full".
- The custom HUD intentionally reports km/h (`m/s * 3.6`). Many GTA vehicle dashboard textures are mph: 141 km/h is approximately 88 mph, which explains the apparent gauge discrepancy.
- Live-log verification found and fixed a faction friendly-fire state crash (`OnDuty` was an undefined global), a missing shared profile dependency in `sunset_fire`, and a defensive character-id fallback in inventory loading.
- Fixed the Lua reserved-word key for the `/goto` help description, which prevented the shared help registry from loading on FXServer.
- Fixed `sunset_help` loading without the core shared data it consumes. LSFD can now use `/firecalls` to synchronize and route to existing incidents, or `/firestart` to request a rate-limited incident when none is active.
- Civilian employment and faction membership are independent: `/quitjob` now resigns only the civilian job at the Job Center; `/leavefaction` and `/quitgroup` remove only faction membership. Command-name collisions across dispatch, emotes, garages and medical actions were removed.
- Payday now adds the civilian-job salary and eligible on-duty faction salary instead of allowing faction membership to mask the civilian salary; the notification shows both components.
- Civilian job changes and faction changes now use separate runtime events. Taking or quitting a civilian job no longer forces faction duty off, and joining/leaving a faction no longer impersonates a civilian job change.
- Core callback throttling always sends an explicit error response, preventing an awaiting client/NUI action from hanging when the limit is reached.
- Dispatch persistence uses an explicit SQL `NULL` branch for unassigned calls, avoiding sparse Lua parameter arrays and oxmysql null-argument runtime errors.
- Fire incident vehicles are protected from the traffic cleanup system and keep their local entity/fire handles across server updates; cleanup now removes both vehicle and script fire correctly.
- TAB and the mouse wheel are restored for weapon selection. The player list is now held with F10 under a fresh key mapping, avoiding persisted TAB bindings from the old command.
- World cleanup now deletes only GTA ambient population entities, never script/network/mission vehicles or peds. All civilian work vehicles and trailers are also explicitly protected.
- Trucker work now shows a persistent mission objective with pickup, delivery and depot-return stages; objective subtitles are rendered correctly by NUI.
- Trucker milestones require the assigned truck and its assigned attached trailer; truck/trailer registration is verified and detachment/vehicle abandonment has a 60-second recovery window. `/recovertrailer` safely rights and reattaches a nearby overturned assigned trailer while the truck is stopped (three uses per shift, three-minute cooldown).
- The inaccessible Tataviam truck checkpoint was replaced with a wide freight destination and truck checkpoints now use an articulated-vehicle-friendly radius.
- Fisherman now uses `/fish` or E to cast with a visible rod and a server-timed reaction challenge; catches require reeling during the short BITE window.
- A successful catch routes the player to the Fish Buyer at Del Perro Pier and shows the exact E interaction; the sale UI now reports the authoritative paid amount.
- Server notifications have one canonical client listener (duplicate toasts removed), and generic/nil errors are converted into user-facing explanations. Inventory use now explains the failed requirement and never consumes an item whose action is not implemented.
- Fisherman catches are persistent `Fresh Fish` inventory items. Carry capacity starts at two and increases by one per Fisherman level (configured cap: 12); `/sellfish` routes to or sells at the Del Perro Pier buyer.
- P is reserved for the phone while ESC opens pause. HUD overlays fade out during pause and return smoothly on exit; character entry uses a loading-to-game blur/fade transition.
- Owned vehicle fuel and damage are checkpointed to persistence every 30 seconds while driving, in addition to garage storage/refuelling saves.

Status key: **COMPLETE** | **PARTIAL** | **NOT IMPLEMENTED** | **BLOCKED**

---

## Core Gameplay Loops

| Loop | Status | Notes |
|------|--------|-------|
| Auth → character → spawn | COMPLETE | `sunset_auth`, `sunset_characters`, `sunset_spawn` |
| Faction join / duty / salary | COMPLETE | HQ markers, `/duty`, payday via `sunset_economy` |
| Civilian jobs (trucker/garbage/courier/fisherman) | COMPLETE | Depot/location-bound loops with server vehicle/coordinate/cooldown validation |
| Civilian mechanic dispatch | COMPLETE | Active job provider → accepted assigned call → nearby customer vehicle → payout/XP/completion |
| Faction mechanic repair | PARTIAL | `/repairveh` with distance check; no dispatch accept flow |
| LSPD wanted / arrest / jail | COMPLETE (static verification) | Accumulating charges, DB persistence, visible booking points/GPS, explicit validation, server-validated release |
| LSPD detention (cuff/escort/frisk) | COMPLETE (static verification) | State machine, proximity validation, cuff state hydration and animation enforcement |
| LSPD citations / MDC | COMPLETE (static verification) | Real violation selector, server-only pricing, single-use atomic pay/refuse; live two-player QA still required |
| LSPD backup | COMPLETE | `/backup` + `/cbackup` via `sunset_dispatch` police_backup |
| EMS downed / stabilize / revive | COMPLETE | Distance + downed checks; medic dispatch auto-complete |
| Fire rescue | PARTIAL | Randomized vehicle-fire incidents, manual incident request, dispatch/GPS and rescue permissions work; no hose/building fire system |
| Taxi phone rides | COMPLETE | DB persistence, meter, idle timeout enforced |
| Taxi manual `/fare` | COMPLETE | Proximity-validated server charge |
| Unified service dispatch | COMPLETE | taxi/medic/fire/mechanic/police_backup |
| Economy (shops/ATM/payday) | COMPLETE | |
| Vehicle dealership | COMPLETE (static verification) | Persistent stock, preview, test drive, purchase and admin catalog management; live gameplay QA required |
| Death / hospital respawn | COMPLETE | Bleedout, bill, EMS notify radius |
| Player stats / progression | PARTIAL | Persistent level/XP, total playtime and per-job progress; advanced histories/achievements are not implemented |
| M menu / NUI | PARTIAL | Player, vehicles, career, property, settings and persistent statistics views; property/settings remain lightweight |
| Inventory / properties / vehicles | PARTIAL | Core exists; RPG hooks vary by feature |
| Crafting / phone / documents | PARTIAL | Present; not full RPG depth |

---

## Security Fixes (2869659c audit)

| Issue | Severity | Status |
|-------|----------|--------|
| Jail escape via `sunset:server:jailComplete` | CRITICAL | FIXED — server validates `releaseAt` |
| Ticket amount from client NUI | HIGH | FIXED — server resolves from `Sunset.Police.violations` |
| `mechanicRepair` no distance check | HIGH | FIXED — 6 m max |
| `factionRevive` no distance/downed check | HIGH | FIXED — 4 m + `IsPlayerDowned` |
| `taxiFare` no proximity | MEDIUM | FIXED — 8 m max |
| Backup spam / duplicate | MEDIUM | FIXED — dispatch rate limit + one active call |
| Client-forged authentication (`accountId`) | CRITICAL | FIXED — successful password callback now establishes the server session directly |
| Client-forged complete character state | CRITICAL | FIXED — spawn only acknowledges the already server-selected character ID |
| Vehicle storage repair/state forgery | HIGH | FIXED — ownership, driver, nearby entity, bounds and rate validation |
| Immediate bleedout bypass via `/respawn` event | HIGH | FIXED — server enforces the authoritative bleedout deadline |
| Needs event replay/spam | MEDIUM | FIXED — server-side tick interval enforced |
| Core callback event flood | MEDIUM | FIXED — input validation and per-second rate cap |
| NUI vehicle/job HTML injection | MEDIUM | FIXED — dynamic values escaped before HTML rendering |

---

## Manifest Audit

| Resource | Issue | Status |
|----------|-------|--------|
| `sunset_jobs` | Duplicate `job_session.lua` in shared_scripts | FIXED |
| all `sunset_*` resources | Missing manifest references / unloaded Lua files | VERIFIED — zero findings in static manifest inventory |

---

## Remaining PARTIAL Items

- Faction LSFD: randomized vehicle-fire incidents are playable; no fire hose or building-fire simulation
- Faction mechanic: no dispatch accept for faction mechanics (civilian path complete)
- Offline faction roster / MDC offline lookup by name
- `sunset_ui` summon panel styling (event wired)
- Gang territory / turf systems

---

## NOT IMPLEMENTED

- Stretcher / hospital intake workflow
- Fire hose physics / fire spread simulation
- Mechanic parts inventory / LS Customs upgrade shop
- Advanced gang missions beyond HQ sell/fence
- CAD map UI for dispatch (text commands + `/calls` panel only)

---

## BLOCKED

- None at integration QA sign-off
