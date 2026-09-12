# RESOURCE_MAP — SunsetMP Architecture Baseline

**Generated:** 2026-09-12, from the completed 9-phase audit (`docs/audit/MASTER_AUDIT.md`).
**Status:** ACCURATE as of commit `2252885`. Re-verify with `scripts/audit-static.ps1` after structural changes.

## 1. Resource inventory (42 custom + 2 external)

| Resource | Role | Server files | Client files | NUI | Notes |
|---|---|---|---|---|---|
| **sunset_core** | Framework: players, chars, money, callbacks, security | main, player, money_log, security, callbacks, command_feedback, discord_logs | main, callbacks | — | Hosts the RPC bus for ALL resources |
| **sunset_ui** | Monolithic NUI (all panels) | — | main, nui_bridge | web/ (~13MB, 44 JS, 51 CSS) | 162+ forwarded NUI callbacks |
| sunset_loadscreen | Loading screen | — | — | static html | manual shutdown, handshake w/ core |
| sunset_auth | Accounts, login, quick tokens | main, password.js (Node scrypt) | main, accounts | via sunset_ui | |
| sunset_characters | Character select/create/delete | — | main | via sunset_ui | Server logic lives in core |
| sunset_spawn | Spawn flow | — | main | — | |
| sunset_player | Autosave loop (60s) | main | — | — | Tiny; could merge into core |
| sunset_world | Blips, zones, 24/7, elevators, NPCs | access | main, stores_247, business_npcs, world_tooltips, elevators, npc_lib, fib_interior, interaction | — | Uses optional ox_lib |
| sunset_hud | HUD NUI updates, voice UI | main | main, world, voice | via sunset_ui | 10Hz HUD payload |
| sunset_menu | M menu | — | main | via sunset_ui | |
| sunset_inventory | Items, hotbars, trade, drops, containers | main, quickslots, trade, containers | main, weapons, props, quickslots, containers | via sunset_ui | Owns `character_inventory`, `container_inventory` |
| sunset_economy | Payday, shops, ATM, dice, lottery | main, dice, lottery | main | via sunset_ui | Owns `payday_runs`, `lottery_*` |
| sunset_jobs | Trucker, garbage, courier, fisherman, mechanic | core, trucker, garbage, courier, fisherman, mechanic, main | core, trucker, trucker_npc, courier, garbage, fisherman, mechanic | via sunset_ui | Owns `job_progress`, `taxi_rides`-like session tables |
| sunset_taxi | Taxi company flows | main | main | via sunset_ui | Rides in-memory + `taxi_rides` log |
| sunset_factions | Police/EMS/faction duty, MDC, jail, wanted, detention, fleet | main, police, detention, ems, chat, leaders, faction_roster, friendlyfire, core, faction_labels | main, police, detention, ems, loadout, friendlyfire | via sunset_ui | LARGEST logic surface (69 callbacks) |
| sunset_clans | Clans, ranks, invites | main, display | main | via sunset_ui | Owns `clans`, `clan_members`, `clan_invites`, `clan_audit_log` |
| sunset_turfs | Turf wars | main | main | via sunset_ui | `turfs` table; wars in-memory |
| sunset_vehicles | Owned vehicles, garages, keys, fuel, insurance | main | main, fuel_pump | via sunset_ui | Owns `vehicles`; keys in-memory |
| sunset_tuning | ECU/cosmetics/dyno/LSC | main | main, apply, baseline, dyno, effects, cosmetics, lsc_menu, exhaust_ptfx | own ui_page | |
| sunset_dealership | Vehicle shop + test drives | main | main | via sunset_ui | Owns `dealership_vehicles`, `dealership_sales` |
| sunset_properties | Houses, rentals, interiors (routing buckets) | main | main | via sunset_ui | Owns `properties`, `property_rentals` |
| sunset_businesses | Player businesses, gas/24-7 revenue | main | main | via sunset_ui | Owns `player_businesses` |
| sunset_licenses | Weapon/driving licenses, exams, damage gating | main, tests | main, quiz, tests | via sunset_ui | Owns `licenses`, `lssi_exam_reviews`; hosts weaponDamageEvent |
| sunset_dispatch | 112/service calls | main, service_core, commands | main | via sunset_ui | Owns `service_calls`; DB-persisted + rehydrated |
| sunset_death | Downed/bleedout/respawn | main | main, damage_indicators | via sunset_ui | Downed state in-memory |
| sunset_admin | Admin levels, bans, commands, checkpoints | main, commands | main | via sunset_ui | Owns `admins`, `bans`, `admin_checkpoints`, `admin_stat_audit` |
| sunset_chat | Chat + command router | main, command_router, connect_motd | main | via sunset_ui | Fan-out to `ExecutePlayerCommand` exports |
| sunset_phone | Phone, SMS, contacts | main | main | via sunset_ui | Owns `phone_messages`, `phone_contacts` |
| sunset_robbery | Store robberies, loot, fence | main, loot, sessions, adapter | main, animations, nui | own ui_page | Server state machine — GOOD reference |
| sunset_crafting | Faction crafting stations | main | main | via sunset_ui | Optional ox_lib |
| sunset_carjack | Lockpick + chop shops | main | main | — | Interaction via sunset_ui panel |
| sunset_fishingshop | Fishing sales, Billy Ray | main | main | via sunset_ui | |
| sunset_pass | Battlepass/missions | main | main | own ui_page | Owns `character_pass_progress` |
| sunset_appearance | Face/ped editor | main | main, appearance_lib | via sunset_ui | |
| sunset_clothing | Clothing shops/wardrobe | main | main, wardrobe | via sunset_ui | @-includes appearance client files |
| sunset_emotes | Emote wheel | — | main | via sunset_ui | |
| sunset_interactions | Player G-menu, give cash | main | main | via sunset_ui | |
| sunset_documents | ID documents | main | main | via sunset_ui | |
| sunset_fire | Fire incidents (EMS/fire dept) | main | main | — | Incidents in-memory |
| sunset_scoreboard | Z scoreboard | main | main | via sunset_ui | |
| sunset_help | /help registry | main | main | via sunset_ui | |
| sunset_needs | Hunger/thirst decay | main | main | — | Server-authoritative |
| oxmysql | DB layer (external) | — | — | — | `MySQL.*` + `startTransaction(query)` |
| pma-voice | Voice (external; Docker-installed) | — | — | — | NOT in repo; hud dependency removed (audit P3-05) |

