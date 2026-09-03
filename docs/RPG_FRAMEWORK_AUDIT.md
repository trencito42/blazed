# SunsetMP RPG Framework Audit

**Date:** 2026-09-03  
**Scope:** Factions, jobs, police, economy, persistence, networking  
**Baseline commit:** `8b0fb04` (LSPD wanted system) through current working tree

---

## 1. Current Architecture

SunsetMP is a custom FiveM RPG framework built around modular `sunset_*` resources:

| Layer | Resources | Role |
|-------|-----------|------|
| Core | `sunset_core` | Player/session, characters, money, callbacks, shared config |
| Auth | `sunset_auth` | Username/password accounts |
| Characters | `sunset_characters`, `sunset_spawn`, `sunset_appearance` | Creation, spawn, visuals |
| Factions | `sunset_factions` | Duty, HQ, commands, police, detention |
| Jobs | `sunset_jobs` | Civilian job center + admin `/setjob` |
| Economy | `sunset_economy` | Hourly payday, shops, ATM |
| Taxi | `sunset_taxi` | Phone app rides, server-validated fares |
| World | `sunset_world` | HQ markers, depots, interaction zones |
| UI | `sunset_ui` | NUI panels, HUD, chat, phone |
| Admin | `sunset_admin` | Permission levels, moderation commands |

**Character model (SAMP-style):** `characters.job` = civilian job; faction membership lives in `characters.metadata.faction` + `metadata.faction_grade` (`sunset_core/shared/profile.lua`). Legacy rows with faction in `job` column are migrated on load.

**Faction config:** `sunset_core/shared/factions.lua` — static Lua table for 7 factions (police, medic, taxi, mechanic, lsfd, 2 gangs).

**Duty state:** In-memory `OnDuty[source]` in `sunset_factions` (not persisted; resets on disconnect).

---

## 2. Existing Systems

### Factions (working)
- Join at HQ (`[E]`), `/duty`, `/leavefaction`, `/faction` info panel
- Rank salaries via `sunset_economy` payday (must be on duty)
- Faction chat `/f`
- Invite/promote (`/finvite`, `/fpromote`)
- Illegal HQ sell (`/sellpouch`, `/fence`)
- Society accounts (`societies` table) for fines/taxi/mechanic cuts
- Loadout on duty (police uniforms/weapons in `client/loadout.lua`)
- Friendly-fire protection between same-faction on-duty members

### Police (partial — from `8b0fb04` + this session)
- `/su`, `/so`, `/wanted`, `/arrest`, `/cuff`, `/uncuff`, `/fine`
- Wanted levels 1–5 with decay, jail teleport, arrest bounty
- MDC UI, ticket UI, backup, megaphone, escort, frisk, hands up
- Server callbacks for all enforcement actions

### EMS / LSFD (minimal)
- Config in `factions.lua` with `heal`/`revive` perms by rank
- `/heal` and `/revive` routed through `sunset_admin` + `sunset_factions` callbacks
- HQ join, duty, fleet spawn — **no dispatch, no stretcher, no hospital intake**

### Taxi (substantial)
- Full phone app (`sunset_taxi`), ride lifecycle, DB persistence (`taxi_rides`)
- Manual `/fare` command
- Server-validated payments and vehicle checks

### Civilian jobs (stubs)
- `trucker`, `fisherman` in `jobs_civilian.lua` — hire only, no gameplay loops

### Other
- Inventory, properties, vehicles, crafting, death/revive, scoreboard, documents, phone

---

## 3. Incomplete Systems

| System | Status |
|--------|--------|
| Trucker / Garbage / Courier jobs | Config + hire only |
| Fisherman minigame | Not started |
| Fire hose / fire missions | Not started |
| EMS dispatch / hospital workflow | Not started |
| Wanted persistence (DB) | Memory-only, lost on restart |
| Jail persistence | Client timer only |
| Faction member offline roster | Online-only `/fmembers` |
| MDT records / warrants history | Not started |
| Dispatch CAD for EMS/Fire | Not started |
| State bags for detention sync | Partial (events only) |

---

## 4. Incorrectly Designed

1. **Faction id checks scattered** — `== 'police'` used in multiple places; addressed by `faction_core.lua` capability model.
2. **Cuff via open NetEvent** — `sunset:server:factionCmd` had no distance validation; **fixed** — moved to callbacks in `detention.lua`.
3. **Duty not persisted** — intentional for session play but confusing after reconnect.
4. **Jail is client-side timer** — player can potentially exploit by reconnecting (sentence not stored).
5. **Wanted in server memory** — no DB, no offline warrant service.
6. **Fleet vehicles client-spawned** — not owned/persisted; acceptable for patrol but not for evidence chain.
7. **Scoreboard exposes cash** — minor privacy concern for RP.
8. **Romanian strings in older SQL/comments** — player-facing text now English.

---

## 5. Security / Exploit Risks

| Risk | Severity | Status |
|------|----------|--------|
| Client-triggered cuff without proximity | High | **Fixed** — server callbacks + range checks |
| Fine/fare amount not capped | Medium | **Fixed** — caps on fine/fare amounts |
| Faction chat spam | Low | **Fixed** — rate limiting |
| `/f` without faction validation | Low | Was OK; channels now validated |
| Client-trusted taxi complete | Low | Already server-validated |
| Illegal sell without duty check | Low | Server checks duty |
| Admin `/setfaction` without audit | Medium | **Fixed** — `faction_audit_log` |
| Jail escape via disconnect | Medium | Open — needs DB sentence |
| Frisk returns full inventory server-side | Low | OK for RP; officer must have perm |

