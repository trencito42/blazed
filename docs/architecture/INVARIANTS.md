# INVARIANTS — Hard Framework Rules

An invariant is a property that must hold at ALL times. Each has: enforcement mechanism (code/DB), verification method, and status.

**Legend:** ✅ enforced+verified by audit · 🛡️ enforced by DB constraint · 🧪 needs runtime test · ⚠️ partially enforced (gap documented)

## Money

| # | Invariant | Enforcement | Status |
|---|---|---|---|
| M1 | Balance never negative | guarded SQL `WHERE cash/bank >= ?` in every core path (player.lua:185-320); trade/tuning/dealership use same guard inside txns | ✅ |
| M2 | Every mutation has a ledger row | core `LogMoneyTransaction`; direct-txn writers (trade, tuning, dealership, fisherman) INSERT into money_transactions in-txn | ✅ |
| M3 | No mutation path bypasses the money API except inside an atomic transaction that also writes the ledger | audit P1-02/P5 fixes | ✅ |
| M4 | Negative/zero amounts rejected at every entry | all callbacks `math.floor(tonumber(x) or 0)`, reject `<1`; core rejects `<=0` | ✅ (audit: "negative-amount inversion impossible") |
| M5 | A repeated request must not repeat its reward | buyLevel re-entrancy lock; payday_runs PK (character_id, period_key); lottery FOR UPDATE; taxi `settling` status; carjack 10s cooldown | ✅🛡️ |
| M6 | Concurrent money ops never lost-update | SaveCharacter no longer writes cash/bank/level/xp/RP/paydays (P5-05); owners use atomic `col = col + ?` or guarded single-statement UPDATE | ✅ |
| M7 | Escrowed money is never destroyed | dice refunds on drop/restart/payout-failure (P5-07) | ✅🧪 |

## Inventory & items

| # | Invariant | Enforcement | Status |
|---|---|---|---|
| I1 | An item exists in exactly one place (inventory XOR container XOR drop) | deposit: remove-first + verified + rollback (P5-03); withdraw: container-first + rollback; trade: single txn moves rows; drops: RemoveItemById commits before drop creation | ✅ |
| I2 | Slot uniqueness per character | `UNIQUE (character_id, slot)` (sql/37) | 🛡️ |
| I3 | Container row uniqueness | `uk_container_item` (sql/42) | 🛡️ |
| I4 | Metadata survives trade/storage/drop/craft | trade re-reads metadata FOR UPDATE in txn (P5-06); containers pass metadata both ways (P5-12) | ✅🧪 |
| I5 | Count guards on every decrement | `count >= ?` in UPDATE, `changed ~= 1` aborts | ✅ |
| I6 | Weapon items require license on receive | trade receiver gate + AddItem gate via licenses export | ✅ |
| I7 | Client cannot inject item value via metadata | fish value clamped to FISH_PRICES max (P2-09); robbery loot values server-generated | ✅ |

## Characters & progression

| # | Invariant | Enforcement | Status |
|---|---|---|---|
| C1 | A character belongs to exactly one player; loads only via ownership-verified path | `WHERE id=? AND player_id=?`; never accepts client char objects | ✅ |
| C2 | One authenticated session per account | CompleteAuthentication drops old sources for same account (saves char first) | ✅ |
| C3 | Session cannot be reset by client replay | playerLoaded ignores replays when authenticated (P2-03) | ✅ |
| C4 | Stale character data is saved before replacement | completeAuthentication stale-save; playerDropped save; onResourceStop save (P5-08) | ✅ |
| C5 | Active character cannot be deleted | deleteCharacter guard (P5-09) | ✅ |
| C6 | Character deletion never orphans assets | pre-delete release of properties/businesses/clans/turfs/lottery + FKs (sql/42) | ✅🛡️ |
| C7 | metadata keys have DB-authoritative merge | rob_points/quickslots merged from DB in SaveCharacter; writers use JSON_SET (P5-10) | ✅ |
| C8 | Level purchase atomic: RP+money+level change together or not at all | buyLevel single conditional UPDATE with re-entrancy lock | ✅ |
| C9 | Jailed/dead characters collect no payday | detained check, case-insensitive (P6-01) | ✅🧪 |

## Vehicles

