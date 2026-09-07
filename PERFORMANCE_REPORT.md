# SunsetMP — Performance Report

**Audit date:** 2026-09-07  
**Method:** Static code review only — **no runtime profiling** was performed on a live server in this pass.

---

## Measurements

| Metric | Result |
|--------|--------|
| Idle client resource time | **NOT MEASURED** |
| Active job resource time | **NOT MEASURED** |
| Server tick impact | **NOT MEASURED** |
| Query counts (common flows) | **NOT MEASURED** |
| NUI update frequency | **NOT MEASURED** |
| Entity counts before/after cleanup | **NOT MEASURED** |

Per release spec §20: improvements are **not claimed** without measurements.

---

## Static findings (code patterns)

### Potential hotspots (review recommended)

| Area | Pattern | File(s) | Risk |
|------|---------|---------|------|
| Chat overhead | `Wait(0)` loop when overhead text drawn | `sunset_chat/client/main.lua` | Low–medium; adaptive wait when not drawing |
| Faction roster | Full online scan for chat/dispatch | Various | Medium at high player count |
| Clan broadcast | Iterates all players per clan action | `sunset_clans/server/main.lua` | Medium |
| Property directory | Full `properties` query on open | `sunset_properties/server/main.lua` | Low |
| Scoreboard | Delay before callback register | `sunset_scoreboard` | Startup only |

### Positive patterns observed

- Clan/faction chat rate limits (1200ms clan, 350–400ms general chat after fix)
- Robbery sessions — server-owned state machine
- Character locks on pass claims (`withCharacterLock`)
- Adaptive `Wait(200)` in chat when no overhead text

### Cleanup (static verification)

| Event | Cleanup handlers present |
|-------|--------------------------|
| playerDropped | clans, chat rate limits, faction state (partial) |
| resourceStop | properties routing buckets |
| job cancel | Per-job modules (verify per job manually) |

---

## Recommended profiling plan (when server available)

1. `resmon` idle 5 min — note top 5 client resources.
2. Active trucker + fisherman sessions — compare `resmon` client/server.
3. Count `MySQL` queries during: login, spawn, `/buylevel`, property buy.
4. Entity count before/after fire mission + job cancel.
5. NUI message rate during M-menu open/close spam.

Record results in a follow-up `PERFORMANCE_REPORT.md` revision.
