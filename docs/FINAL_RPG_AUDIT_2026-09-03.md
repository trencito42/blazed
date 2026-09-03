# SunsetMP final RPG code audit

**Audit date:** 2026-09-03
**Inspected baseline:** `614c4f9` on `main`
**Scope:** runtime loading, core/auth, factions, Police/EMS/Fire/Taxi, dispatch, civilian jobs, persistence, progression, M menu/NUI, and exposed client-to-server boundaries.

## Executive result

The prior completion reports were not fully reliable. The configured deployment template does start every current `sunset_*` resource and every Lua file under those resources is referenced by its manifest, but the framework still contained two critical trust-boundary flaws and several high/medium runtime abuse paths. These were repaired in this audit.

The RPG is a playable MVP, not a feature-complete SA:MP-style RPG. Police, dispatch, Taxi and the five civilian work paths have substantial implementations. EMS and Fire are functional but remain shallow. Advanced character history, achievements, offline faction/MDT history, stretcher/intake, fire hose/spread, mechanic parts/upgrades and a full CAD map remain backlog.

## Verified runtime wiring

- `config/server.cfg.template` starts core, UI, world, factions, dispatch, jobs, Police dependencies, EMS/Fire/Taxi and supporting gameplay resources in a viable dependency order.
- Static manifest inventory found no missing referenced files and no unreferenced Lua implementation files under `resources/[sunset]`.
- `sunset_jobs/fxmanifest.lua` loads trucker, garbage, courier, fisherman, mechanic and command clients plus every matching server module.
- `sunset_ui` declares its HTML, CSS, JavaScript, vendor and asset trees.
- Dependency installation and live container/database startup could not be executed on this Windows audit host because Docker and a local MariaDB service are unavailable.

## Security and runtime defects fixed

1. **Critical — forged login:** the client could emit `sunset:server:authSuccess` with an arbitrary account ID. Authentication now completes inside the successful server password callback, account identity is reloaded from the database, repeat completion is rejected, and the client no longer submits account identity.
2. **Critical — forged character:** the spawn client returned the full character object (including money, job, metadata and XP) to the server. The server now accepts only a spawn acknowledgement for the character ID it already selected and retains its authoritative object.
3. **High — vehicle state/repair forgery:** storage accepted client health/state for any owned plate. It now requires the player to be the driver of the matching nearby network entity, verifies ownership, clamps state, reads engine/body health from the server entity, limits payload size and rate-limits writes.
4. **High — bleedout bypass:** a client could request hospital respawn immediately. The server now owns and enforces `releaseAt`, including the stabilized deadline.
5. **Medium — needs replay:** the hunger/thirst event could be spammed. A server interval gate now rejects early repeats.
6. **Medium — callback flood:** the generic callback event now validates callback name/request ID and caps calls per player per second.
7. **Medium — NUI injection:** database-derived vehicle/job strings inserted with `innerHTML` are escaped; IDs are converted to numbers.

## Persistence and progression

- Character money, job, faction metadata, needs, level/XP, death state, property and last-played data are persisted by the core.
- Account-wide playtime is flushed every five minutes and on disconnect. This is total connected playtime, not yet a robust AFK-aware active-time metric.
- Per-job XP, level, completed tasks and earnings use `job_progress` and are server awarded by validated job state machines.
- Wanted and jail use dedicated persistence migrations; Taxi rides and Police tickets/history have database records.
- The M menu now exposes an actual persistent statistics view: level/XP, total playtime, current session, character creation/last login, job tasks, job earnings, combined skill levels and asset counts.

## Remaining limitations (not represented as complete)

- No monthly activity ledger, AFK/active split, achievements, faction history or complete wealth/property history.
- EMS lacks stretcher and hospital intake workflow.
- Fire has vehicle-fire incidents but no hose physics, fire propagation or building incident set.
- Offline faction roster and full offline MDT/warrant history are incomplete.
- Property and settings tabs in M are functional entry points, not deep management screens.
- Runtime gameplay still needs a two-client staging pass against MariaDB/OneSync for concurrency, disconnect/reconnect and entity ownership behavior.

## Validation performed

- JavaScript syntax check for every `sunset_ui/web/js/*.js`: passed.
- Lua syntax parse for every changed Lua/manifest file: passed. (The general parser does not understand FiveM backtick hash literals, so unchanged files using that extension require the FXServer runtime for authoritative parsing.)
- Manifest referenced-file and unreferenced-Lua inventory: passed with zero findings.
- `git diff --check`: passed.

## Required staging smoke test

1. Register and login; confirm another account ID cannot be selected through a custom event.
2. Enter game, reconnect, and verify the same authoritative cash/job/XP state.
3. Run `/setjob [id] courier`, `/work`, `/jobs`, `/skills`, then repeat for all five civilian jobs.
4. Test Police backup, dispatch accept/complete, wanted/arrest/jail reconnect and early respawn rejection.
5. Store a personally owned driven vehicle; reject a remote plate and confirm engine/body damage persists.
6. Open M, inspect every tab and the Statistics action at 16:9 and a narrower resolution.
