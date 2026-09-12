# SunsetMP / BlazeMP — Full Gamemode Audit

**Audit date:** 2026-09-11  
**Scope:** complete local repository at `C:\Users\stefan\Documents\sunsetmp`  
**Method:** source-first static audit; existing reports were treated as untrusted historical context  
**Change policy:** analysis only. No runtime source, configuration, database, deployment, or gameplay code was changed during this pass.

## Executive verdict

The framework is broad and contains substantial original work, but it is **not release-ready**. The principal problem is not a lack of features; it is that several core economic and gameplay operations are split across independent database writes, while multiple client events still supply authoritative outcomes. That creates exploitable duplication paths, partial transactions, stale caches, and player-facing states that can diverge from the database.

The UI symptoms visible in the latest screenshots are deterministic code defects, not random FiveM rendering. Inventory and trade are allowed to be visible simultaneously, and inventory has the higher z-index. The inventory layout also stacks a fixed-height panel, equipment, duty loadout, grid, and actions without a viewport height contract. `/v` can reuse stale `M` menu state because the already-open branch changes only the tab and skips solo-mode/data initialization.

### Release decision

**NO-GO.** Do not open the server to an uncontrolled public economy before the P0 items in [FIX_PLAN.md](FIX_PLAN.md) are complete and independently verified.

### Overall scores

| Area | Score / 10 | Summary |
|---|---:|---|
| Architecture | 4 | Useful domain separation, but parallel engines, a monolithic NUI, and a circular resource dependency undermine it. |
| Security | 3 | Many callbacks validate identity/proximity, but critical client-authority and credential/secret issues remain. |
| Server performance | 5 | Fine at low population; avoidable DB-per-event paths and O(players) scans will scale poorly. |
| Client performance | 5 | Several sensible timed loops coexist with per-frame work and an oversized shared NUI bundle. |
| Database integrity | 3 | Many multi-ledger operations lack transactions, uniqueness constraints, idempotency, or row locking. |
| Networking | 5 | Net IDs and proximity are validated in some newer systems, inconsistently elsewhere. |
| Runtime reliability | 3 | Partial commits, cache drift, resource-order risk, and UI state leakage make failures hard to recover from. |
| Gameplay completeness | 4 | Wide feature surface, but important flows remain fragile or unclear in actual play. |
| Maintainability | 4 | Resource boundaries help, but duplicated systems, runtime DDL, and CSS/JS layering increase regression risk. |
| Scalability | 3 | Current patterns are unsafe for 100–200 active players without redesign. |
| Production readiness | 2 | Critical security and economy blockers must be resolved before release. |

## Repository inventory and checks

- 43 custom `sunset_*` resources, plus external dependencies such as `oxmysql`.
- Approximately 670 custom files: 274 Lua files, 50 JavaScript files, and roughly 54,000 relevant source lines.
- 35 numbered SQL migrations.
- All literal manifest references checked by `scripts/audit-static.ps1` resolved; 43 resources were discovered.
- JavaScript syntax check passed for current `.js` files.
- The current fishing shop client parsed successfully with a Lua parser; the previously reported unmatched `)` is no longer present.
- No Lua runtime/compiler test, FXServer integration suite, database transaction test suite, or automated multiplayer gameplay suite exists in the repository.
- Static command scan found overlapping client/server registrations for `/r`, `/radar`, `/f`, `/setradar`, `/clans`, `/d`, `/clan`, `/stopradar`, and `/startradar`. Some may be intentional event bridges, but each must be verified for double execution and help ownership.

## Critical and high-severity findings

### F-001 — Infrastructure database credential is committed

- **Severity:** Critical
- **Confidence:** Confirmed
- **Evidence:** `scripts/vps-restart-all.sh:3-4`, consumed again around `:12` and `:20`; file is present in repository history (observed commit `cf332ef`).
- **Failure scenario:** anyone with repository/history access can obtain a live-looking database credential and connect directly if network policy permits. Removing only the current line does not remove it from Git history.
- **Required fix:** rotate the database credential immediately, update the deployment secret store, remove the value from all tracked files, purge it from Git history, invalidate old clones where possible, and add secret scanning for shell/config files. The secret is intentionally redacted from this report.

### F-002 — Job Creator progression and payout can be forged by the client