| # | Invariant | Enforcement | Status |
|---|---|---|---|
| V1 | Exactly one authoritative owner row per vehicle | `vehicles.character_id` + plate UNIQUE index (sql/02) | 🛡️ |
| V2 | One spawned entity per plate at a time | outPlates cleanup broadcast to -1 on spawn (P4-07); store/park delete entity; disconnect cleanup (F7.2/P6-03) | ✅🧪 |
| C3v | Plate matching is exact | normalizePlate + exact compare client & server (P4-06) | ✅ |
| V4 | Client cannot inflate persisted vehicle state | props whitelist {cosmetics,color1,color2,odometer}; ecu DB-only; fuel monotonic +0.5; odometer monotonic +8km; health read server-side (P4-01/02/09) | ✅ |
| V5 | Destroyed vehicles: no free reset path | adminRepairDatabase admin-gated (P1-01); claim charges in correct order; store cannot clear destroyed | ✅ |
| V6 | Key grants die with ownership | ClearKeysForPlate on transfer, ClearKeysForCharacter on delete (P6-07) | ✅ |
| V7 | Chop-shop pays only for a real, driven, non-owned, non-protected vehicle, once per cooldown | carjack sell full validation (P2-01) | ✅🧪 |

## Sessions & gameplay state

| # | Invariant | Enforcement | Status |
|---|---|---|---|
| S1 | Only the server transitions session state | robbery state machine (reference); taxi statuses server-set; dice server-rolled | ✅ |
| S2 | Reward granted at most once per session | robbery loot uid + lootBusy; payday_runs; taxi settling; fisherman SellLocks | ✅ |
| S3 | Entity loss cancels or recovers the session cleanly | jobs abandonment monitor (60s); robbery session fail on down/drop; taxi cancel on downed/jailed (P6-02) | ✅🧪 |
| S4 | Incapacitated players have no economic agency | IsIncapacitated gates: trade, give cash, shop, dice, spawnVehicle (P6-05) | ✅🧪 |
| S5 | Kill attribution is server-derived | playerKilled requires LastPvPAttacker match from weaponDamageEvent (P2-07) | ✅ |
| S6 | Death cannot be faked | playerDied/enteredDowned verify ped health server-side (P2-07) | ✅ |
| S7 | No player is left frozen/invisible/stuck after any transition | routing-bucket reset on respawn/jail/admin (P3-04); jail event re-send (P6-04); modalSuperseded + ticket failsafes (P8-11/12); playerInteractionClose failsafe (9c) | ✅🧪 |
| S8 | Resource restart leaves no stuck players | core onResourceStop save; properties bucket reset; robbery cancel; dispatch rehydrate; factions rehydrate (P7-12); dice refund | ✅ |

## Security & trust boundary

| # | Invariant | Enforcement | Status |
|---|---|---|---|
| X1 | No handler trusts a client-supplied source/target as acting identity | audit: source always event source; targets validated online+proximity | ✅ |
| X2 | No player-controlled string reaches innerHTML unescaped | esc/escHtml at all known sinks + server-side strip (P8-01..05) | ✅🧪 |
| X3 | Admin actions require DB-backed level checks; console-only where designed | requirePerm + IsAdmin re-checks; setadmin=5; setowner console | ✅ |
| X4 | Login resists brute force | 5-fail exponential lockout + 2/s callback limit (P2-04) | ✅🧪 |
| X5 | Rate limits on every client→server entry | bus 30/s + per-name; expensive list; Security.RateLimit on dumps | ✅ |
| X6 | Dangerous explosion/damage types gated (OneSync required) | explosionEvent allowlist (P3-02); weaponDamageEvent license gate | ✅ |
| X7 | No secrets in repo/git | gitignored server.cfg/.env/keys; history scanned clean; template uses env vars | ✅ |
| X8 | SQL injection impossible via client input | parameterized everywhere; dynamic fragments whitelisted; audit found no concatenation of client strings | ✅ |

## Database

| # | Invariant | Enforcement | Status |
|---|---|---|---|
| D1 | Multi-write operations are real transactions on the txn connection | all `MySQL.*` inside startTransaction replaced with `query.*` (P4-03, P5-01, P5-02) | ✅ |
| D2 | A failed transaction changes nothing | error-in-closure → oxmysql rollback (verified in dist/build.js) + query-handle usage | ✅ |
| D3 | Migrations ordered, recorded, re-runnable | apply-migrations.sh + schema_migrations checksums; sql/42 idempotent | ✅ |
| D4 | Ownership FKs prevent ghosts | fk_property_owner, fk_business_owner, fk_lottery_char, fk_turf_clan (sql/42, verified applied on VPS) | 🛡️ |
| D5 | No runtime DDL in resources | grep: zero CREATE/ALTER TABLE in Lua | ✅ |

## Automated verification hooks

- `scripts/audit-static.ps1`: manifest refs, dual-side commands, secret scan. **Run after every structural change.**
- luaparse / node --check sweeps (temp harness documented in `docs/audit/AUDIT_STATE.md`).
- Planned (`docs/testing/REGRESSION_MATRIX.md`): direct-DB-write detector outside whitelisted owners; callback registry completeness (JS fetch names vs bridge forwards); invariant SQL queries (negative balances, duplicate plates, orphan FKs) runnable against live DB.
