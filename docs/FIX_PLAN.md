# SunsetMP / BlazeMP — Ordered Fix Plan

This plan is derived from `FULL_GAMEMODE_AUDIT.md`. It deliberately separates containment, invariant repair, UI repair, and release validation. No implementation change was made as part of the audit pass.

## Rules for all fixes

1. Never trust a client-provided success, reward, price, balance, vehicle class, tank capacity, speed, rank, entity ownership, or distance when the server can derive it.
2. Every operation moving money/items/assets must be atomic, conditional, auditable, and retry-safe.
3. Use deterministic per-character locks only as a latency optimization; database constraints and transactions remain the final authority.
4. Every callback returns a stable error code plus a clear Romanian player message. Internal details go only to structured logs.
5. One UI state machine owns modal visibility and NUI focus.
6. No runtime `CREATE/ALTER TABLE`; deployments run one checked migration pipeline.
7. Each patch includes adversarial, failure-injection, reconnect, and replay tests—not only a happy path.

## Phase P0 — Immediate containment (release blocking)

### P0.1 Rotate and purge the exposed credential

- **Files/systems:** `scripts/vps-restart-all.sh`, Git history, VPS/Coolify secrets, database user/network policy, CI secret scan.
- **Action:** rotate first; replace tracked values with environment/secret references; purge historical blob; scan all branches/tags/archives.
- **Risk:** deployment outage if secret consumers are not updated together.
- **Verification:** old credential rejected; new deploy and migration authenticate; repository/history scanner returns no match.
- **Regression:** restart/deploy from a clean clone.

### P0.2 Temporarily disable exploitable Job Creator rewards

- **Files:** `sunset_jobcreator/server/engine.lua`, `server/stages.lua`.
- **Action:** gate reward-bearing templates until server-owned stage verification is implemented. Do not merely hide the UI.
- **Verification:** direct/replayed `JCEngine_ClientAction` calls cannot advance or pay.

### P0.3 Contain crafting and trade

- **Files:** `sunset_crafting/server/main.lua`, `sunset_inventory/server/trade.lua`, inventory mutation service.
- **Action:** serialize per-character operations and disable unsafe settlement paths if a full transaction cannot be shipped immediately.
- **Verification:** 100 concurrent duplicate requests yield at most one valid outcome and preserve total value.

## Phase P1 — Rebuild value invariants

### P1.1 Transactional ledger service

- **Files:** `sunset_core/server/player.lua`, `sunset_economy/server/main.lua`, `lottery.lua`, SQL migrations.
- **Action:** create double-entry ledger/operation table with unique idempotency key; atomic balance deltas; committed balances returned to cache.
- **Dependencies:** migration runner P2.1 can be introduced first if preferred.
- **Expected result:** no money creation/destruction on retry, crash, or destination failure.
- **Tests:** ATM, transfer, shop, payday, lottery, buy-level, disconnect, DB timeout, duplicate packet.

### P1.2 Transactional inventory service

- **Files:** `sunset_inventory/server/main.lua`, schema, every caller that grants/removes items.
- **Action:** unique `(character_id,slot)`, item version/conditional count updates, locked capacity selection, atomic move/swap, operation keys.
- **Expected result:** one authoritative path for add/remove/move/consume/grant.
- **Tests:** concurrent use/craft/reward/drop/trade; full inventory; stack boundaries; forced query failure.

### P1.3 Atomic trade settlement

- **Files:** `sunset_inventory/server/trade.lua`, ledger/inventory/property/vehicle ownership tables.
- **Action:** lock both participants in sorted ID order; revalidate offers; commit items, money, and assets together; mark trade settled once.
- **Tests:** either all values move once or none move; disconnect and retry recover safely.

### P1.4 Atomic crafting

- **Files:** `sunset_crafting/server/main.lua`, inventory service.
- **Action:** recipe lookup server-side, locked conditional ingredient consumption, capacity check, output grant in one transaction.
- **Tests:** request burst, altered recipe/payload, two recipes sharing inputs, cancellation, full inventory.

### P1.5 Progression/payday/buy-level

- **Files:** `sunset_core/server/player.lua`, `sunset_economy/server/main.lua`, progression schema.
- **Action:** atomic RP/XP increments, durable active minutes, unique payday period, transaction for all payday effects, transactional buy-level.
- **Tests:** exact SA:MP-style RP progression, multiple missed periods, restart at boundary, insufficient RP/cash, M remains open and refreshes after buy-level.

