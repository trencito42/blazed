# SunsetMP RPG Status (Canonical)

**Last updated:** 2026-09-03  
**Deploy baseline:** post-integration QA commit on `main`

Status key: **COMPLETE** | **PARTIAL** | **NOT IMPLEMENTED** | **BLOCKED**

---

## Core Gameplay Loops

| Loop | Status | Notes |
|------|--------|-------|
| Auth → character → spawn | COMPLETE | `sunset_auth`, `sunset_characters`, `sunset_spawn` |
| Faction join / duty / salary | COMPLETE | HQ markers, `/duty`, payday via `sunset_economy` |
| Civilian jobs (trucker/garbage/courier/fisherman) | COMPLETE | Full `/work` loops in `sunset_jobs` |
| Civilian mechanic dispatch | COMPLETE | `/work` shift + `sunset_dispatch` AcceptCall/CompleteCall wired |
| Faction mechanic repair | PARTIAL | `/repairveh` with distance check; no dispatch accept flow |
| LSPD wanted / arrest / jail | COMPLETE | DB persistence, server-validated release |
| LSPD detention (cuff/escort/frisk) | COMPLETE | State machine + proximity validation |
| LSPD citations / MDC | COMPLETE | Ticket amounts from server config only |
| LSPD backup | COMPLETE | `/backup` + `/cbackup` via `sunset_dispatch` police_backup |
| EMS downed / stabilize / revive | COMPLETE | Distance + downed checks; medic dispatch auto-complete |
| Fire rescue | PARTIAL | Heal/revive perms; `/service fire`; no hose/mission loop |
| Taxi phone rides | COMPLETE | DB persistence, meter, idle timeout enforced |
| Taxi manual `/fare` | COMPLETE | Proximity-validated server charge |
| Unified service dispatch | COMPLETE | taxi/medic/fire/mechanic/police_backup |
| Economy (shops/ATM/payday) | COMPLETE | |
| Death / hospital respawn | COMPLETE | Bleedout, bill, EMS notify radius |
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

---

## Manifest Audit

| Resource | Issue | Status |
|----------|-------|--------|
| `sunset_jobs` | Duplicate `job_session.lua` in shared_scripts | FIXED |

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