---

## 6. Persistence Problems

- Faction membership: `metadata` JSON on `characters` — works, no normalized `faction_members` table yet.
- Faction leaders: new `faction_leaders` table (`sql/08-faction-core.sql`).
- MOTD: `faction_motd` table.
- Warnings: `faction_warnings` table.
- Wanted/jail/cuff: **not persisted** — highest priority for next police sprint.
- Taxi rides: persisted on complete.
- Fines: `faction_fines` table.

---

## 7. Networking / Sync Problems

- Cuff state: server authority + client anim; escort uses attach (can desync on high latency).
- Wanted HUD: `sunset:client:wantedUpdate` to target only — other officers use `/wanted` or MDC.
- No Player state bags for `isCuffed` / `wantedLevel` — other resources cannot query easily.
- Backup blip: one-shot client blip, 60s TTL.

---

## 8. Database / Schema Problems

- `characters.metadata` unindexed — fine at current scale.
- No FK from `faction_fines` to `characters` (orphan rows possible).
- `taxi_rides` missing FK constraints.
- Migration order: `01` → `08` via `deploy.sh`.
- Legacy `job` column still used for civilians — dual model requires `profile.lua` migration helper.

---

## 9. Faction Problems

- No unified leader role before this session — added `/setleader`, `/removeleader`.
- Invite is instant (no accept/decline flow).
- Illegal factions share same grade structure as legal — OK for now.
- No faction bank withdrawal UI for leaders.
- EMS and LSFD share medic perms but no faction-specific commands beyond heal/revive.

---

## 10. Job Problems

- Only 2 civilian jobs with placeholder descriptions.
- No job progress, routes, or payouts beyond base salary.
- `/setjob` vs `/setfaction` split is correct but confusing for new admins — document in `COMMANDS.md`.
- Mechanic repair at HQ is a flat $250 with no target player economy.

---

## 11. Recommended Architecture

```
sunset_core/shared/
  faction_core.lua    ← types, capabilities, HasFactionCapability()
  factions.lua        ← faction definitions + grades/perms
  profile.lua         ← job vs faction resolution

sunset_factions/server/
  core.lua            ← duty, rate limits, audit
  detention.lua       ← cuff/escort/vehicle state machine
  chat.lua            ← /f /r /d /gov /m
  leaders.lua         ← leader commands + admin setleader
  police.lua          ← wanted/arrest/jail
  main.lua            ← shared faction callbacks

Per-faction extensions (future):
  sunset_factions/server/ems.lua
  sunset_factions/server/fire.lua
```

**Principles:** Server-authoritative money/ranks/wanted; capability checks not string compares; callbacks not open NetEvents for gameplay; audit log for leadership actions.

---

## 12. Migration Strategy

1. **Phase A (done this session):** `faction_core`, detention security, chat channels, leader tables, police extensions.
2. **Phase B:** Persist wanted + jail sentences to DB; state bags for detention.
3. **Phase C:** EMS dispatch + revive workflow; LSFD foundation (no hose yet).
4. **Phase D:** Civilian job loops (trucker first).
5. **Phase E:** MDT history, offline warrants, faction treasury UI.

Run `sql/08-faction-core.sql` on deploy. Existing characters unaffected.

---

## 13. Exact Files to Modify

### Modified this session
- `resources/[sunset]/sunset_core/shared/faction_core.lua` (new)
- `resources/[sunset]/sunset_core/shared/factions.lua`
- `resources/[sunset]/sunset_core/fxmanifest.lua`
- `resources/[sunset]/sunset_factions/server/core.lua` (new)
- `resources/[sunset]/sunset_factions/server/detention.lua` (new)
- `resources/[sunset]/sunset_factions/server/chat.lua` (new)
- `resources/[sunset]/sunset_factions/server/leaders.lua` (new)
- `resources/[sunset]/sunset_factions/server/main.lua`
- `resources/[sunset]/sunset_factions/server/police.lua`
- `resources/[sunset]/sunset_factions/client/detention.lua` (new)
- `resources/[sunset]/sunset_factions/client/main.lua`
- `resources/[sunset]/sunset_factions/client/police.lua`
- `resources/[sunset]/sunset_factions/fxmanifest.lua`
- `resources/[sunset]/sunset_ui/web/index.html`
- `resources/[sunset]/sunset_ui/web/js/panels.js`
- `resources/[sunset]/sunset_ui/web/js/app.js`
- `resources/[sunset]/sunset_ui/client/nui_bridge.lua`
- `sql/08-faction-core.sql` (new)
- `deploy.sh`

### Next sessions
- `sunset_factions/server/ems.lua`, `client/ems.lua`
- `sunset_factions/server/fire.lua`, `client/fire.lua`
- `sunset_jobs/server/trucker.lua` (new)
- `sunset_core/server/player.lua` — optional `faction_members` normalization
- `sunset_hud` — wanted stars from state bag
- `sql/09-wanted-persistence.sql` (planned)