- **Severity:** Critical
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_jobcreator/server/engine.lua:14-63` accepts `data.success` and client-provided stage data for progress, skill, prop, and NPC actions; `resources/[sunset]/sunset_jobcreator/server/stages.lua:210-238` automatically grants the reward after advancement.
- **Failure scenario:** a modified client submits successful stage actions in sequence using known stage IDs and reaches `give_reward` without completing the world activity.
- **Required fix:** make the server own stage state, issued tokens, accepted entity models/net IDs, position windows, minimum timings, and completion predicates. Reward only from a single server transaction with replay protection.

### F-003 — Crafting admits concurrent duplication and partial consumption

- **Severity:** Critical
- **Confidence:** High
- **Evidence:** `resources/[sunset]/sunset_crafting/server/main.lua:90-140` counts ingredients, removes each independently, ignores individual removal results, then adds output/refunds. Inventory mutation itself is non-transactional (F-005).
- **Failure scenario:** two callbacks pass the same stale count check; inputs are consumed once or partially while both outputs can be granted.
- **Required fix:** per-character operation lock plus one SQL transaction using conditional decrements/locked rows, output capacity validation, and one idempotency key.

### F-004 — Trade commits items before money and assets

- **Severity:** Critical
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_inventory/server/trade.lua:419-438` commits item transfers; money moves afterward at `:441-465`; asset transfers occur later from `:468` onward.
- **Failure scenario:** item transaction succeeds, cash debit/credit or an asset transfer fails, and the callback returns an error while ownership has already changed.
- **Required fix:** move every offered asset and both money ledger entries into one database transaction, or implement a durable saga with compensating records and reconciliation. Lock both characters in a deterministic order.

### F-005 — Inventory mutation is race-prone and schema permits duplicate slots

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_inventory/server/main.lua:107-174` performs cache-based absolute count writes; `:487-531` performs multi-query slot swaps after memory mutation; inventory schema has no unique `(character_id, slot)` constraint.
- **Failure scenario:** concurrent reward/use/move/trade calls overwrite counts, duplicate a stack, lose an item, or create two rows in one slot.
- **Required fix:** unique slot constraint, transactional inventory service, row locks/conditional updates, deterministic versioning, and removal of direct domain-specific item writes.

### F-006 — Money, XP, and respect caches can lose concurrent updates

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_core/server/player.lua:185-248` updates cached money from a potentially stale cached value after awaited SQL; `:382-403` writes XP/respect as absolute values based on mutable cache.
- **Failure scenario:** two rewards complete out of order and the later cache/write overwrites one result; HUD and DB disagree until reload.
- **Required fix:** authoritative atomic SQL deltas with returned balances/version, serialized per-character ledger operations, and cache refresh from the committed row.

### F-007 — Buy-level can debit money without granting the level

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_core/server/player.lua:405-440` debits funds and updates level/RP in separate operations; an exception can also leave the per-source lock set.
- **Failure scenario:** DB failure after debit takes money but leaves the old level; subsequent attempts may remain locked.
- **Required fix:** one transaction, `xpcall`/finally-style lock release, idempotent request key, and authoritative response without closing the M menu.

### F-008 — Payday is non-idempotent, non-transactional, and loses activity on restart

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_economy/server/main.lua:28-45` keeps played minutes in memory; `:67-126` resets eligibility before independent reward/rent writes; `:176-207` polls wall-clock time without a durable payroll period.
- **Failure scenario:** restart loses qualifying minutes; crash mid-payday creates partial payment; restart near an hour can skip or duplicate a period.
- **Required fix:** durable activity counter, `payday_period` unique ledger, one transaction for all deltas/expiry/rent effects, and retry-safe execution.

### F-009 — ATM and bank transfers can destroy money

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_economy/server/main.lua:280-330` removes from one balance before separately adding to another; the second result is not safely rolled back.
- **Failure scenario:** destination update fails after source debit, permanently losing player funds.
- **Required fix:** transactional double-entry ledger with conditional source balance and one commit.

### F-010 — Vehicle fuel endpoints trust client-supplied economic facts

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_vehicles/server/main.lua:614-655` accepts plate/from/to fuel with only broad station proximity; `:697-753` accepts tank liters/class and lacks authoritative entity/proximity validation. Gas-can refund around `:686` always targets cash even when bank paid.
- **Failure scenario:** a modified client selects a favorable tank size/class/fuel delta, targets a plate without interacting with the actual entity, or receives a refund into the wrong wallet.
- **Required fix:** resolve vehicle/entity/model/class/tank/plate server-side, validate driver/pump distance and state, use one payment/fuel transaction, and return explicit localized errors.

