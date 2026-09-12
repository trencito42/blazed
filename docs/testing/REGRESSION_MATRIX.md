# REGRESSION_MATRIX — Test Status & Evidence

**Legend:** PASS (verified with evidence) · FAIL · BLOCKED (needs runtime/manual) · AUTOMATED (script exists) · MANUAL

## 1. Automated static checks (runnable now)

| Check | Tool | Status | Evidence / how to run |
|---|---|---|---|
| Lua syntax (all resources) | luaparse harness | PASS | 257/257 files, `docs/audit/AUDIT_STATE.md` capacity notes |
| JS syntax | `node --check` sweep | PASS | 53/53 files |
| Manifest refs resolve | `scripts/audit-static.ps1` | PASS (AUTOMATED) | 42 resources, all script paths exist |
| Duplicate/dual-side commands | audit-static.ps1 | PASS | 9 known intentional pairs listed |
| Secret scan (Lua) | audit-static.ps1 | PASS | no `cfxk_`/passwords in tracked Lua |
| Secrets never committed | `git log --all` grep | PASS | history clean; server.cfg/.env gitignored |
| NUI callback completeness (JS fetch names vs bridge forwards) | **TODO script** | BLOCKED→build | needs `scripts/check-nui-bridge.js` (Phase 2 task) |
| Direct-DB-write detector (writes outside owning resource) | **TODO script** | BLOCKED→build | grep `UPDATE/INSERT/DELETE` per resource vs DOMAIN_OWNERSHIP table |
| SQL migration idempotency | live re-run | PASS | sql/42 re-ran clean on VPS (2nd apply = "already applied" + prepared-statement gates) |
| Runtime DDL in resources | grep | PASS | zero CREATE/ALTER in Lua |

## 2. Server startup (VPS, 2026-09-12)

| Check | Status | Evidence |
|---|---|---|
| All resources start | PASS | `docker compose logs fivem`: 50 "Started resource", 0 errors/exceptions |
| DB connect | PASS | oxmysql "Database server connection established", core "database connected" |
| Turfs load | PASS | "Loaded 16 gang territories" |
| Migrations applied | PASS | schema_migrations has 42; FKs fk_property_owner/fk_business_owner/fk_lottery_char/fk_turf_clan verified present; uk_container_item verified |
| Container healthy | PASS | `Up (healthy)` both fivem+mariadb |
| OneSync enabled | **BLOCKED** | txAdmin controls onesync at runtime; cfg line commented by txAdmin validator. VERIFY in txAdmin settings page (40120) that OneSync=Infinity is ON. Required for damage/explosion gating to actually cancel. |
| pma-voice present | PASS | info.json resources list includes pma-voice + ox_lib + bob74_ipl (Docker image installs them) |
| oxmysql transaction adapter (commit eb138d0) | PASS (deployed) | VPS HEAD = eb138d0, `transactionAdapter` present, container healthy, 50 resources started, 0 errors. The typed `query.single/update/insert.await` helpers used by the Phase-5 transaction fixes (crafting, fisherman, tuning, dealership, trade, deleteCharacter) run on the transaction connection through this adapter. |
| Phase 2 deploy (sunset_sessions + trucker hardening) | PASS (startup) | commit aa28709/af92473 deployed; 51 resources started incl. sunset_sessions ("session service online"), 0 script errors, info.json alive, containers healthy |
| NUI bridge completeness | PASS (AUTOMATED) | `node scripts/check-nui-bridge.js` — 162/162 posted callbacks registered; 29 registered-without-caller are other-resource NUI pages (pass/robbery/tuning) + dynamic ESC map (informational) |
| Cross-domain DB writes | PASS (AUTOMATED) | `node scripts/check-db-writes.js` — 0 NEW violations; 11 known-debt entries tracked for Phase 3 remediation |
| Session framework unit tests | BLOCKED (remote) | `sunset_testdriver` console commands (integrity/sessiontest/smoketest/testall) or `+setr testdriver_autorun 1`. VPS regenerates server.cfg from template each start, wiping convars; run locally on the Windows dev server, or temporarily add testdriver to config/server.cfg.template for one CI boot |
| Transaction paths at runtime (craft/tune/purchase/trade/delete-char) | **BLOCKED** | adapter is new — exercise each txn path once in-game and check for `Callback error` in `docker compose logs fivem` (R31) |

## 3. Runtime gameplay tests (ALL BLOCKED — need in-game execution)

The static audit cannot execute these. Each maps to a fix; run before trusting the fix in production. Full list also in `docs/audit/AUDIT_STATE.md`.

