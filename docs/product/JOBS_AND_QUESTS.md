# JOBS_AND_QUESTS — Activity Catalog & Quest Chains

**Principle:** every activity has a loop richer than "drive to checkpoint", plus progression, risk, anti-farm, varied locations, server-authoritative rewards, and an economic purpose (faucet/sink/circulation).

## 1. Legal jobs

| Job | Loop (current → target) | Progression | Economic role | Status |
|---|---|---|---|---|
| **Trucker** | depot → load → route (multi-stop, varied) → deliver; trailer attach validated | job_progress XP → contract tiers (long-haul pays more, needs license) | faucet (salary+per-delivery) | ✅ reference vertical slice (port to session framework first) |
| **Fisherman** | buy bait → fishing spot → catch (chance by bait) → sell at 24/7 or Billy Ray | rod upgrades, skill levels, rarity tiers | faucet; fish value clamped server-side | ✅ working |
| **Courier** | accept package → deliver within time → chain of drops | speed/accuracy rating → premium packages | faucet + circulation (deliver player/business goods later) | ⚠️ courier.js now linked (P8-22); validate full loop |
| **Garbage** | route bins → collect → dump at depot | shift streaks | faucet; sink (city upkeep narrative) | ✅ working |
| **Mechanic** | respond to repair calls → fix player vehicles → charge | certification levels | circulation (player→player service) | ✅ working |
| **Taxi** | pick up passenger → metered fare → dropoff; tip | driver rating, company cut | circulation | ✅ working (double-charge fixed P5-04) |
| **Driving instructor** | run LSSI exams for players | — | sink (exam fees) | ✅ working |
| Delivery contracts / vehicle recovery / logistics | NOT BUILT | — | faucet+circulation | 🔜 post-Trucker, reuse session framework |
| Business employment | wage share via RecordSale | — | circulation | ✅ partial |
| Faction salary | duty-gated hourly | rank | faucet (taxed) | ✅ working |

## 2. Illegal activities

| Activity | Loop | Risk | Progression | Economic role | Status |
|---|---|---|---|---|---|
| **Store robbery** | scout → start (location whitelist) → hack/smash → loot → fence within timer; wanted stars on success | jail on death-capture, loot stripped on down, police response | rob_points; higher-tier stores | faucet (high, needs rebalance) | ✅ strong server state machine (reference) |
| **Carjack + chop** | find car → lockpick (skill%) → drive to chop → sell | chop proximity, 10s cooldown, owned/protected cars refused | lockpicking XP (job_progress) | faucet (NEEDS NERF — see audit economy review) | ✅ working (mint exploit fixed P2-01) |
| **Fencing contraband** | sell stolen loot (metadata-tagged) at fence offers that expire | offer expiry, fence location risk | — | faucet→sink conversion | ✅ working |
| Theft/smuggling/contraband production/black-market contracts/clan ops | NOT BUILT | — | contact reputation | — | 🔜 gated behind criminal contact quest |
| **Turf war** | clan attacks turf → capture timer → payout to owning clan | war loss, cooldown | clan reputation | faucet (passive, needs sink pairing) | ✅ working (query storm fixed P7-01) |
| High-risk dynamic events | NOT BUILT | — | — | faucet | 🔜 future |

## 3. Quest chains (unlock order — see RPG_PROGRESSION §2)

Each chain = ordered quests in `character_quests`; a quest completes on a server-validated condition and emits progress. Chains:

1. `onboarding` — tutorial, /help, first spawn, HUD/phone orientation → unlocks Job Center.
2. `first_job` — trial trucker or fisherman shift → unlocks full job board.
3. `driving` — LSSI theory + practical → license → rental → ownership.
4. `social` — add contact, send SMS, complete a player trade → rental eligibility.
5. `housing` — rent first house → home spawn + storage.
6. `faction` — apply at HQ, accepted by leader → faction salary/ranks.
7. `advanced_profession` — skill-tier gate (job_progress level) → premium contracts.
8. `criminal_contact` — CHOICE-driven (repeat shady sales / buy lockpick) → black market → robbery prep → staged robberies.
9. `clan_endgame` — level + invite → clan create/join → turf wars.

**Canonical quest service** (new `sunset_quests`, Phase 7): owns `character_quests`, exposes `StartQuest`, `CompleteObjective`, `IsComplete`, `GetProgress`; other resources emit `sunset:quest:progress(charId, key, amount)` and never write the table directly (DOMAIN_OWNERSHIP rule).

## 4. Anti-farming controls (required per activity)

- Per-session reward uniqueness (INVARIANT S2/M5).
- Cooldowns on repeatable faucets (carjack 10s, robbery location cooldown, dice max bet).
- Location variety (rotating depots/spots/targets) — no single camping spot.
- Diminishing returns on grind (e.g., Nth identical delivery in a row pays less) — target for job rebalance.
- Jail as the illegal sink (lost paydays + fines), not just a slap.
- Server-derived outcomes only (coords/entity/attach validated; never client "done").

## 5. Definition of "complete" for any activity (vertical-slice gate)

An activity is shippable only when it handles ALL of (from the brief): success, cancel, timeout, death, arrest, cuff, bucket change, vehicle exit, entity destruction, disconnect+reconnect, resource restart, server restart, duplicate/spam request, invalid client data, DB failure, missing dependency, two concurrent players, NUI closed unexpectedly — and never leaves anim/prop/vehicle/checkpoint/payment/inventory in a partial state. Track per-activity in REGRESSION_MATRIX.md.
