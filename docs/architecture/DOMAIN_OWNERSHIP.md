# DOMAIN_OWNERSHIP — Canonical Service Map

**Rule:** every important concept has exactly ONE canonical service. Other resources call its exports/callbacks; they never touch its tables or reimplement its logic. Violations are listed with a remediation plan.

## Canonical services

| Domain | Canonical service | Public API (exports/callbacks) | Tables owned |
|---|---|---|---|
| Identity & characters | **sunset_core** (auth handshake in sunset_auth) | `GetPlayer`, `GetCharacter`, `CompleteAuthentication`, char CRUD callbacks | accounts, players, characters |
| Money & ledger | **sunset_core** | `AddMoney`, `RemoveMoney`, `MoveMoney`, `TransferMoney`, `GetMoney`, `RefreshMoney`, `LogMoneyTransaction`, `GetMoneyHistory` | characters.cash/bank, money_transactions |
| Premium currency | **sunset_core** | `AddBlazePoints`, `SpendBlazePoints`, `RefreshBlazePoints` | accounts.premium_points |
| Progression (XP/RP/level) | **sunset_core** | `AddXP`, `AddRespectPoints`, `buyLevel` callback, `SetPersistentStat` | characters.level/xp/respect_points, (payday_runs written by economy inside its txn) |
| Inventory & item metadata | **sunset_inventory** | `AddItem`, `RemoveItem`, `HasItem`, `UseItem`, `SetItemMetadata`, `CountItem`, `GetInventory`, `ReloadInventory`, containers via callbacks | character_inventory, container_inventory |
| Jobs & job progression | **sunset_jobs** | `HireCivilianJob`, job session callbacks, `SunsetJobs_PayReward` (internal), `ExecutePlayerCommand` | job_progress |
| Factions & membership | **sunset_factions** | `IsOnDuty`, `GetDutyState`, `HasFactionPerm`, `IsFactionLeader`, `GetDetentionState`, `IsCuffed`, `IsJailed` | (faction membership lives on characters.job via core `SetFaction`) |
| Clans | **sunset_clans** | clan callbacks, `FormatDisplayName`, `sunset:clans:dissolved` event | clans, clan_members, clan_invites, clan_audit_log |
| Turfs | **sunset_turfs** | attack/sync callbacks; listens `sunset:clans:dissolved` | turfs |
| Wanted/surrender/jail | **sunset_factions** (police module) | `AddWantedCharge`, `GetWantedState`, jail via detention; events `sunset:faction:playerJailed`, `sunset:faction:forceDutyOff` | wanted_records, jail_sentences |
| Vehicles/keys/fuel | **sunset_vehicles** | spawn/store/park callbacks, `TransferVehicleOwnership`, `ClearKeysForPlate`, `ClearKeysForCharacter`, `EnrichVehicleRow` | vehicles |
| Properties & rentals | **sunset_properties** | `ResolveSpawnChoice`, `LeaveProperty`, `ProcessRentPayday`, property callbacks | properties, property_rentals |
| Businesses & economy sinks | **sunset_businesses** | `RecordSale`, `RecordSaleAtCoords`, `GetOwnedBusinesses`, buy/withdraw callbacks | player_businesses |
| Licenses | **sunset_licenses** | `HasLicense`, `GrantLicense`, exam callbacks; hosts weaponDamageEvent gate | licenses, lssi_exam_reviews |
| Dispatch & emergency calls | **sunset_dispatch** | `CreateCall`, `CancelCall`, `CompleteCall`, `GetPlayerActiveCall` (rehydrates from DB — reference implementation) | service_calls |
| Death/downed state | **sunset_death** | `IsPlayerDowned`, `RevivePlayer`, `RespawnPlayer`, `ClearDownedForCustody`; events `sunset:death:playerDowned`, `sunset:death:recordAttacker` | (none — transient by design) |
| Gameplay sessions | **per-system today; target: shared framework (see GAMEPLAY_SESSIONS.md)** | robbery = good reference; jobs/taxi/dice/turfs = ad-hoc | robbery none (in-mem), taxi_rides log |
| UI focus & modals | **sunset_ui** | `Show`, `Hide`, `Send`, `SetFocus(hasFocus, hasCursor, keepInput, owner)`, `GetFocusOwner`, `ReleaseFocusUnlessModal`, `Notify`, `ProgressBar`; bridge events `sunset:nui:*`, `sunset:nui:modalSuperseded` | (hud layout JSON via SaveResourceFile, admin-gated) |
| Admin & permissions | **sunset_admin** | `IsAdmin(src, level)`, `GetAdminLevel`, ban enforcement at connect | admins, bans, admin_checkpoints, admin_stat_audit |
| Chat & command routing | **sunset_chat** | `sunset:chat:runCommand` → router → `ExecutePlayerCommand` exports | — |
| Phone | **sunset_phone** | send/contact callbacks | phone_messages, phone_contacts |
| Payday & taxes | **sunset_economy** | internal `processPayday` (queued, batched); event `sunset:payday:processed` | payday_runs |
| Security/anti-cheat | **sunset_core/security** | `Sunset.Security.RateLimit` (exported as `RateLimit`), weapon strip, teleport flag, explosionEvent gate | — |