## Phase P2 — Server authority and schema discipline

### P2.1 One migration pipeline

- **Files:** `deploy.sh`, `scripts/vps-restart-all.sh`, `sql/*.sql`, resource startup DDL.
- **Action:** `schema_migrations(version,checksum,applied_at)`, ordered unique versions, fail-fast runner, backup/restore drill, remove runtime DDL.
- **Tests:** empty DB, current production clone, second idempotent run, checksum mismatch, failed migration rollback.

### P2.2 Job Creator server-owned state machine

- **Files:** `sunset_jobcreator/server/engine.lua`, `server/stages.lua`, client stage adapters.
- **Action:** server creates session/stage nonce; derives next stage; verifies model/net ID/owner/position/time/route; consumes nonce once; settles reward through ledger.
- **Tests:** skip/reorder/replay stages, teleport, delete/replace entity, leave vehicle/trailer, disconnect, resource restart.

### P2.3 Vehicle fuel and persistence authority

- **Files:** `sunset_vehicles/server/main.lua`, client fuel code, DB schema.
- **Action:** server resolves vehicle class/tank/plate/entity and validates pump/driver; calculate consumption from authoritative class/RPM/load model; persist fuel/engine/odometer consistently.
- **Tests:** owned/non-owned, full tank, gas can, bank/cash, reconnect/store/retrieve, network ownership migration.

### P2.4 Property, dealership, lottery settlements

- **Files:** `sunset_properties`, `sunset_dealership`, `sunset_economy/server/lottery.lua`.
- **Action:** replace compensation chains with DB transactions and operation ledgers; unique claims/plates/tickets/payouts.
- **Tests:** insufficient level/funds never debit; duplicate click buys once; failure at every statement; restart reconciliation.

### P2.5 Authentication/session hardening

- **Files:** password helper, auth server/client/accounts, session lifecycle.
- **Action:** password-hard KDF migration, revocable quick-login token, rate limits/backoff, save-before-duplicate-eviction, unique normalized email/username constraints.
- **Tests:** legacy password migration, stolen/revoked token, concurrent login, reconnect, DB delay, enumeration-safe errors.

## Phase P3 — UI/input architecture repair

### P3.1 Central NUI modal and focus arbiter

- **Files:** `sunset_ui/web/js/panels.js`, menu/inventory/trade/phone/store scripts, client focus calls.
- **Action:** one state store owns `activeModal`, subview, payload, focus, cursor, HUD dimming, and transition. Opening one modal must close every incompatible root.
- **Expected result:** no black orphan overlay, dual trade, invisible focus trap, or chat/phone cursor theft.
- **Tests:** pairwise open/close matrix for M/I/trade/V/phone/chat/faction/store/clothing/fish/rob/spawn; Escape and resource stop.

### P3.2 Inventory and trade component unification

- **Files:** `inventory-forza.css/js`, `trade-forza.css/js`, inventory markup.
- **Action:** one reusable inventory grid component; trade embeds it without opening standalone I; one cell size/aspect/image rule; bounded duty/loadout section; internal scroll.
- **Visual requirements:** no opaque full-screen black rectangle; consistent redesign tokens; readable vignette; uniform item squares; complete UI inside viewport.
- **Tests:** empty/full/duty inventory, 720p/1080p/1440p/ultrawide, UI scaling, long labels, trade start/cancel/accept.

### P3.3 Repair `/v` state transition

- **Files:** `sunset_vehicles/client/main.lua`, `sunset_menu/client/main.lua`, `sunset_ui/web/js/menu.js`.
- **Action:** every `/v` open performs a full vehicle-mode initialization and refresh, regardless of previous menu state; remove tab-only early return.
- **Tests:** `/v` cold, after M, while M open, after inventory, in/out vehicle, empty/many vehicles, repeated open/close.

### P3.4 Consolidate design system

- **Files:** all NUI CSS, `server redesign` references, shared tokens/components.
- **Action:** define typography, spacing, surface alpha, borders, colors, z-index layers, buttons, list/grid, close control, and vignette once. Migrate one panel at a time and delete legacy rules after parity.
- **Tests:** screenshot baselines compared to approved 1:1 references; no global selectors leaking into another panel.

### P3.5 Input ownership