## 2. Load order (server.cfg)

loadscreen → oxmysql → core → ui → world → factions → clans → turfs → dispatch → crafting → auth → characters → appearance → spawn → player → inventory → economy → needs → death → vehicles → tuning → admin → properties → businesses → emotes → clothing → phone → interactions → taxi → fire → documents → licenses → jobs → carjack → fishingshop → robbery → pass → hud → dealership → scoreboard → chat → menu → help

**Critical ordering facts:**
- Every feature resource `@sunset_core/shared/*.lua` includes core config at load.
- Every resource registers callbacks INTO core (`exports.sunset_core:RegisterCallback`), so core must start first (it does).
- Soft circular runtime calls (guarded pcall/GetResourceState): core→properties (spawn), core→clans (display names), core→admin (IsAdmin), core→death/factions (IsIncapacitated).

## 3. Dependency graph (hard edges)

```
oxmysql ──> sunset_core ──> everything
sunset_ui ──> everything with panels (NUI host)
sunset_factions ──> core, ui, world, inventory, death, appearance
sunset_economy ──> core, inventory, ui, world, factions
sunset_jobs ──> core, ui, vehicles, factions (taxi duty sync)
sunset_vehicles ──> core, ui, tuning (ECU info), businesses (gas sales)
sunset_inventory ──> core, ui (+ licenses for weapon gate)
sunset_chat ──> core, ui, admin (shared config)
sunset_help ──> core, ui, admin, chat
sunset_clothing ──> core, ui, appearance (@include)
sunset_menu ──> core, ui, tuning (shared config)
sunset_turfs ──> core, ui, clans (@include shared ranks)
```

No declared manifest cycles. Runtime soft-cycles listed above are all pcall-guarded.

## 4. Database ownership map (canonical writer per table)

