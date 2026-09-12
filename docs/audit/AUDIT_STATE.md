# AUDIT_STATE — Authoritative Checkpoint

**Last updated:** 2026-09-12 (ALL PHASES COMPLETE + BACKLOG BURN-DOWN 9b)
**Current phase:** COMPLETE incl. Phase 9b backlog burn-down (payday batching, minute batching, dice escrow persistence, trade metadata, factions rehydration, webhook throttle, font/icon vendoring, 13MB asset diet, XODO branding purge). Verdict: **CONDITIONAL GO** — only ops actions + runtime tests remain (cannot be done statically).
**Next phase to resume from:** none — audit complete. Remaining work = VPS ops (secret rotation, sql/42 via scripts/apply-migrations.sh, pma-voice) + 15 runtime tests (list below).

Resume procedure for a new session: read this file, then `docs/audit/MASTER_AUDIT.md` (full architecture map §1, findings register §2, phase reports §3). Do not re-scan the repo.

---

## Phase status

| Phase | Description | Status |
|---|---|---|
| 1 | Discovery & architecture mapping | COMPLETE |
| 2 | Security, trust boundaries, net events, server authority | COMPLETE (+13 fixes) |
| 3 | FiveM networking, OneSync, entities, sync | COMPLETE (+6 fixes, OneSync enabled) |
| 4 | Vehicles & GTA/FiveM compatibility | COMPLETE (+9 fixes) |
| 5 | DB, persistence, concurrency, economy, duplication | COMPLETE (+8 fixes, sql/42 migration) |
| 6 | Gameplay systems & cross-system state | COMPLETE (+10 fixes) |
| 7 | Performance & resource lifecycle | COMPLETE (+5 fixes, backlog documented) |
| 8 | NUI/UI consistency & integration | COMPLETE (+12 fixes incl. 3 XSS) |
| 9 | Regression scan & production-readiness | COMPLETE (verdict: CONDITIONAL GO) |

## Resources inspected

All 42 `sunset_*` resources + oxmysql, server.cfg + template + docker configs, all 41+1 SQL migrations, deploy scripts, prior audit docs (cross-checked). Line-level deep review: core, vehicles, inventory (trade/containers/quickslots), economy (payday/dice/lottery/atm), auth, admin, death, factions (police/detention/main), taxi, carjack, fishingshop, crafting, jobs (fisherman), tuning, turfs, clans, properties, licenses, dispatch, ui (bridge/app/chat/mdc/panels/trade-forza), hud, world, fire, menu, dealership, robbery, loadscreen.

## Confirmed findings & fixes

~60 findings across phases (6 CRIT, ~20 HIGH). **44 fixed in code**, all tagged `[AUDIT Px-xx]` in source. Full register: MASTER_AUDIT.md §2 + per-phase tables §3.

CRIT fixes: carjack free-money mint (P2-01), container remote-looting (P2-05), crafting/fisherman broken transactions (P5-01/02), container deposit dupe (P5-03), taxi double-charge (P5-04), jailed-payday casing bug (P6-01), MDC/calls/chat stored XSS (P8-01/02/03), OneSync absent (P3-01), turf-war query storm (P7-01), adminRepairDatabase (P1-01).

## Unresolved findings (backlog, non-blocking, designs documented in MASTER_AUDIT.md)

RESOLVED in Phase 9b (see MASTER_AUDIT.md §Phase 9b): P5-06 trade metadata, P5-07 dice escrow, P7-02 payday batching, P7-05 font/icon vendoring + asset diet + branding purge, P7-07 minute batching, P7-12 factions rehydration, P7-10 webhook throttle.
Still deferred (low risk, designs documented): P3-07 sunsetWanted statebag privacy; P3-08 propertiesChanged debounce; P8-15 SetFocus owner adoption (~80 sites, needs visual testing); z-index/CSS consolidation; battlepass dormant-modal removal; legacy SHA-256 forced rotation (ops decision); quick-token lifetime shortening (ops decision).

## Files modified by this audit (53 + 2 new)

Config: `server.cfg` (OneSync), `config/server.cfg.template` (OneSync).
New: `sql/42-audit-integrity.sql`, `docs/audit/MASTER_AUDIT.md`, `docs/audit/AUDIT_STATE.md`.
Resources (all changes tagged `[AUDIT ...]`): sunset_admin (commands), sunset_auth (main), sunset_carjack (client+server), sunset_clans (main), sunset_core (fxmanifest, client/main, server/main, server/player, server/security, shared/factions), sunset_crafting (main), sunset_dealership (main), sunset_death (client+server), sunset_dispatch (main, service_core), sunset_economy (main, dice), sunset_factions (client/main, client/police, server/main, server/police, server/detention), sunset_fire (server), sunset_fishingshop (server), sunset_hud (fxmanifest, client/main), sunset_interactions (server), sunset_inventory (containers, quickslots, trade), sunset_jobs (fisherman), sunset_licenses (server), sunset_menu (client), sunset_properties (fxmanifest, client, server), sunset_taxi (server), sunset_tuning (server), sunset_turfs (server), sunset_ui (index.html, nui_bridge, app.js, chat.js, mdc_tablet.js, panels.js, trade-forza.js), sunset_vehicles (client+server), sunset_world (world_tooltips).
Pre-existing uncommitted change NOT by this audit: `sunset_turfs/client/main.lua` (modified before audit started; left as-is).

## Runtime tests still required (none executed — static-only environment)

1. Carjack sell: at chop shop (pays, deletes) vs anywhere else (refuses); owned plate refused; spamming cooldown.
2. Container access remotely by plate iteration → must fail; trunk access within 6m → works.
3. Jailed player across hourly payday → $0, no RP/rob points.
4. Taxi complete spam (2 fast callbacks) → single charge.
5. Trade/give-cash/shop/dice while downed or jailed → refused.
6. Ticket-receive: ESC closes; failed PAY closes; 120s auto-expire.
7. Login: 5 wrong passwords → lockout with countdown.
8. Vehicle store with injected props.ecu → ecu not persisted; fuel never increases; damaged car spawns damaged (no free heal).
9. Disconnect with owned car out → car deleted, stored=1, parked coords saved.
10. Death inside house → hospital respawn visible (bucket reset).
11. Chop NPC peds after `restart sunset_carjack` → no duplicates.
12. Courier HUD now renders (courier.js linked).
13. XSS regression: `/112` with `<img src=x onerror=alert(1)>` description → renders as text in MDC.
14. sql/42 migration applies on a copy of the live DB (FK creation may need dangling-row cleanup — statements included).
15. OneSync on: verify damage-event license gating actually cancels (was no-op before).

## Ops actions required before public launch

- Rotate `sv_licenseKey` (was plaintext in local server.cfg), MySQL root password, server-tls.key/server-monitor-token.key if box was shared.
- Run `sql/42-audit-integrity.sql`.
- Install pma-voice locally (scripts/install-deps.sh) or keep Docker deploy path.
- Align gamebuild: live server.cfg=3258 vs template=3751 — pick one deliberately.
- Decide on legacy SHA-256 password forced rotation + quick-token lifetime.

## Capacity notes

Static checks available in this environment: luaparse (npm, temp dir), node `new Function()` for JS, repo's `scripts/audit-static.ps1`. No FiveM runtime/DB available — all runtime tests above are deferred to the user.
