# SunsetMP RPG Status (Canonical)

**Last updated:** 2026-09-03  
**Code baseline:** local audit after `614c4f9` (not yet deployed by this audit)

## Live vehicle/menu corrections (2026-09-04)

- Personal-vehicle storage is now server-authorized before the client deletes the entity; failed ownership/driver checks return an explicit error and no longer produce a false success.
- The M-menu vehicle card overlays fuel, engine and body health from the currently driven owned entity, instead of showing stale database values until storage.
- M-menu faction info closes the NUI before opening the chat panel, so the result is visible.
- Duty notifications always use a boolean state and a faction label; faction leave no longer adds a duplicate generic notification.
- Fuel-pump input is edge-triggered after each fill. Holding E when the tank reaches 100% cannot reopen the pump and spam "Tank is already full".
- The custom HUD intentionally reports km/h (`m/s * 3.6`). Many GTA vehicle dashboard textures are mph: 141 km/h is approximately 88 mph, which explains the apparent gauge discrepancy.
- Live-log verification found and fixed a faction friendly-fire state crash (`OnDuty` was an undefined global), a missing shared profile dependency in `sunset_fire`, and a defensive character-id fallback in inventory loading.

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
| LSPD wanted / arrest / jail | COMPLETE | DB persistence, server-validated release |
| LSPD detention (cuff/escort/frisk) | COMPLETE | State machine + proximity validation |
| LSPD citations / MDC | COMPLETE | Ticket amounts from server config only |
| LSPD backup | COMPLETE | `/backup` + `/cbackup` via `sunset_dispatch` police_backup |
| EMS downed / stabilize / revive | COMPLETE | Distance + downed checks; medic dispatch auto-complete |
| Fire rescue | PARTIAL | Vehicle-fire incident loop and rescue perms work; no hose/building fire system |
| Taxi phone rides | COMPLETE | DB persistence, meter, idle timeout enforced |
| Taxi manual `/fare` | COMPLETE | Proximity-validated server charge |
| Unified service dispatch | COMPLETE | taxi/medic/fire/mechanic/police_backup |
| Economy (shops/ATM/payday) | COMPLETE | |
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

- Faction LSFD: no fire hose / incident missions
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