| # | Scenario | Verifies | Expected |
|---|---|---|---|
| R1 | `/112` with `<img src=x onerror=alert(1)>` as description | P8-01 XSS | renders as literal text in MDC, no execution |
| R2 | `/service taxi <script>` | P8-02 XSS | escaped in calls panel |
| R3 | Faction grade label with HTML | P8-03 XSS | escaped in chat header |
| R4 | Sell stolen car at chop shop vs elsewhere | P2-01 carjack | pays+deletes at shop; refuses elsewhere; owned plate refused |
| R5 | Spam carjack sell 5×/sec | P2-01 cooldown | one sale per 10s |
| R6 | Vehicle trunk access | N/A | No player-facing trunk system is implemented; do not assign this to testers |
| R7 | Deposit item while trade-locked | P5-03 dupe | no duplication |
| R8 | Jailed player at hourly payday | P6-01 | $0, no RP/rob point |
| R9 | Taxi: spam complete callback | P5-04 | single charge |
| R10 | Taxi: passenger downed mid-ride | P6-02 | ride cancels, meter stops, both freed |
| R11 | Trade/give-cash/shop/dice while downed | P6-05 | refused |
| R12 | 5 wrong passwords | P2-04 | lockout w/ countdown |
| R13 | Store vehicle w/ injected props.ecu + fuel=100 | P4-01/02 | ecu not persisted; fuel capped |
| R14 | Crash car to ~90 engine, re-store, respawn | P4-04 | spawns damaged (no free heal) |
| R15 | Disconnect with owned car out in world | F7.2/P6-03 | car deleted, stored=1, coords saved |
| R16 | Die inside a house | P3-04 | hospital respawn visible (bucket reset) |
| R17 | Open "sell car" interaction menu, press ESC / walk away | 9c UI hang | menu closes, focus released, can move |
| R18 | Ticket-receive: fail PAY then ESC | P8-11 | window closes, no focus trap |
| R19 | Open M menu then /clan | P8-12 | no stuck cursor after closing clan |
| R20 | Craft with insufficient 2nd material | P5-01 | nothing consumed (txn rollback) |
| R21 | Sell fish from middle of map | P2-09 | refused (needs 24/7 or Billy Ray) |
| R22 | Dice: opponent disconnects mid-roll | P5-07 | both wagers refunded |
| R23 | `restart sunset_economy` mid-dice-roll | P5-07 | escrow refunded on stop |
| R24 | `restart sunset_factions` while players online | P7-12 | wanted/jail rehydrated |
| R25 | Officer escorts suspect then leaves faction | P6-08 | escort released |
| R26 | Chop NPC peds after `restart sunset_carjack` | P7-09 | no duplicate peds |
| R27 | Courier job HUD | P8-22 | renders (courier.js linked) |
| R28 | ATM transfer from middle of map | P2-08 | refused (needs ATM) |
| R29 | Delete the active identity/account owning house/business/clan | INTERNAL/DESTRUCTIVE | Not a secondary-character test; run only against a disposable database fixture |
| R30 | NUI fonts/icons load with internet blocked | P7-05 | render from local assets |

## 4. Concurrency / adversarial (BLOCKED — needs 2+ clients or test-driver)

| # | Scenario | Invariant |
|---|---|---|
| A1 | Two players pick same ground drop simultaneously | I1 (one gets it) |
| A2 | Two concurrent trade commits same items | I1/M5 |
| A3 | Two vanity-plate saves racing | V1 (FOR UPDATE now on txn connection) |
| A4 | 100 concurrent craft requests | I5/M5 |
| A5 | Concurrent dealership purchase of last stock | M5 (stock decrement txn) |
| A6 | Payday + trade + buyLevel interleaved on one char | M6 (no lost update) |
| A7 | Replay `sunset:server:playerLoaded` mid-session | C3 |

**Note:** A1-A7 require the dev-only simulated-player/test-driver described in the brief §10. Building it is a Phase 2 deliverable (`sunset_testdriver`, dev-only, no production authority).

## 5. Per-activity vertical-slice matrix (target: fill as each is ported)

Columns = the 19 required handlers (success, cancel, timeout, death, arrest, cuff, bucket, vehicle-exit, entity-destroy, disconnect, reconnect, resource-restart, server-restart, duplicate, invalid-data, DB-failure, missing-dep, concurrency, NUI-closed). Rows = Trucker, Fisherman, Courier, Garbage, Mechanic, Taxi, Robbery, Carjack, Licenses, Dice, Turfs. Current: robbery ≈ mostly covered; taxi improved (P6-02); others partial. Trucker is the reference slice to complete next.