### F-011 — Tuning reads a model field it never queries

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_tuning/server/main.lua:18-22` selects only `id, props`; callers use `row.model` around `:94` and `:132`.
- **Failure scenario:** capability resolution receives an empty model, so ECU/performance options are missing, wrong, or rejected.
- **Required fix:** include model and all authoritative vehicle fields in the query, validate JSON, and add capability tests for representative classes.

### F-012 — `sunset_tuning` and `sunset_vehicles` form a resource dependency cycle

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_tuning/fxmanifest.lua:45-51` depends on `sunset_vehicles`; `resources/[sunset]/sunset_vehicles/fxmanifest.lua:12,27` imports and depends on `sunset_tuning`.
- **Failure scenario:** resource start order is undefined/fails or exports/config are unavailable during startup/restart.
- **Required fix:** move shared vehicle capability configuration into a third dependency-free resource/module, then make both resources depend on it.

### F-013 — Password storage is too fast; quick login persists plaintext passwords

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_core/shared/password.lua:68-83` uses one salted SHA-256 and direct equality; `resources/[sunset]/sunset_auth/client/main.lua:52-62,195-205` and `client/accounts.lua:117-160` store the password in client KVP.
- **Failure scenario:** database leak permits inexpensive offline cracking; local compromise exposes reusable plaintext credentials.
- **Required fix:** server-side Argon2id/bcrypt/scrypt/PBKDF2 with migration-on-login. Quick login must store an opaque, revocable, device-bound token—not a password.

### F-014 — Duplicate logged-in account eviction may discard unsaved state

- **Severity:** High
- **Confidence:** High
- **Evidence:** `resources/[sunset]/sunset_core/server/main.lua` in `CompleteAuthentication` (around `:91+`) drops the old source and immediately clears player/session tables.
- **Failure scenario:** `playerDropped` runs after the authoritative in-memory object has been removed, so final persistence cannot access it.
- **Required fix:** save/close the old session before eviction, make disconnect cleanup idempotent, and test concurrent reconnects.

### F-015 — Property, rent, and dealership purchases have compensation gaps

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_properties/server/main.lua:204-277`; `resources/[sunset]/sunset_dealership/server/main.lua:150-196`.
- **Failure scenario:** ownership/stock changes commit before payment or renter/owner credits; compensation can itself fail, leaving free assets, lost rent, lost prior rental, or incorrect stock.
- **Required fix:** transactionally update ownership, balances, stock, and audit ledger; add unique idempotency keys and reconciliation.

### F-016 — Lottery purchase/draw is not atomic or replay-safe

- **Severity:** High
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_economy/server/lottery.lua:67-99` separates count, debit, jackpot, insert; `:108-176` separates payouts, ticket deletion, and state save; `/lottery` alias at `:217-219` dispatches through `ExecuteCommand`.
- **Failure scenario:** concurrent limit bypass, paid ticket missing, jackpot mismatch, or duplicate/lost winner payout after crash.
- **Required fix:** transactional round/ticket ledger with state machine and unique payout records; call the handler directly with source context.

### F-017 — License enforcement queries the database on every firearm damage event

- **Severity:** High (performance/availability)
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_licenses/server/main.lua` weapon-damage handler around `:177` calls uncached `HasLicense` for firearm events.
- **Failure scenario:** automatic fire creates many DB queries per second per combatant, saturating the database and delaying unrelated gameplay.
- **Required fix:** authoritative in-memory license cache loaded at character activation and invalidated on grant/expiry; no synchronous DB query in the damage hot path.

### F-018 — UI allows inventory and trade modal to coexist, with inventory above trade

