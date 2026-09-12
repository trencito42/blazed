# RPG_PROGRESSION — Product Direction (B-Zone/buGGed-inspired, FiveM-native)

**Design north star:** a player who logs in daily for a month should have a visibly different character than day one — money, level, reputation, assets, unlocks — earned through varied loops, not grinded from one command.

## 1. Core progression pillars (what already exists → what to strengthen)

| Pillar | Current state | Target |
|---|---|---|
| Persistent identity | ✅ accounts/characters, scrypt auth, multi-slot | keep; add per-character stats page depth |
| Hourly payday | ✅ salary (job+faction) − tax − vehicle/property upkeep; requires 20 active min; jailed/dead excluded | keep; make salary scale with level modestly |
| RP/level | ✅ respect_points per payday + activities; `/buylevel` costs RP + money | add visible level benefits (unlocks, caps) — see §3 |
| XP/skills | ✅ job_progress XP per profession (trucker/fisherman/lockpicking...) | surface in /stats; skill tiers gate contracts |
| Money paths | ✅ legal jobs, illegal (robbery/carjack/fence), dice/lottery | rebalance (see ECONOMY notes in audit); add smuggling/contracts |
| Assets | ✅ vehicles+insurance, houses+rentals, businesses | asset tiers as progression milestones |
| Social rank | ✅ factions (ranks, leader, salary, perms), clans (ranks, turfs) | faction reports/evaluations; clan reputation |
| Licenses | ✅ driving/weapon exams, LSSI reviews | measure license tenure in payday-hours (B-Zone style): some licenses require N paydays of clean history |

## 2. Gating philosophy: unlock chains, not command soup

Nothing beyond basic orientation is available at character creation. Quest chains (see JOBS_AND_QUESTS.md) introduce systems in order:

1. **Tutorial/city orientation** (walkthrough: HUD, phone, /help, M menu, spawn basics) → unlocks Job Center access.
2. **First legal job** (trucker or fisherman trial shift) → unlocks full job list + first paycheck.
3. **Driving school** (LSSI theory + practical, already implemented) → unlocks driving license → vehicle rental → ownership.
4. **Social** (add contact, phone SMS, player trade) → unlocks property rental application.
5. **Property** (rent a house; later buy) → unlocks home spawn + storage.
6. **Faction application** (apply at HQ; leader approval) → unlocks faction salary/ranks; leaving NEVER removes civilian job (invariant).
7. **Advanced professions** (skill-tiered: master trucker contracts, mechanic certification) → premium payouts.
8. **Criminal contacts** — introduced by CHOICE, not command: e.g., selling excess scrap to a shady NPC repeatedly flags you; a lockpick can be bought only after black-market contact quest. Robbery prep (scouting → tools → job) gated behind contact reputation.
9. **Clan/turf endgame** — requires level + invitation; turf wars are the clan progression loop.

Implementation note: a lightweight `character_quests` table (charId, questKey, stage, progress JSON, completedAt) owned by a new `sunset_quests` canonical service; existing systems emit progress events (`sunset:quest:progress`, charId, key, amount) — fisherman already has AddMissionProgress in sunset_pass as a pattern.

## 3. Level benefits (make levels MEAN something)

| Level band | Unlocks |
|---|---|
| 1-4 | starter jobs, rental, basic shops |
| 5-9 | driving license eligible, property rental, taxi employment |
| 10-14 | vehicle purchase (dealership tier 2), faction applications, business employment |
| 15-19 | property purchase, advanced contracts, weapon license eligibility (plus clean-history paydays) |
| 20+ | business ownership, clan creation, dealership tier 3, faction leadership eligibility |

(Exact numbers to be tuned with the economy rebalance; principle: purchases gated by level + money, crimes gated by contacts + risk, rank gated by time + reputation.)

## 4. Legal vs illegal balance contract

- Legal work: steady, safe, scales with SKILL (job_progress tiers) and TIME (payday history). Ceiling: comfortable, not rich.
- Illegal work: bursty, risky (wanted stars, jail time = lost paydays, loot loss on death-capture, fence price volatility), scales with REPUTATION (rob points/contacts). Ceiling: rich but taxed by risk — jail time is the sink (opportunity cost + fines).
- Design rule from the audit economy review: current robbery/carjack payouts are 20-50x legal hourly — MUST be rebanced before quest-gating, otherwise gating is cosmetic (players rush the crime chain).

## 5. Long-term retention hooks

- **Achievements/reputation** (per-activity lifetime stats already in job_progress; surface them): "Master Trucker", "Clean Record" (N paydays unjailed), "Property Mogul".
- **Seasonal**: Sunset Pass (exists) as the seasonal layer.
- **Player-driven economy**: businesses employ players (wage share exists via RecordSale revenue), rentals create landlord income — money circulates between players, not just faucet→sink.
- **Legacy markers**: rare dealership stock, plate customization (paid vanity), house decorations (future).

## 6. What we explicitly do NOT do

- No pay-to-win (Blaze Points stay cosmetic/pass/convenience).
- No instant-max: starting cash stays modest ($250) and level gates stay.
- No disconnected script feel: every system must appear in /help registry (exists) and be reachable through the quest chain or world markers, not secret commands.
- No client-trusted progression: all XP/RP/level mutations server-side through core API (invariant M6/C8).
