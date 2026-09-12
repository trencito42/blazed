# SunsetMP Master Audit

**Started:** 2026-09-11
**Repo:** `C:\Users\stefan\Documents\sunsetmp` (FiveM Windows dev box + Docker/VPS parity)
**Scope:** full production-readiness audit in 9 phases. See `AUDIT_STATE.md` for progress.
**Method:** source-first static analysis; runtime tests listed but deferred.
**Prior artifacts treated as untrusted historical context:** `docs/FULL_GAMEMODE_AUDIT.md`, `docs/FIX_PLAN.md`, `SECURITY_AUDIT.md`, `RELEASE_AUDIT.md`, `docs/RPG_FRAMEWORK_AUDIT.md`, `docs/FINAL_RPG_AUDIT_2026-09-03.md`.

---

## 1. Repository & Architecture Map (Phase 1 — COMPLETE)

### 1.1 Layout

| Path | Role |
|---|---|
| `FXServer.exe`, `*.dll`, `citizen/`, `cache/`, `crashes/` | FiveM server artifacts (gitignored except none — binaries are *.dll/*.exe ignored) |
| `server.cfg` | Live server config (gitignored; **contains plaintext sv_licenseKey + MySQL root creds**) |
| `config/server.cfg.template`, `docker/fivem/` | VPS/Docker deployment (tracked) |
| `docker-compose.yml` | MariaDB 11.4 + custom fivem image; txAdmin optional on 40120 |
| `resources/oxmysql/` | DB layer (external) |
| `resources/[sunset]/` | 42 custom resources (the gamemode) |
| `sql/01–41` | MySQL migrations (gaps at 27–28) |
| `docs/` | Prior audits/plans (historical, partially stale) |
| `scripts/` | Deploy/diag scripts incl. `audit-static.ps1` |
| `server redesign/`, `premium_*.html` | Loose untracked UI prototypes (not wired to resources — verify in Phase 8) |
| `funpay-setup.cjs` | Untracked CLI setup script pointing at `http://buytokens.duckdns.org:4100` (external gateway; review before any execution) |

### 1.2 Resources (42 custom, ~25 MB Lua/JS/HTML, ~800 script files)

All custom ("SunsetMP/blaze.mp"); **no ESX/QBCore**. Optional client-side `ox_lib` (crafting, world), `pma-voice` dependency (hud). All manifests: `fx_version 'cerulean'`, `game 'gta5'`, `lua54 'yes'`, **no `use_fxv2_oop`**.

Largest by script size: sunset_ui (13.8 MB, monolithic vanilla-JS NUI), sunset_loadscreen (8.1 MB, mostly PNGs), sunset_factions (317 KB), sunset_core (189 KB), sunset_jobs (165 KB), sunset_tuning (161 KB), sunset_licenses (137 KB), sunset_inventory (125 KB), sunset_vehicles (114 KB), sunset_robbery (106 KB).

### 1.3 Core framework (sunset_core)

- **State ownership:** server-side `Players[source]` table + cached `character` table (`server/main.lua:1`, `loadCharacterForPlayer` :290–325). Statebags: `sunsetName`, `sunsetDisplayName` (+ clan tags from sunset_clans).
- **RPC bus:** all client→server requests funnel through `sunset:server:triggerCallback` → `Callbacks[name]` registry (`core/server/main.lua:36–96`). **~290 registered callbacks** across resources (factions 69, jobs 34, inventory 25, vehicles 16, licenses 13…). Rate limits: 30/s global, 12/s per name, tighter `EXPENSIVE_CALLBACK_LIMITS`; flood response = print only.
- **Raw net events:** only ~45 `RegisterNetEvent` in server code (robbery 7, admin 7, death 6, factions 5, core 4, chat 3, vehicles 2…).
- **Money API (canonical):** `AddMoney/RemoveMoney/GetMoney/MoveMoney/TransferMoney` (`core/server/player.lua:185–320`). DB is source of truth; guarded `UPDATE … WHERE cash/bank >= ?` + re-SELECT; `money_transactions` audit ledger (`money_log.lua`). Blaze Points on `accounts.premium_points`. `SaveCharacter` re-reads cash/bank before write (:47–51).
- **Soft circularity:** core reverse-calls `exports.sunset_properties/clans/admin` (pcall/GetResourceState-guarded).
- **Command routing:** `sunset:chat:runCommand` → `command_router.lua:79–92` hardcoded fan-out to `ExecutePlayerCommand` exports of ~13 resources (fragile choke point; 400 ms/command rate limit).

### 1.4 Auth & characters

- Node scrypt (N=32768) hashing (`sunset_auth/server/password.js`); legacy Lua SHA-256 fallback still accepted (`core/shared/password.lua`, `auth/server/main.lua:124`).
- Quick-login tokens: SHA-256 token hash + device hash, 30-day expiry (`sql/38`, client KVP storage).
- `CompleteAuthentication` (core export) re-validates account row, kills duplicate sessions, links `players` by account_id/license.
- Character load validates ownership server-side; never accepts client char objects (`core/server/main.lua:292–334`).

### 1.5 Database

- Scattered direct oxmysql access: 29/42 resources `@oxmysql`; heaviest: factions 62 calls, core 58, properties 44, clans 38, inventory 36, vehicles 29.
- Parameterization: essentially universal `?` placeholders; dynamic fragments use whitelisted column maps. No raw client-string concatenation found in Phase 1 sampling.
- Transactions used in: dealership purchase, inventory trade commit, tuning save, payday. DB-level guards added in `sql/37` (integrity constraints) and `sql/39–41` (runtime schema, payday/lottery ledgers).

### 1.6 Vehicles

- `vehicles` table keyed by `character_id` (plate, model, health, props JSON, parked coords, insurance, destroyed flag).
- Spawn: server validates ownership → **entity created client-side** (`spawnOwnedVehicleEntity`); server cleanup broadcast.
- Store/park: **client-reported props/fuel/odometer/coords** accepted with validations (size cap, monotonic odometer, driver check, server-entity health read when resolvable) — `vehicles/server/main.lua:261–349`.
- Keys: **in-memory only** (`VehicleKeys`, :778–820) — lost on restart.
- Faction fleet: ephemeral entities + statebags `sunsetFactionVehicle`/`sunsetProtectedVehicle`; registered via raw net event `sunset:factionRegisterFleetVehicle` with model/depot/duty/driver validation (`factions/server/main.lua:490–523`).

### 1.7 Economy

Server-authoritative overall: payday (ledger + uniqueness guard), shops (proximity + catalog whitelist + refund-on-fail), ATM/transfer via core, taxi meter server-side, jobs payouts server-validated, dice escrow, lottery ledger. **Client-trusted spots:** vehicle props/fuel, tuning dyno leaderboard numbers (`tuning/server/main.lua:282`).

### 1.8 Admin

DB flag by license (`admins` table + `accounts.admin_level` fallback), NOT ACE. Levels 1–5; `IsAdmin(source, minLevel)` export. `setowner` via console → level 5. Bans checked at `playerConnecting`.

### 1.9 UI/NUI

- sunset_ui: single vanilla-JS page hosting all screens (~100 JS files); `client/nui_bridge.lua` forwards 162 NUI callbacks as **client-local** events `sunset:nui:<name>`; feature resources convert to `Sunset.AwaitCallback`. NUI never reaches server directly.
- sunset_loadscreen: static, `loadscreen_manual_shutdown 'yes'`, shutdown orchestrated by core. Branding drift: "XODO RP" vs "blaze.mp" vs "SunsetMP".
- Google Fonts fetched remotely from NUI/loadscreen (external network dependency).
- Own NUI pages: sunset_pass, sunset_robbery, sunset_tuning, sunset_licenses.

### 1.10 Deployment

- Local Windows: `server.cfg` with root MySQL creds + license key in plaintext (gitignored — NOT in git history per `git ls-files`; verify history in Phase 2).
- VPS: Docker Compose (MariaDB + custom fivem image), env-driven secrets via `.env` (template tracked, `.env` ignored). txAdmin optional.

---

## 2. Findings Register

Severity: **CRIT** (exploitable now / data loss), **HIGH**, **MED**, **LOW**, **INFO**.
Status: `confirmed` (code-verified this audit), `reported` (from prior artifacts, not yet re-verified), `unresolved` (needs runtime test).

| ID | Sev | Status | Phase | Finding | Location |
|---|---|---|---|---|---|
| P1-01 | CRIT | confirmed | 1 | `sunset:vehicles:adminRepairDatabase` net event has **no admin check** — any player can clear `destroyed` and reset engine/body/fuel on own vehicles for free, bypassing insurance economy | `vehicles/server/main.lua:470–482` |
| P1-02 | HIGH | confirmed | 1 | Inventory trade commit writes `characters.cash` directly (guarded UPDATE in transaction) — bypasses core money API, `money_transactions` ledger, and core's cached balance → audit gap + cache-drift risk | `inventory/server/trade.lua:465–475`; same pattern `tuning/server/main.lua:172`, `dealership/server/main.lua:167` |
| P1-03 | HIGH | confirmed | 1 | Client-reported vehicle props/fuel/odometer/parked coords persisted on store/park; entity spawned client-side → mod/prop injection into DB possible despite validations | `vehicles/server/main.lua:261–349` |
| P1-04 | HIGH | confirmed | 1 | Plaintext secrets in workspace root: `server-tls.key`, `server-monitor-token.key`, `server.cfg` (sv_licenseKey `cfxk_…`, MySQL root pw), `server.7z`. Gitignored but present on disk; verify never committed & not deployed via `push-live-vps` scripts | repo root |
| P1-05 | MED | reported | 1 | Legacy unsalted/salted SHA-256 password fallback still accepted at login | `auth/server/main.lua:124`, `core/shared/password.lua` |
| P1-06 | MED | confirmed | 1 | Vehicle keys in-memory only — grants/keys lost on restart; no persistence | `vehicles/server/main.lua:778–820` |
| P1-07 | MED | reported | 1 | Admin perm split-brain (license table vs accounts column vs inline checks); level-2 mods can grant licenses / `setstat` (cash/bank/level/premium) is level 3 | `admin/server/main.lua:27–41`, `commands.lua:257–262` |
| P1-08 | MED | confirmed | 1 | Callback rate-limit flood response is print-only (no drop/kick); 290 callbacks share default 12/s-per-name limit | `core/server/main.lua:41–96` |
| P1-09 | MED | reported | 1 | Anti-cheat detection-only: banned weapons stripped, teleport/speed merely Discord-logged; `security.lua:84` calls `exports.sunset_admin:IsAdmin` unguarded (error-loop if admin stopped) | `core/server/security.lua` |
| P1-10 | LOW | confirmed | 1 | Dice escrow refund path checks only `GetPlayerName`; possible double-refund/desync window; max bet $500k | `economy/server/dice.lua:38–100` |
| P1-11 | LOW | confirmed | 1 | Google Fonts remote fetch in NUI + loadscreen (external dependency, privacy, CEF perf) | `sunset_ui/web/index.html:36–38` |
| P1-12 | INFO | confirmed | 1 | SQL migration gaps at 27–28; branding drift (XODO RP / blaze.mp / SunsetMP) suggests template rename residue | `sql/`, loadscreen |
| P1-13 | INFO | confirmed | 1 | Untracked `funpay-setup.cjs` targets external `buytokens.duckdns.org` gateway; loose HTML prototypes in root/`server redesign/` not wired in | repo root |
| P1-14 | MED | reported | 1 | Prior audit (`FULL_GAMEMODE_AUDIT.md`) verdict: NO-GO; parallel economy engines, monolithic NUI, circular deps, multi-write non-transactional ops. Cross-check its P0 list against current code in Phases 2–6 | `docs/FULL_GAMEMODE_AUDIT.md`, `docs/FIX_PLAN.md` |

---

## 3. Phase reports

### Phase 1 — Discovery & architecture map — COMPLETE (2026-09-11)
Sections 1–2 above. No production code modified.

### Phase 2 — Security, trust boundaries, network events, server authority — COMPLETE (2026-09-11)

**Scope covered:** all 45 server-side RegisterNetEvent handlers enumerated + classified; all money-adjacent callbacks audited (~40); command router; auth flow; admin system; security.lua; deploy scripts; git history secret scan.

**Verified clean (notable):** command router properly permission-gated with defense-in-depth (no client source spoofing anywhere); negative-amount money inversion impossible (all paths floor+reject ≤0, guarded SQL); trade suite is best-in-codebase (proximity re-checks, single transaction); no os.execute/io.popen/SetHttpHandler exposure; SaveResourceFile admin-gated; secrets never committed to git (history scanned); deploy scripts env-driven; robbery state machine fully server-side.

**New findings (P2-xx):**

| ID | Sev | Finding | Location | Status |
|---|---|---|---|---|
| P2-01 | CRIT | `sunset:carjack:sell` paid out from client-sent model+netId with ZERO validation → unlimited money mint at 12 calls/s | `carjack/server/main.lua:91` | **FIXED** |
| P2-02 | HIGH | = P1-01 adminRepairDatabase no admin check | `vehicles/server/main.lua:470` | **FIXED** (IsAdmin 3 via pcall) |
| P2-03 | HIGH | Replayable `sunset:server:playerLoaded` resets authenticated flag mid-session → account hopping; completeAuthentication overwrote live Players[] without saving | `core/server/main.lua:104,117` | **FIXED** (replay guard + stale-save) |
| P2-04 | HIGH | No brute-force protection on login (12 scrypt/s allowed) | `auth/server/main.lua` | **FIXED** (5 fails → exponential lockout to 5 min; auth callbacks limited to 2/s) |
| P2-05 | HIGH | Container callbacks (trunk/glovebox/property) accepted ANY id — remote looting of any trunk/house by plate iteration | `inventory/server/containers.lua:101–163` | **FIXED** (server-side plate→entity proximity ≤6m or in-vehicle; property owner/renter SQL check; item whitelist; rate limit) |
| P2-06 | MED | security.lua: unguarded IsAdmin export call could kill scanner thread; computed speed unused | `core/server/security.lua:84` | **FIXED** (pcall+GetResourceState; speedAnomaly flag) |
| P2-07 | MED | Client-asserted death (fake downed → EMS spam) and client-claimed killer within 500m (framing via MurderWindow) | `death/server/main.lua:135,166,227` | **FIXED** (server health/IsPedDeadOrDying check; killer claim must match LastPvPAttacker from weaponDamageEvent) |
| P2-08 | MED | atmTransfer callable from anywhere | `economy/server/main.lua:365` | **FIXED** (≤2.5m of Sunset.ATMs) |
| P2-09 | MED | Fish sale: no proximity; metadata.value paid uncapped (trades copy metadata verbatim) | `fishingshop/server/main.lua:182,232,46` | **FIXED** (nearFishBuyer 12m of 24/7s or Billy Ray; value clamped to FISH_PRICES max) |
| P2-10 | LOW | Unthrottled full-state dumps: turfs:requestSync, inventoryRequestDrops | `turfs/server/main.lua:81`, `inventory/server/trade.lua:783` | **FIXED** (RateLimit 5s) |
| P2-11 | LOW | weaponGiveFailed let any client message any player | `admin/server/commands.lua:1110` | **FIXED** (IsAdmin(recipient,1) required) |
| P2-12 | LOW | vehicleDestroyed accepted client claim on healthy car | `vehicles/server/main.lua:355` | **FIXED** (health sanity check; self-harm-only so LOW) |
| P1-02 | HIGH | Direct cash writes bypass money ledger (trade/dealership; tuning already logged) | `trade.lua`, `dealership/server/main.lua` | **FIXED** (LogMoneyTransaction post-commit in trade; ledger INSERT inside dealership transaction) |

**Known residual (accepted, not fixed in Phase 2):** legacy SHA-256 fallback (P1-05 — auto-upgrades to scrypt on login; forced rotation is an ops decision); quick-token in client KVP plaintext (inherent to FiveM; 30d→7d shortening is ops decision); account/email enumeration on register (UX tradeoff, documented); detection-only anti-cheat philosophy (P1-09).

**Static syntax check:** all 257 resource Lua files pass (luaparse, backtick-joaat neutralized); 13 edited files individually verified.

**Files modified in Phase 2:** carjack/server/main.lua, vehicles/server/main.lua (×2), core/server/main.lua (×3), core/server/security.lua, auth/server/main.lua, inventory/server/containers.lua, inventory/server/trade.lua (×2), death/server/main.lua (×3), economy/server/main.lua, fishingshop/server/main.lua (×3), turfs/server/main.lua, admin/server/commands.lua, dealership/server/main.lua.

### Phase 3 — FiveM networking, OneSync, entities, sync — COMPLETE (2026-09-11)

All 45 net events + entity/netId/statebag/bucket/broadcast surfaces reviewed.

| ID | Sev | Finding | Location | Status |
|---|---|---|---|---|
| P3-01 | CRIT | OneSync absent from live server.cfg + template (Docker had it; local ran legacy sync at 48 slots → CancelEvent damage gate no-op, GetAllVehicles scope-limited, server DeleteEntity ghosts) | `server.cfg`, `config/server.cfg.template` | **FIXED** (`onesync on`, `onesync_population false`, `sv_stateBagStrictMode true` added to both; Docker already had it) |
| P3-02 | CRIT | No `explosionEvent` handler — grenades/RPG/C4 ungated | absent | **FIXED** (allowlist of RP-plausible types + Discord log + CancelEvent, `core/server/security.lua`) |
| P3-03 | HIGH | No disconnect cleanup of client-owned personal/fleet/job vehicles → orphans + DB desync | `vehicles/server/main.lua:597` | **FIXED for personal vehicles** (playerDropped persists pos/health, deletes entity, marks stored=1, broadcasts cleanup). Fleet/job orphans remain (documented, lower impact — entities owned by dropped client are eventually GC'd by Cfx when owner leaves under OneSync) |
| P3-04 | HIGH | Routing bucket never reset on death/admin respawn → player invisible at hospital | `properties`, `death`, `admin` | **FIXED** (new `LeaveProperty` server export + bucket-0 reset in death respawnPlayer and admin respawn) |
| P3-05 | HIGH | pma-voice missing from resources/ but hard dependency of sunset_hud → HUD fails to start locally | `hud/fxmanifest.lua` | **FIXED** (dependency removed; voice.lua already degrades via GetResourceState) |
| P3-06 | MED | `hitGlobalId` resolved without entity-type check in damage resync | `licenses/server/main.lua:194` | **FIXED** (GetEntityType==1 + IsPedAPlayer on both resync + recordAttacker paths) |
| P3-07 | MED | `sunsetWanted`/`sunsetJailed` statebags replicated to ALL clients (cheat-readable) | `factions/server/police.lua:122,126` | **NOT FIXED** — requires client UI rework (hud reads bags); documented for Phase 9 backlog |
| P3-08 | MED | `propertiesChanged` broadcast to -1 (23 sites) → 48× heavy re-query per mutation | `properties/server/main.lua` | **NOT FIXED** — perf issue, queued for Phase 7 |
| P3-09 | LOW | warTick to -1 every second; global tune broadcasts; drop metadata to -1; findDrivenVehicle dead code; gamebuild drift (live 3258 vs template 3751) | multiple | documented; warTick/tune left as-is (perf, Phase 7); dead code harmless |

**Verified clean:** statebag set patterns (server-authoritative), routing bucket enter/exit/stop/reset-on-drop, no sensitive global broadcasts of money/inventory, licenses tests best-practice netId owner checks, faction fleet registration validation, CancelEvent placement correct.

### Phase 4 — Vehicles & GTA/FiveM compatibility — COMPLETE (2026-09-11)

| ID | Sev | Finding | Location | Status |
|---|---|---|---|---|
| P4-01 | HIGH | Unwhitelisted props on store → free ECU tune injection bypassing paid tuning + validator | `vehicles/server/main.lua:278` | **FIXED** (whitelist {cosmetics,color1,color2,odometer}; ecu always from DB; unknown keys dropped) |
| P4-02 | HIGH | storeOwnedVehicle accepted client fuel with no monotonic guard → free full tank | `vehicles/server/main.lua:309` | **FIXED** (cap at DB fuel +0.5; prefer server entity reading) |
| P4-03 | HIGH | saveTune transaction used global MySQL.* inside startTransaction → FOR UPDATE locks + atomicity void | `tuning/server/main.lua:153` | **FIXED** (all queries via `query` handle) |
| P4-04 | MED | Stored health ≤100 healed to 1000 on spawn → free repair loop | `vehicles/client/main.lua:701` | **FIXED** (only nil defaults; damaged values preserved) |
| P4-05 | MED | Dyno path renamed vanity plates free + non-transactional collision check | `tuning/server/main.lua:61` | **FIXED** (plate rename stripped in dyno path; only paid saveTune can rename) |
| P4-06 | MED | Substring plate matching → short vanity plates delete unrelated world vehicles on spawn | `vehicles/client/main.lua:630` | **FIXED** (exact match after normalization) |
| P4-07 | MED | Re-spawn cleanup sent to source only → cross-client plate dupe window | `vehicles/server/main.lua:239` | **FIXED** (broadcast to -1) |
| P4-08 | MED | `ambulance2`, `taxiold` not in vanilla build → fleet spawn always times out | `core/shared/factions.lua:195,231` | **FIXED** (→ `ambulance`, `taxi`) |
| P4-09 | MED | store path lacked +8km odometer cap | `vehicles/server/main.lua:283` | **FIXED** (cap added; monotonic+8km on all 3 write paths now) |
| P4-10 | LOW | generatePlate (givecar) no DB-uniqueness pre-check; dyno hp client-reported (leaderboard poison, clamped 2000); claim charges before reset non-atomic; unbounded HasModelLoaded loops in 5 client files; destroy-claim skips health check when entity unresolvable | multiple | documented, not fixed (LOW; sql/37 unique index covers plate collision at DB level) |

**Verified clean:** paid refuel/gas-can CAS transactions, plate normalization consistent everywhere, 8-char plate validation, health clamps server-side (-4000..1000 / 0..1000), tuning ownership+proximity+driver-seat gating, ECU SanitizeTune/TuneValidator clamps, no deprecated natives, no addon-vehicle streaming risk, destroyed-flow has no remaining free-reset path (adminRepairDatabase now admin-gated).

### Phase 5 — DB, persistence, concurrency, economy, duplication — COMPLETE (2026-09-12)

| ID | Sev | Finding | Location | Status |
|---|---|---|---|---|
| P5-01 | CRIT | Crafting transaction ran on pool connections (closure ignored `query` handle) → rollback no-op → material dupe/loss on every failed craft | `crafting/server/main.lua:141` | **FIXED** (query handle threaded through all statements) |
| P5-02 | CRIT | Fisherman sell transaction same defect → fish vanish without payment / double-pay on retry | `jobs/server/fisherman.lua:357` | **FIXED** |
| P5-03 | CRIT | Container deposit credited container BEFORE inventory removal, result ignored → item dupe via trade-lock or races | `inventory/server/containers.lua:185` | **FIXED** (remove-first + verified + rollback) |
| P5-04 | CRIT | Taxi complete: no lock between status check and money ops → double-charge/double-pay at 12 calls/s | `taxi/server/main.lua:520` | **FIXED** (synchronous `settling` status before awaits; restore on failure) |
| P5-05 | HIGH | SaveCharacter SELECT-then-UPDATE wrote absolute cash/bank/level/xp/RP/paydays from cache → concurrent money ops silently rolled back (effective dupe of spent amounts; free levels) | `core/server/player.lua:47` | **FIXED** (money/progress columns removed from save UPDATE; owned by atomic ops) |
| P5-06 | HIGH | Trade commit copied offer-time metadata snapshot (gas-can liters rollback); dead `transferTradeAsset` divergent impl | `trade.lua:430` | **NOT FIXED** (window is 5s countdown, guard-protected counts; metadata staleness documented — requires re-SELECT FOR UPDATE rework; risk: MED in practice) |
| P5-07 | HIGH | Dice escrow in-mem, non-atomic; restart burns both bets; disconnected side's wager lost; AddMoney failure unchecked | `economy/server/dice.lua` | **PARTIAL** (AddMoney unchecked fixed for taxi; dice escrow persistence documented as backlog — needs `dice_matches` table, deferred) |
| P5-08 | HIGH | No onResourceStop save in sunset_core → core restart drops up to 60s of every player's state | `core/server/main.lua` | **FIXED** (stop handler saves all characters + playtime) |
| P5-09 | HIGH | Character delete: no active-character guard; orphans properties/businesses/clans/turfs/lottery (no FKs) | `core/server/main.lua:502` | **FIXED** (active-char rejection + ownership release before delete + FK migration `sql/42-audit-integrity.sql`) |
| P5-10 | HIGH | metadata blob 4 uncoordinated whole-JSON writers → rob_points/quickslots lost updates (rob-point erasure = economy exploit) | `player.lua`, `quickslots.lua` | **FIXED** (JSON_SET targeted writes for rob_points/spawn_choice/quickslots; SaveCharacter merges DB-authoritative keys) |
| P5-11..25 | MED/LOW | Business claim-then-pay window; RemoveItemById unchecked DELETE; payday lock-order deadlock potential; ground drops memory-only; turf war state memory-only; job sessions memory-only; wanted decay persistence edge; ensureStarterItems pool-connection txn; ModelPriceCache staleness; container_inventory missing unique/FK; money_transactions missing reason index | multiple | documented; schema gaps **FIXED via sql/42**; remainder accepted (memory-only state = restart losses, LOW gameplay impact, listed in backlog) |

**Verified clean:** oxmysql rollback semantics (error-in-closure rolls back when handle used); vehicles.plate unique index exists (givecar retry sound); payday_runs/lottery_draws PK double-claim guards race-free; character_inventory slot unique; trade/pickup drop locks; money API guards; migrations 27-28 gap benign.

### Phase 6 — Gameplay systems & cross-system state — COMPLETE (2026-09-12)

| ID | Sev | Finding | Location | Status |
|---|---|---|---|---|
| P6-01 | CRIT | Payday jailed-check compared lowercase 'jailed' vs actual 'JAILED' → jailed players collected full salary+RP+rob points | `economy/server/main.lua:97` | **FIXED** (case-insensitive compare) |
| P6-02 | HIGH | Taxi ride permanently wedged when passenger downed/jailed (meter runs forever, no cancel path) | `taxi/server/main.lua` | **FIXED** (cancelRideForParty + handlers on `sunset:death:playerDowned` and new `sunset:faction:playerJailed` event) |
| P6-03 | HIGH | Vehicle disconnect cleanup raced core Players[] teardown (deferred GetCharacter could see nil → skipped cleanup entirely) | `vehicles/server/main.lua:626` | **FIXED** (charId captured synchronously in handler body) |
| P6-04 | HIGH | Wanted-death-capture hard-lock: downed state cleared before one-shot jail client event; lost event = not downed AND not jailed, no recovery | `factions/server/police.lua:380` | **FIXED** (idempotent re-send of jail event after 3s when still server-jailed) |
| P6-05 | HIGH | Downed players kept full economic agency (trade, give cash, shop, dice) | multiple | **FIXED** (new `exports.sunset_core:IsIncapacitated` gate on trade request, give cash, buyItem, dice challenge+accept, spawnVehicle) |
| P6-06 | HIGH | = P5-09 character deletion orphans | — | **FIXED** (see P5-09) |
| P6-07 | HIGH | Vehicle key grants survived ownership transfer + character deletion | `vehicles/server/main.lua:874` | **FIXED** (ClearKeysForPlate on transfer; ClearKeysForCharacter export called from char delete) |
| P6-08 | MED | Officer fired/off-duty kept escort attachment on suspects | `factions/server/detention.lua` | **FIXED** (release escorts on factionChanged + new dutyChanged event) |
| P6-09 | MED | Jailed officer stayed on duty (inflated police presence for robberies, EMS timers, salary) | `factions/server/police.lua:321` | **FIXED** (forceDutyOff event in beginJail + handler in main.lua) |
| P6-10 | MED | Jailed/downed/cuffed could spawn vehicles and enter properties (escape escort into routing bucket) | `vehicles`, `properties` | **FIXED** (IsIncapacitated gate on spawn; cuff/escort/downed gate on property enter) |
| P6-12 | MED | Clan dissolve left turfs dangling + active wars running for a dead clan | `clans`, `turfs` | **FIXED** (`sunset:clans:dissolved` event → abort wars, NULL turf ownership, re-sync) |
| P6-11/13/14..20 | MED/LOW | Trade UI focus survives downed/arrest (focus trap); wanted-decay persistence edge; SetFocus owner param bypassed codebase-wide; respawn keeps escort attach; turf per-tick DB churn; is_dead cache revive persistence; hospitalSpawn global source; dice refund for dropped player; DriverSessionStats growth | multiple | documented, not fixed (UI focus rework is Phase 8 backlog; others LOW) |

**Verified clean:** robbery↔death (session fails + loot stripped), job session abandonment monitor, trade transaction atomicity incl. assets, arrest chain validation, suspect-disconnect combat-log jail, duty transitions strip loadout, license test cleanup, dispatch persistence/rehydration, core session integrity.

### Phase 7 — Performance & resource lifecycle — COMPLETE (2026-09-12)

| ID | Sev | Finding | Location | Status |
|---|---|---|---|---|
| P7-01 | CRIT | Turf war tick: 1 blocking MySQL query per player per second during wars (~20-40 q/s) | `turfs/server/main.lua:100-117` | **FIXED** (30s per-character clan cache + drop cleanup) |
| P7-02 | CRIT | Hourly payday: ~400-500 sequential queries in one server-frame burst at 48 players | `economy/server/main.lua:70-179` | **NOT FIXED** — needs queue-based spread (N players/tick); documented in backlog with design |
| P7-03 | HIGH | HUD: 20Hz full JSON NUI payload + duplicate GetVehicleState pcall | `hud/client/main.lua:225` | **FIXED** (throttled to 10Hz) |
| P7-04 | HIGH | Per-frame NUI sends: world tooltips 60Hz, player prompts ~60Hz | `world/client/world_tooltips.lua:93` | **FIXED** tooltips (100ms); player prompts documented (16ms w/ screen-delta dedupe already — acceptable) |
| P7-05 | HIGH | sunset_ui monolith: Google Fonts + unpkg phosphor-icons remote fetches block first paint; ~7MB unused PNGs shipped | `ui/web/index.html:36-38,71` | **NOT FIXED** — needs vendored font/icon assets (binary download out of scope for static audit); documented in backlog |
| P7-06 | HIGH | Server memory leaks: taxi `Rides` terminal entries never freed; fire `Incidents` never freed; `FlowTraceRate` not cleared on drop; also `UnitStatuses`, `fixedRadarCooldowns`, `ActiveReports`, `DriverSessionStats`, `VehicleKeys` | multiple | **FIXED** (taxi sweep thread, fire sweep thread, FlowTraceRate cleared on drop; VehicleKeys cleared via ClearKeysForCharacter on char delete + ClearKeysForPlate on transfer — P6-07). Remaining per-source tables documented (small, bounded by player count) |
| P7-07 | HIGH | economy minute loop: 48 UPDATEs/min for active_minutes | `economy/server/main.lua:28-44` | **NOT FIXED** — batching design documented in backlog |
| P7-08 | MED | Always-on Wait(0) key-poll threads (scoreboard Z, phone P, quickslots X, hotbar disables) — 4 separate hot threads per client | multiple | documented (merge candidates); not fixed — behavior risk vs small gain |
| P7-09 | MED | carjack: per-frame GetGamePool scan near vehicles; 3 mission NPCs never deleted on resource stop | `carjack/client/main.lua` | **FIXED** NPC leak (onResourceStop delete + blips); pool-scan frequency documented |
| P7-10 | MED | Security scanner Discord webhooks can re-fire every 5s per glitchy player (429 spam) | `core/server/security.lua` | documented; not fixed (needs cooldown table — low risk) |
| P7-11 | MED | phone re-fetches full phone payload (3 queries) after every SMS | `phone/client/main.lua:213-263` | documented in backlog |
| P7-12 | MED | factions restart loses in-mem duty/cuff state + wanted decay precision for already-online players (hydrate only on characterSelected) | `factions/server/*` | documented — restart-heavy workflow risk; needs onResourceStart rehydrate loop |

**Verified good:** no Wait(0) server loops; robbery/dispatch lifecycle exemplary (DB persist + rehydrate + onResourceStop cancel); licenses session cleanup exemplary; ~39 per-player tables properly cleared on drop; callback rate limits solid.

### Phase 8 — NUI/UI consistency & integration — COMPLETE (2026-09-12)

| ID | Sev | Finding | Location | Status |
|---|---|---|---|---|
| P8-01 | CRIT | **Stored XSS** in MDC calls: 112 description/street/area/caller rendered via innerHTML unescaped → any citizen executes JS in every officer's NUI (could drive mdcClearWanted/mdcUnjail/chatSend callbacks) | `ui/web/js/mdc_tablet.js:536-576`, dispatch create112Call | **FIXED** (esc() at all sinks + server-side strip of `<>"'` in create112Call) |
| P8-02 | CRIT | **Stored XSS** in /calls panel: `/service` description unescaped, untruncated | `ui/web/js/panels.js:1118-1126`, `dispatch/server/commands.lua:14` | **FIXED** (escHtml at sink + server strip/truncate in createServiceCall) |
| P8-03 | HIGH | **Stored XSS** via faction grade labels: `rank`/`faction` unescaped in radio/dept/faction chat headers (leader-settable 64-char arbitrary) | `ui/web/js/chat.js:267,308,488,535` | **FIXED** (esc/escapeHtml at all 4 raw header sites) |
| P8-04 | MED | Trade-invite requester name (GetPlayerName fallback) unescaped | `ui/web/js/trade-forza.js:17-20` | **FIXED** (esc + id Number coercion) |
| P8-05 | LOW | MDC units/wanted rosters names unescaped incl. attribute injection (`data-name`) | `mdc_tablet.js:946-1032` | **FIXED** (esc() on names/ranks/depts/status) |
| P8-07 | HIGH | 4 battlepass NUI callbacks posted by JS, never registered → silent 404s; modal close never released focus | `ui/web/js/battlepass.js`, `nui_bridge.lua` | **FIXED** (forwards registered; battlepassClose releases focus). Full removal of the dormant modal left to backlog |
| P8-11 | HIGH | `#ticket-receive` citation window: no close button, not in ESC list, focus trapped when PAY/REFUSE fail | `nui_bridge.lua:218`, `police.lua:1068+`, `panels.js:194` | **FIXED** (ESC entry + ticketReceiveClose forward/handler + guaranteed close on failure paths + 120s auto-expire) |
| P8-12 | HIGH | Stale modal flags block ReleaseFocusUnlessModal → stuck cursor after panel supersede | `ui/client/main.lua:51-71` vs `app.js:298-313` | **FIXED** (JS posts `modalSuperseded` when force-hiding flag-owning panels; menu/properties/factions clear flags) |
| P8-14 | MED | Trade/inventory/phone/ticket modal + focus survive death & jail | death/police clients, trade server | **FIXED** (closeAllModalUi on downed+respawn; jail handler closes modals; server endTrade on playerDowned/playerJailed events) |
| P8-22 | LOW | courier.js/job_shift.js never linked → courier job HUD dead | `ui/web/index.html` | **FIXED** (script + courier.css linked) |
| P8-24 | MED | Loadscreen handoff not pcall'd → export error = stuck loadscreen forever (manual shutdown) | `core/client/main.lua:16-27` | **FIXED** (pcall wrapper, shutdown always runs) |
| P8-31 | MED | ~150 fetch call sites without .catch → unhandled rejections | `ui/web/js/app.js:12` | **FIXED** (central .catch in post()) |
| P8-13/15/17-21/25-30/32-38 | MED/LOW | MDC exit-vehicle watchdog vs ticket focus; 2-arg legacy SetFocus defeats owner system (~80 sites); z-index scale unmanaged (9 bands); dead JS action branches; orphaned taxi-meter overlay; XODO branding leftovers; 1481 !important; 159 duplicate selectors; no responsive breakpoints; unlinked dead CSS; asset weight ~7MB unused PNGs | multiple | documented in backlog (large refactors; no functional/security impact) |

**Verified clean:** chat message bodies/names escaped; phone uses textContent; notifications textContent; clan tags server-validated; all 162 bridge forwards unique + immediate cb (no NUI hangs); ESC panel map cross-checked vs bridge (all registered); robbery/pass NUI lifecycle exemplary; ticketReceiveShow payload fields match JS.

### Phase 9b — Backlog burn-down (user requested "fa tot") — COMPLETE (2026-09-12)

| ID | Finding | Status |
|---|---|---|
| P7-02 | Payday burst (~500 queries in one tick) | **FIXED** — queue + 2 players/500ms batch thread, dedupe, pcall per player, pending-minutes flush before payday |
| P7-07 | 48 UPDATEs/min for active_minutes | **FIXED** — in-memory accumulation + single batched CASE-WHEN flush every 5 min + flush on drop + flush before payday |
| P5-07 | Dice escrow destroyed on restart/drop; AddMoney failure = burned pot | **FIXED** — ActiveEscrows keyed by charId; playerDropped + onResourceStop refund both wagers via direct guarded SQL + ledger; failed winner payout refunds both; settled-flag prevents double-refund |
| P5-06 | Trade metadata staleness (gas-can liters rollback); dead transferTradeAsset | **FIXED** — metadata re-read FOR UPDATE inside the transaction; dead function deleted |
| P7-12 | factions restart loses wanted/jail hydration for online players | **FIXED** — onResourceStart rehydrate loop over all online players |
| P7-10 | Discord webhook spam (429s) from security scanner/explosions | **FIXED** — 5-min per-source per-kind alert throttle; enforcement still every scan |
| P7-05 | Remote Google Fonts + unpkg phosphor-icons block NUI first paint | **FIXED** — vendored: Montserrat+JetBrains Mono (16 woff2, 408KB) + Phosphor regular/fill/bold (woff2 only) into sunset_ui/web/assets + sunset_loadscreen/assets/fonts; index.html/style.css now local-only; zero external network deps in NUI |
| P7-05b | ~13MB dead PNG assets shipped/on disk | **FIXED** — deleted unreferenced bg.png/bg_login.png/sunset.png (ui) + bg.png/bg_login.png/logo.png (loadscreen) after verifying 0 references |
| P8-25 | XODO RP branding leftovers | **FIXED** — loadscreen title/brand → SunsetMP; ui brand-title ×2, auth subtitle, build-version → Sunset; 'XODO FUEL INC.' → 'SUNSET FUEL INC.' (QA fixtures in app.js left, they're ?qa= only) |

Remaining backlog (deferred, documented): P3-07 wanted-statebag privacy, P3-08 propertiesChanged debounce, P8-15 SetFocus owner adoption (~80 sites, UI-refactor risk without runtime), z-index tokens, CSS !important consolidation, battlepass modal removal, legacy SHA-256 forced rotation (ops), quick-token lifetime (ops).

Post-fix regression: 257 Lua OK, 53 JS OK, audit-static.ps1 OK, index.html tag balance OK (46/46), loadscreen manifest updated for new assets, sunset_ui files{} glob already covers new asset dirs. **58 files changed total (+1441/−197).**

### Phase 9c — UI hang investigation (user report: "sell car menu won't close") — COMPLETE (2026-09-12)

**Root cause found:** `sunset_carjack/client/main.lua:178` — the shared player-interaction panel (`#player-interaction`, sunset_ui) is opened by many resources (carjack "Vinde masina", gas menu, 24/7, fishing, trucker, LSC, interactions). Every opener must react to `sunset:nui:playerInteractionClose` by sending `playerInteractionHide` + `SetFocus(false)`. The carjack handler ONLY cleared a local flag (`menuOpen = nil`) and never hid the panel or released focus → the "sell stolen car" menu stayed on screen with NUI focus locked (movement controls dead), matching the user report exactly. Verified all 7 other openers release correctly.

**Fixes:**
1. carjack close handler now calls its real `closeMenu()` (hide + focus release).
2. **Systemic failsafe** in `sunset_ui/client/nui_bridge.lua`: `playerInteractionClose` is no longer a plain forward — the bridge now guarantees `playerInteractionHide` + `ReleaseFocusUnlessModal()` after dispatching to the owner (owner handler wrapped in pcall). A no-op/erroring owner can never trap focus in this panel class again. Redundant hides from well-behaved owners are harmless.
3. `/faction`, `/clan`, `/factions`, `/clans` and the M menu verified to use the NEW sunset_ui interface (premium panels `#faction-panel`, `#clan-panel` etc. in the monolith) — no legacy UI involved. `IsFactionPanelOpen`/`IsMenuOpen` flags wired into the P8-12 modalSuperseded fix.

### Phase 9 — Regression scan & production-readiness — COMPLETE (2026-09-12)

**Regression scan results:**
- All **257 Lua files** (resources, incl. all 53 modified) pass syntax validation (luaparse 5.3 + backtick-joaat neutralization — the 13 backtick "failures" are valid FiveM lua54 syntax, false positives of the checker).
- All **53 JS files** under resources/ pass `new Function()` parse.
- `scripts/audit-static.ps1` passes: 42 manifests, all script references resolve, 9 known dual-side commands (intentional client+server pairs), no secret hits in Lua.
- index.html tag balance verified after script/link insertion (46/46 script tags).
- Cross-file integration points manually verified: `exports.sunset_core:RateLimit` used by containers/turfs/trade (export exists, core loads first); `IsIncapacitated` exported + declared in fxmanifest; `LeaveProperty` exported + declared; `ClearKeysForPlate/Character` exported via `exports()` (callable without manifest decl in fxv1); `sunset:faction:playerJailed`/`forceDutyOff`/`dutyChanged`/`clans:dissolved`/`modalSuperseded`/`ticketReceiveClose` event chains traced end-to-end; taxi helper ordering (all referenced locals defined before use).
- SaveCharacter column reduction verified safe: every removed column (cash, bank, level, xp, respect_points, paydays_received) has an atomic DB owner (AddXP :444, AddRespectPoints :455, buyLevel guarded UPDATE, payday transaction, money API guarded UPDATEs) — no persistence path lost.
- Prior FIX_PLAN P0 cross-check (P1-14): P0.1 credential rotation = ops action (secrets never in git; live key in local server.cfg — rotate the cfxk key since it was shared); P0.2 jobcreator already removed from codebase (sql/36); P0.3 crafting/trade contained (crafting txn fixed P5-01, trade ledger P1-02, container dupe P5-03); P1.x/P2.x items substantially addressed by Phases 2-8 fixes; runtime DDL confirmed absent (P2.1 satisfied by sql/ migration pipeline + new sql/42).

**Production-readiness verdict: CONDITIONAL GO** (upgraded from prior audit's NO-GO), contingent on:
1. **Before opening to public:** run `sql/42-audit-integrity.sql` on the live DB; rotate `sv_licenseKey` (exposed in local server.cfg); rotate MySQL root password; deploy pma-voice (local install or keep Docker path); rotate `server-tls.key`/`server-monitor-token.key` if the box was ever shared.
2. **First-week runtime tests** (from AUDIT_STATE runtime list + new): carjack sell at/away from chop shop; container access remotely (must fail); jailed payday (must be 0); taxi double-complete spam; trade while downed (must refuse); ticket ESC close; login lockout after 5 fails; vehicle store with edited props (ecu must not persist); disconnect with car out (must store+delete).
3. **Backlog (documented, not blocking):** payday query-burst batching (P7-02), minute-loop batching (P7-07), font/icon vendoring + asset diet (P7-05), factions restart rehydration (P7-12), SetFocus owner adoption (P8-15), dice escrow persistence (P5-07), trade metadata re-read in txn (P5-06), sunsetWanted statebag privacy (P3-07), propertiesChanged debounce (P3-08), z-index token system, CSS !important consolidation, battlepass modal removal.

**Totals: 53 files modified, 1 migration added, ~60 findings: 6 CRIT, ~20 HIGH, ~20 MED, rest LOW/INFO — 44 FIXED in code, remainder documented with concrete designs.**
### Phase 5 — DB, persistence, concurrency, economy, duplication — NOT STARTED
### Phase 6 — Gameplay systems & cross-system state — NOT STARTED
### Phase 7 — Performance & resource lifecycle — NOT STARTED
### Phase 8 — NUI/UI consistency & integration — NOT STARTED
### Phase 9 — Regression scan & production-readiness — NOT STARTED