- **Severity:** High (player-blocking UI)
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_inventory/client/main.lua:156-166` opens inventory before sending trade state; `resources/[sunset]/sunset_ui/web/js/panels.js:831-847` activates TradeForza without closing inventory; `trade-forza.js:48-56` opens `#trade-window`; `inventory-forza.css:1-15` uses z-index 11500 while `trade-forza.css:132-155` uses 9500. `trade-forza.css:883-886` hides only the legacy trade panel.
- **Failure scenario:** exactly as in the supplied screenshot: two trade surfaces and an inventory panel overlap, inputs/focus go to the wrong layer, and the page becomes unusable.
- **Required fix:** one central NUI modal state machine (`none|inventory|trade|vehicle|menu|...`), mutually exclusive roots, focus ownership, and invariant tests. Trade must reuse one inventory component, not open the standalone inventory modal.

### F-019 — Inventory layout has no viewport contract and duty items are unbounded

- **Severity:** High (player-blocking UI)
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_ui/web/css/inventory-forza.css:27-47,126-218,463-485`; fixed panel dimensions plus stacked equipment, quick access, grid, duty section, and controls; no reliable `max-height`/internal overflow contract for the complete composition.
- **Failure scenario:** duty weapons expand the panel beyond the screen; item cells become visually nonuniform and controls are clipped, matching the supplied screenshot.
- **Required fix:** viewport-relative shell, bounded sections, one grid token, `aspect-ratio:1`, contained item images, internal scrolling, and visual tests at 1280×720, 1920×1080, ultrawide, and UI scaling variants.

### F-020 — `/v` can reuse stale `M` state instead of initializing vehicle mode

- **Severity:** High (player-blocking UI)
- **Confidence:** High
- **Evidence:** `resources/[sunset]/sunset_vehicles/client/main.lua:866-872` emits `sunset:menu:openVehicle`; `resources/[sunset]/sunset_menu/client/main.lua:200-225` returns early when `menuOpen`, sending only `menuSetTab`; `resources/[sunset]/sunset_ui/web/js/menu.js:706-738` applies solo mode on a full show.
- **Failure scenario:** opening `/v` after another menu retains the wrong container, stale payload, close placement, or shell, producing the reported broken vehicle UI.
- **Required fix:** route every open through the same state transition that sets mode, payload, focus, and visibility; never use tab-only mutation to change root mode.

## Additional medium findings

### F-021 — Fixed police radar trusts the officer client's measured speed

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_factions/server/police.lua:987-1027` accepts client `speedKmh`, plate, and model.
- **Impact:** a modified officer client can fabricate evidence/fines; a target client can evade detection depending on measurement ownership.
- **Fix:** server-observed entities/state, signed observation snapshots, strict patrol-vehicle/seat/radar-state validation, and an audit record.

### F-022 — Generic callback gateway has only a coarse global rate limit

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_core/server/main.lua:25-70` invokes registered callbacks through one event and permits approximately 30 callbacks/sec/source.
- **Impact:** expensive callbacks can still be spammed within the global allowance; callback safety depends completely on every handler.
- **Fix:** per-callback budgets/cooldowns, payload size/type schemas, metrics, timeouts, and denial logging.

### F-023 — Fishing sale removes inventory before confirming payment

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_jobs/server/fisherman.lua:335-379` removes the complete fish quantity before the money operation.
- **Impact:** payment failure destroys a player's catch.
- **Fix:** one inventory/economy transaction or durable sale ledger with rollback.

### F-024 — Starter inventory and character creation are partial-write workflows

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** starter grant `resources/[sunset]/sunset_inventory/server/main.lua:59-80`; character creation flow in `sunset_core/server/main.lua` performs slot/create/items/flags separately.
- **Impact:** reconnect or crash can create incomplete characters or duplicate starter grants.
- **Fix:** character bootstrap transaction and unique one-time grant record.