- **Files:** chat, phone, interactions, emotes, menu, inventory clients.
- **Action:** central input context for T/P/G/X/Z/I/M; explicit focus acquire/release and resource-stop cleanup.
- **Tests:** 112 call → phone reopen → chat; player interaction; MDC; quick emotes; pause menu; death/cuff transitions.

## Phase P4 — Runtime/performance and domain cleanup

### P4.1 License hot path cache

- **Files:** `sunset_licenses/server/main.lua`.
- **Action:** load license state on character activation, update cache on grant/payday expiry, enforce firearm/flying/boat/driving without per-event DB reads.
- **Performance gate:** zero database queries per bullet.

### P4.2 Break resource cycle and fix tuning data

- **Files:** tuning/vehicles manifests and shared config; `sunset_tuning/server/main.lua`.
- **Action:** third shared vehicle-definition module; query model explicitly; versioned persisted tune payload; validate capabilities server-side.
- **Tests:** clean boot/restart order, dyno, install/remove, reconnect, representative car categories.

### P4.3 Query/index optimization

- **Files:** inventory nearby lookup, phone messages, scoreboard, logs, migrations.
- **Action:** spatial scoping, batched player queries, phone composite indexes, query timing instrumentation, retention/archive jobs.
- **Gates:** define p95/p99 budgets and verify at 25/50/100 simulated players.

### P4.4 Client profiling

- **Files:** HUD/world/player-label loops and NUI payload code.
- **Action:** resmon capture idle/driving/combat/menu; cache static scaleforms/state; reduce polling; event-drive data; throttle overhead label updates.
- **Gate:** publish measured before/after CPU and NUI frame-time results.

### P4.5 Reconcile duplicate domain engines

- **Files:** `sunset_jobs` vs `sunset_jobcreator`, legacy/new UI panels, duplicated commands.
- **Action:** select one canonical job/session contract and one command registry. Adapt legacy jobs or retire duplicated paths deliberately.
- **Tests:** every job's start/progress/recovery/cancel/reward and faction separation.

## Phase P5 — Complete release verification

### Automated gates

- Lua parse/lint for every Lua file.
- JavaScript syntax/lint and NUI unit/state tests.
- Manifest/dependency DAG validation (cycles fail CI).
- Secret scanning for all tracked file types and Git history.
- SQL migration clean/upgrade/repeat/rollback tests.
- Callback schema, permission, rate-limit, and replay tests.
- Failure injection for every economy/inventory workflow.
- Load test at 25, 50, and 100 simulated clients/events.

### Two-client gameplay matrix

Test every command and interaction as: civilian, each faction rank, leader, off-duty/on-duty, admin levels, dead, cuffed, jailed, wanted surrenderable/non-surrenderable, inside/outside correct vehicle and zone.

Mandatory flows:

- login, quick login, character selection, default/last/home/rent spawn;
- M, I, trade, `/v`, phone/112, chat, interaction menu, scoreboard;
- every civilian job including vehicle/trailer loss and 60-second recovery;
- faction application/invite/leave/duty/fleet/commands/weekly report;
- police cuff/ticket/radar/arrest/death-to-jail/wanted decay;
- EMS/fire/dispatch incidents and entity cleanup;
- all license theory/practical/instructor review/grant/expiry paths;
- vehicle buy/store/park/fuel/damage/tune/insurance/persistence;
- property buy/rent/manage/description/interior/spawn/sale;
- robbery/minigame/reward/wanted/jail/reconnect;
- crafting/business/shop/clothing/pass/lottery.

### Release acceptance criteria

- Zero Critical/High unresolved findings.
- No known value-duplication or value-loss path.
- No client-authoritative rewards or economic values.
- No plaintext credential storage or committed secret.
- No resource dependency cycle.
- No runtime schema mutation.
- No dual modal or orphan NUI focus in the pairwise UI matrix.
- Clean upgrade from a production database copy with reconciliation totals unchanged.
- 24-hour soak with restart/reconnect and no unexplained balance, inventory, ownership, wanted, license, or faction drift.
- Published rollback procedure and verified backup restore.

## Recommended execution order

Do **P0 → P1 → P2 → P3 → P4 → P5**. UI work can proceed alongside backend work only if it does not obscure or postpone the critical value/security invariants. Feature expansion should remain frozen until P0/P1 pass.