| Table | Owner (canonical writer) | Other writers (SHOULD BE ELIMINATED) |
|---|---|---|
| accounts, players | sunset_core (auth flow) | — |
| characters (cash/bank/level/xp/RP/paydays) | sunset_core money+progression API | economy payday (inside txn — acceptable), inventory trade (inside txn + ledger — acceptable), tuning (inside txn + ledger — acceptable), dealership (inside txn + ledger — acceptable) |
| characters (position/appearance/hunger/thirst/stress/metadata/job) | sunset_core SaveCharacter + targeted JSON_SET writers | factions duty flag (cache only) |
| character_inventory | sunset_inventory | crafting (txn), fisherman sell (txn), robbery loot (via inventory exports) |
| container_inventory | sunset_inventory/containers | — |
| money_transactions | sunset_core LogMoneyTransaction | direct INSERTs inside txns: tuning, fisherman, dealership, trade (all ledger-consistent) |
| vehicles | sunset_vehicles | trade (asset transfer in txn), tuning (props/plate in txn) |
| properties, property_rentals | sunset_properties | trade (asset transfer in txn), economy (rent at payday in txn) |
| player_businesses | sunset_businesses | trade (asset transfer in txn) |
| clans, clan_members, clan_invites | sunset_clans | core deleteCharacter (dissolve on char delete) |
| turfs | sunset_turfs | clans dissolve handler (NULL ownership) |
| payday_runs | sunset_economy | — |
| lottery_state, lottery_tickets, lottery_draws | sunset_economy/lottery | core deleteCharacter (ticket cleanup) |
| licenses, lssi_exam_reviews | sunset_licenses | — |
| service_calls | sunset_dispatch | — |
| wanted_records, jail_sentences | sunset_factions/police | — |
| admins, bans, admin_checkpoints | sunset_admin | — |
| auth_quick_tokens | sunset_auth | — |
| job_progress | sunset_jobs (+carjack lockpicking XP) | carjack writes job_progress directly — **violation, see DOMAIN_OWNERSHIP** |
| dealership_vehicles, dealership_sales | sunset_dealership | carjack READS dealership_vehicles for pricing (read-only OK) |
| taxi_rides | sunset_taxi | — |
| character_pass_progress | sunset_pass | — |
| phone_messages, phone_contacts | sunset_phone | — |

## 5. Client→server surface

- **1 bus event:** `sunset:server:triggerCallback` (name, requestId, ...) → ~290 registered callbacks, central rate limit (30/s global, 12/s per name, tighter `EXPENSIVE_CALLBACK_LIMITS` incl. auth=2/s).
- **~47 raw RegisterNetEvents** (server-side). Full classified table: `docs/audit/MASTER_AUDIT.md` Phase 2 Part B. All audited; exploitable ones fixed.
- **Command router:** `sunset:chat:runCommand` → permission gate → `ExecutePlayerCommand` fan-out (hardcoded resource list in `sunset_chat/server/command_router.lua:79-92`).
- **NUI:** JS `fetch` → `RegisterNUICallback` in sunset_ui bridge → client-local `sunset:nui:<name>` event → owning resource → `Sunset.AwaitCallback` → server. NUI never talks to the server directly.

## 6. Duplicated implementations (consolidation targets)

| Concept | Duplicate locations | Canonical target |
|---|---|---|
| normalizePlate | vehicles server+client, tuning server+client, fuel_pump | core shared util |
| escapeHtml | phone.js (strict), chat.js (looser), mdc_tablet.js, panels.js, trade-forza.js, player_interaction.js | one shared ui util module |
| Lockpick XP → job_progress | carjack/server writes job_progress directly | sunset_jobs progression API |
| Vehicle health clamps | vehicles store/sync/park/disconnect-cleanup (×4 inline) | shared helper |
| proximity checks | each resource rolls its own | core helper `Sunset.NearCoords(source, coords, dist)` |
| Money-in-transaction pattern | dealership, tuning, fisherman, trade each hand-roll ledger INSERT | core helper `Ledger.recordInTxn(query, charId, account, dir, amount, reason)` |

## 7. In-memory-only state registry (restart loses)

| State | Resource | Impact | Mitigation status |
|---|---|---|---|
| Vehicle keys | vehicles | grants lost | documented; persist later |
| Dice escrow (in-flight 1.8s) | economy | refunds on stop/drop | FIXED (P5-07) |
| Turf wars | turfs | war cancelled silently | accepted (cooldown prevents abuse) |
| Robbery sessions | robbery | session fails, loot stripped | by design (server cancels) |
| Taxi rides | taxi | ride cancelled | by design + sweeps |
| Downed state | death | player stands up | accepted (short-lived) |
| Detention/cuffs | factions | everyone uncuffed on restart | accepted (jail survives via DB) |
| Wanted decay precision | factions | ±60s | rehydration FIXED (P7-12) |
| Job sessions | jobs | shift progress lost | accepted |
| Fire incidents | fire | incidents gone + sweep | FIXED leak (P7-06) |
| Dispatch calls | dispatch | — | DB-persisted + rehydrated (reference implementation) |