### F-025 — Nearby inventory discovery is O(players) per open

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_inventory/server/main.lua:435-470` scans online players and coordinates for each request.
- **Impact:** repeated inventory opens scale quadratically under load.
- **Fix:** client/server spatial buckets or scoped player lists, cached briefly, with a final server distance check on action.

### F-026 — Migrations are replayed without a migration registry

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** `deploy.sh:159-176` replays numbered SQL; `scripts/vps-restart-all.sh:6-17` has different error policy; 35 migrations include duplicate numeric prefixes and multiple resources also create/alter tables at runtime.
- **Impact:** schema drift, silent partial deploys, slow startup, and non-repeatable environments.
- **Fix:** `schema_migrations` table, checksum/version enforcement, one migration runner, fail-fast deploy, and removal of runtime DDL after backfill.

### F-027 — Database constraints and indexes do not match hot invariants

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** no unique inventory `(character_id,slot)`; account email is not unique; phone message query filters sender-or-receiver while schema indexes only receiver.
- **Impact:** duplicate logical records and increasingly slow inbox queries.
- **Fix:** cleanup migration followed by unique/index constraints and query plan verification.

### F-028 — Local and template startup configuration drift

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** local `server.cfg` and template/deploy configuration do not ensure the same base resources/dependencies (`ox_lib`, voice/maps/interiors and related resources differ).
- **Impact:** behavior that works on one environment disappears after a clean deploy/restart.
- **Fix:** one generated canonical startup manifest, dependency preflight, and CI comparison.

### F-029 — Shared NUI is a monolith with layered old/new style systems

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_ui/web/index.html` loads a large set of panel-specific styles/scripts; repository contains roughly 45 NUI JS files plus old and Forza/redesign layers.
- **Impact:** global selectors, competing z-index values, stale visible roots, focus loss, black overlays, and inconsistent visual language recur across M/I/trade/factions/vehicles.
- **Fix:** shared design tokens and primitives, isolated panel roots, central modal/focus store, remove legacy layers after migration, visual regression screenshots.

