# PERFORMANCE_BASELINE — Budgets & Measurements

**Honesty note:** this environment is static-only. Numbers below marked *MEASURED* come from code analysis (loop frequencies, query counts) or the live VPS startup logs. Numbers marked *TARGET* are budgets to validate in-game with `resmon` / txAdmin / FiveM profiler. We do not claim measured frame costs we have not profiled.

## 1. Budgets (TARGET — must be validated on a populated server)

| Metric | Budget | How to measure |
|---|---|---|
| Client idle resmon (sunset_* total) | < 0.20 ms/frame | in-game `resmon`, standing still, no UI open |
| Client active job resmon | < 0.40 ms/frame | during trucker/fishing loop |
| Server tick (sv_maxclients 48) | < 8 ms sustained | txAdmin / `server_tic` |
| DB queries / player / minute (idle) | < 5 | oxmysql slow log / query counter |
| DB queries / player / minute (active job) | < 30 | same |
| NUI messages / second / client (idle) | < 15 | count SendNUIMessage in hud/world |
| NUI messages / second (UI open) | < 40 | same |
| Network events / second / client | < 20 | netgraph / callback rate |
| Server Lua memory growth / hour | < 5 MB (bounded) | `collectgarbage('count')` periodic |
| Entity count (server-visible) | < 400 | OneSync entity dump |

## 2. Fixed hot paths (MEASURED from code, before → after)

| Path | Before | After | Evidence |
|---|---|---|---|
| Turf war clan lookup | ~20-40 blocking MySQL queries/sec during a war (per-player-per-tick) | ~0 steady (30s cache) | P7-01, turfs/server/main.lua getPlayerClan cache |
| Payday burst | ~400-500 sequential queries in ONE tick at 48 slots | spread: 2 players / 500ms queue (~30s) | P7-02, economy PaydayQueue |
| Active-minutes writes | 48 UPDATEs/min (1 per player per minute) | 1 batched CASE-WHEN UPDATE / 5 min + on drop | P7-07 |
| HUD NUI payload | 20 Hz full ~25-field JSON | 10 Hz | P7-03 |
| World tooltip NUI sync | 60 Hz while near any NPC | 10 Hz | P7-04 |
| NUI external font/icon fetch | 2 blocking remote requests (Google Fonts + unpkg) on first paint | 0 (local assets) | P7-05 |
| Memory leaks | taxi Rides, fire Incidents, FlowTraceRate, LastAlertAt never freed | swept on terminal state / drop | P7-06, P7-10 |
| Security Discord webhooks | unbounded (every 5s scan per offender → 429s) | 1 per 5 min per source per kind | P7-10 |

## 3. Remaining known costs (documented, not yet fixed — backlog)

| Item | Cost | Why deferred |
|---|---|---|
| `propertiesChanged` broadcast to -1 on every mutation (23 sites) → each client re-pulls full property table | up to 48 heavy JOINs per admin edit | needs debounce + delta payload; medium refactor, no correctness risk |
| Phone re-fetches full payload (3 queries) after every SMS | chatter on SMS-heavy play | delta-push refactor |
| 4 always-on client key-poll Wait(0) threads (scoreboard Z, phone P, quickslots X, hotbar disables) | small per-frame scheduler overhead ×4 | merge into one input thread; behavior risk without runtime test |
| Turf per-second DB churn beyond clan (already cached) | low | acceptable at 16 turfs |
| ~1481 `!important` + 159 duplicate CSS selectors | paint/maintainability | cosmetic refactor |

## 4. Loop inventory (MEASURED)

- Server Wait(<100ms) loops: 0 (only admin deferral Wait(0), correct). Server minimum cadence = 1s (robbery tick, justified) / 2s (taxi meter).
- Client Wait(0) loops: 65 sites; ~50 are conditional (only active during a job/UI/state) or transient model-load waits. Always-on per-frame: hud world (density natives), hud main (HideHudComponent), scoreboard/phone/quickslots key polls. Full table: `docs/audit/MASTER_AUDIT.md` Phase 7.
- Background server threads: payday queue drain (2s idle), minute accumulator (60s), minute flush (5min), broadcastTime (10s), playtime flush (5min), security scan (5s), taxi/fire sweeps (5min/10min), dispatch/wanted ticks. All ≥1s cadence.

## 5. Profiling procedure (to fill TARGET numbers)

1. Populate server (or use test-driver bots — Phase 2 deliverable) to ~24 and ~48.
2. `resmon` snapshot per client state: idle / driving / job-active / UI-open / combat.
3. txAdmin server performance + `sv_profile`.
4. oxmysql: enable query logging for 10 min, aggregate per resource.
5. NUI: instrument `SendNUIMessage` counter in sunset_ui for 60s per state.
6. Record before/after each perf fix in §2. Re-run REGRESSION perf rows.