## Known ownership violations (remediation backlog)

1. **carjack → job_progress** (`sunset_carjack/server/main.lua` getLockpickLevel/addLockpickXP): writes `job_progress` directly with its own level curve.
   *Remediation:* add `exports.sunset_jobs:AddJobProgress(source, 'lockpicking', xp, tasks, earned)` (already exists for fisherman) and delete the local SQL. LOW risk, do in Phase 3 repairs.
2. **Direct `characters.cash/bank` writes inside feature transactions** (trade, tuning, dealership, fisherman): pattern is ledger-consistent and atomic INSIDE each transaction, but bypasses the core cache until `RefreshMoney` is called (all 4 call sites do).
   *Remediation:* extract `Sunset.Ledger.DebitInTxn(query, charId, account, amount, reason)` helper in core so the guard+ledger pattern is written once. Accepted interim state.
3. **carjack reads dealership_vehicles for pricing**: read-only cross-domain lookup. Acceptable, but price logic should move to a shared config or dealership export. LOW.
4. **factions duty flag writes `char.metadata.on_duty` cache only** (never persisted intentionally — duty is session state). OK as-is; documented so SaveCharacter doesn't "fix" it.
5. **economy payday writes rob_points into metadata inside its txn** while core `SetRobPoints` uses JSON_SET: both are now DB-authoritative and SaveCharacter merges `rob_points` from DB before writing (P5-10 fix) — consistent. No action.

## Cross-domain event contracts (server-internal TriggerEvent)

| Event | Producer | Consumers | Purpose |
|---|---|---|---|
| `sunset:death:playerDowned` | death | factions (death-capture), taxi (cancel rides), robbery (fail session), inventory (end trades), turfs | incapacitation broadcast |
| `sunset:death:recordAttacker` | licenses (weaponDamageEvent) | death, turfs | server-side kill attribution |
| `sunset:faction:playerJailed` | factions/police beginJail | taxi, inventory | jail intake broadcast |
| `sunset:faction:forceDutyOff` | factions/police | factions/main | break load-order cycle for setDuty |
| `sunset:server:dutyChanged` | factions/main setDuty | factions/detention (escort release) | duty transitions |
| `sunset:server:factionChanged` | core SetFaction | factions main+detention | membership transitions |
| `sunset:clans:dissolved` | clans | turfs | release turfs + abort wars |
| `sunset:server:characterSelected` | core | police (hydrate), jobs, factions, many | character lifecycle |
| `sunset:payday:processed` | economy | turfs (payout hook) | economy tick |
| `sunset:nui:modalSuperseded` | sunset_ui bridge (from JS) | menu, properties, factions | clear stale open-flags |
| `sunset:ui:ticketReceive` etc. | various servers | nui_bridge | UI open commands |

## Dependency rules (enforced by review, target: by lint)

- Feature resources may depend on: core, ui, (declared peers in fxmanifest).
- Core may call feature exports ONLY via `GetResourceState` + `pcall` (current state, keep).
- No resource may query another domain's tables except: read-only pricing lookups (documented) and inside multi-domain settlement transactions owned by the initiator (trade) — every such write must appear in RESOURCE_MAP §4 "Other writers" or be refactored.
- New tables require: owning resource declared here + migration in sql/ + FK to characters/clans where applicable.