### F-030 — HUD and world loops contain avoidable per-frame work

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_hud/client/main.lua:225-287` combines 50ms/500ms HUD updates with a per-frame scaleform/component loop and periodic gamer-tag sweep; `sunset_world` also performs continuous suppression loops.
- **Impact:** cumulative client frame cost rises with other scripts and player count.
- **Fix:** profile with resmon, cache unchanged state, event-drive HUD payloads, reduce tag sweeps, and keep `Wait(0)` only where a native requires per-frame enforcement.

### F-031 — Phone schema management and message query will degrade

- **Severity:** Medium
- **Confidence:** Confirmed
- **Evidence:** `resources/[sunset]/sunset_phone/server/main.lua:1-33` performs DDL at runtime; phone data query uses `(sender=? OR receiver=?) ORDER BY id DESC LIMIT 60` without matching composite indexes.
- **Impact:** startup locks/schema drift and slower phone load as messages grow.
- **Fix:** migration-only DDL and sender/id plus receiver/id indexes (or normalized conversation membership).

### F-032 — Scoreboard registration has an avoidable startup race

- **Severity:** Low/Medium
- **Confidence:** Confirmed
- **Evidence:** scoreboard callback registration occurs after a fixed `Wait(2000)`.
- **Impact:** F10/player-list requests during startup can fail depending on timing; player enrichment can become N+1.
- **Fix:** explicit dependency/readiness event and batched player data.

### F-033 — Logs and audit data have no visible retention policy

- **Severity:** Medium
- **Confidence:** High
- **Evidence:** multiple gameplay/admin/audit tables are append-oriented; no scheduled retention/partition/archive process was found.
- **Impact:** storage growth and slower admin/history queries over a long-running season.
- **Fix:** documented retention, indexes, archival, and table-size monitoring.

## Positive controls already present

- Faction HQ interaction no longer permits self-joining: `sunset_factions/server/main.lua:77-83` directs players to the application/invite flow.
- Leaving a faction is separate from the civilian job: `sunset_factions/server/main.lua:85-115` preserves job state.
- Faction invites validate authority, target state, proximity, and expiry.
- Faction fleet requests validate faction, duty, rank, depot, and model; client-spawn registration performs additional driver/model/depot checks.
- Trucker completion validates assigned truck/trailer and destination position, and a trailer recovery path exists.
- Fishing cast/reel uses server tokens, timing, zones, and item metadata rather than accepting only a client success boolean.
- Recent robbery flows contain session, token, busy-state, proximity, and rate-limit checks; these patterns should be reused elsewhere.
- Property instances use separate routing buckets per property.
- Dealership stock decrement is conditional and purchase has a local lock, although the overall purchase still needs one transaction.

## Resource-by-resource assessment

| Resource | Risk | Audit result |
|---|---|---|
| sunset_admin | Medium | Broad authority surface; command authorization exists, but admin mutations need uniform persistent audit/idempotency tests. |
| sunset_appearance | Medium | NUI/state lifecycle depends on the shared UI; test reconnect, cancel, and failed-save paths. |
| sunset_auth | High | Weak password KDF and plaintext quick-login storage are release blockers. |
| sunset_businesses | Medium | Economy/property coupling requires the same transactional ledger guarantees. |
| sunset_carjack | Medium | World/entity actions need server ownership, distance, cooldown, and replay verification. |
| sunset_characters | High | Bootstrap/session transitions can partially persist; duplicate-login flow risks unsaved state. |
| sunset_chat | Medium | Shared focus/command ownership has regressed repeatedly; overlapping commands require runtime verification. |
| sunset_clans | Medium | Membership/leadership writes require concurrency and permission matrix tests. |
| sunset_clothing | Medium | Current JS syntax passes; shared NUI and store state/focus remain regression-prone. |
| sunset_core | High | Generic callback gateway, cache concurrency, progression and session lifecycle are foundational risks. |
| sunset_crafting | Critical | Concurrent crafting duplication/partial consumption path. |
| sunset_dealership | High | Stock/payment/ownership compensation is not atomic. |
| sunset_death | High | Wanted/jail/death transitions need authoritative, exactly-once state tests. |
| sunset_dispatch | Medium | Validate access, alert visibility, spam control, persistence, and reconnect delivery. |
| sunset_documents | Medium | Access/ownership and NUI focus need adversarial testing. |
| sunset_economy | Critical | Payday, ATM, transfer, and lottery ledger integrity are unsafe under failure/concurrency. |
| sunset_emotes | Medium | Key ownership (`X`, chat/phone focus) needs one input arbiter. |
| sunset_factions | Medium/High | Core membership flow is correct; police radar evidence remains client-authoritative. |
| sunset_fire | Medium | Incident entity lifetime/cleanup and concurrent responder ownership need runtime tests. |
| sunset_fishingshop | Medium | Current source parses; purchase/inventory failure and UI lifecycle require integration tests. |
| sunset_help | Medium | Command discovery is incomplete when registrations are split; generate from one command registry. |
| sunset_hud | Medium | Per-frame cost, text readability, state synchronization, and panel-hide behavior need profiling/tests. |
| sunset_interactions | Medium | Recent global/export initialization regressions show dependency/readiness fragility. |
| sunset_inventory | Critical | Racy mutations, incomplete constraints, partial trade, and deterministic dual-modal UI. |
| sunset_jobcreator | Critical | Client can forge stage success and reach payout. |
| sunset_jobs | High | Parallel job systems and non-atomic rewards/sales; legacy/new paths must be reconciled. |
| sunset_licenses | High | Functional structure is substantial, but per-bullet DB checks are a scale blocker. |
| sunset_loadscreen | Medium | Transition state is spread across loadscreen/auth/spawn; one finite-state flow is needed. |
| sunset_menu | High | `/v` stale-mode path and shared modal/focus state cause broken UI. |
| sunset_needs | Medium | Payday/session persistence and authoritative update cadence need failure tests. |
| sunset_pass | Medium | Rewards must use the same atomic ledger/inventory service and replay protection. |
| sunset_phone | High | Focus regressions plus runtime DDL/query indexing; 112 paths need end-to-end error handling. |
| sunset_player | Medium | Identity/overhead/UI state needs event-driven positioning and reconnect cleanup. |
| sunset_properties | High | Buy/rent/owner-credit workflows are multi-write compensation chains. |
| sunset_robbery | Medium | Newer validation is comparatively good; payout/wanted/jail exactly-once tests remain mandatory. |
| sunset_scoreboard | Medium | Startup race and scaling/N+1 risk. |
| sunset_spawn | High | Last-location collision/ground readiness and loadscreen state need deterministic state machine tests. |
| sunset_taxi | Medium | Fare/mission state needs disconnect, vehicle loss, spoof, and payment tests. |
| sunset_tuning | High | Missing queried model plus circular dependency; purchase/install persistence needs atomicity. |
| sunset_turfs | Medium/High | Ownership/reward/concurrency and restart reconciliation require adversarial tests. |
| sunset_ui | High | Monolithic mixed-generation UI, modal collision, z-index/focus/cascade regressions. |
| sunset_vehicles | High | Fuel client trust, persistence consistency, and tuning dependency cycle. |
| sunset_world | Medium | Continuous native loops and global state changes need profiling and compatibility tests. |
| external dependencies | Medium | Startup parity/version pinning for oxmysql, voice, interiors, maps, and libraries is not enforced. |

## Architecture and ownership map

The intended boundaries are recognizable—core identity, inventory, economy, jobs, factions, vehicles, and UI—but write ownership is not strict:

- money is changed by many systems through cache-sensitive helpers;
- items are changed through a non-transactional shared API;
- jobs exist in both legacy `sunset_jobs` and stage-driven `sunset_jobcreator` paths;
- vehicle capabilities are shared through a circular dependency;
- one NUI document hosts many modal systems with independent visibility and focus logic;
- schema evolution occurs in numbered migrations, deploy scripts, and resource startup code.

The target architecture should enforce one owner per invariant: a transactional ledger for value, a transactional inventory service, a server-owned activity/session engine, a single UI modal/focus arbiter, and one migration runner.

## Performance and scale forecast

| Population | Expected state without fixes |
|---:|---|
| 25 | Usually playable, but exploitable economy and intermittent UI/data inconsistency remain. |
| 50 | DB-per-shot licensing, nearby scans, callback spam, UI payloads, and synchronous queries become visible during peaks. |
| 100 | High probability of DB queueing, stale caches, missed callbacks, NUI focus collisions, and economic race conditions. |
| 200 | Not supportable reliably with current hot paths, polling, transaction model, and lack of load/replay tests. |

Measurements required before any capacity claim: server tick time, per-resource CPU/resmon, DB query p50/p95/p99 and pool wait, event rates/bytes, NUI frame time, entity counts, state-bag traffic, cache hit rate, and transaction retry/deadlock rate.

## Top 20 release risks

1. Rotate and purge the committed infrastructure credential.
2. Remove client authority from Job Creator stage completion/rewards.
3. Eliminate crafting duplication with transactional inventory mutation.
4. Make trade items/cash/assets one atomic settlement.
5. Add inventory uniqueness and concurrency control.
6. Replace cache-based XP/RP/money absolute writes.
7. Make buy-level transactional and lock-safe.
8. Make payday durable and idempotent.
9. Make ATM/bank transfers double-entry and atomic.
10. Make fuel/entity/tank facts server-authoritative.
11. Fix tuning's missing model query.
12. Break the tuning/vehicles dependency cycle.
13. Replace weak password hashing and plaintext quick-login secrets.
14. Make duplicate-login eviction persist before cleanup.
15. Make property/dealership settlements atomic.
16. Make lottery rounds and payouts replay-safe.
17. Remove license DB reads from the bullet hot path.
18. Enforce mutually exclusive NUI modal/focus state.
19. Rebuild inventory layout around viewport constraints.
20. Make `/v` initialize a complete vehicle-menu state every time.

## Required validation gates

Before release, the server needs automated tests covering:

- duplicated/reordered/replayed client events;
- two simultaneous callbacks for every value mutation;
- forced DB failure after each step of trade, craft, purchase, rent, payday, lottery, and buy-level;
- disconnect/reconnect/resource restart during each workflow;
- permission matrix for civil, faction ranks, leader, admin levels, duty/off-duty, dead/cuffed/jailed;
- two real FiveM clients for proximity, invites, cuff/arrest, trade, 112, overhead labels, factions, jobs, and licenses;
- NUI open/close sequences and focus invariants across M, I, trade, `/v`, phone, chat, factions, stores, clothing, rob, fish, spawn;
- resolution/UI-scale screenshot comparison;
- 25/50/100-player synthetic callback and database load.

## Final conclusion

The repository should be treated as a feature-rich pre-release framework, not a finished production framework. Existing reports that label subsystems complete are insufficient because they generally prove file presence or happy-path behavior, not atomicity, replay resistance, startup parity, multiplayer concurrency, or UI state isolation. The next work must follow the ordered remediation plan and stop adding large feature surfaces until the P0/P1 invariants are protected.
