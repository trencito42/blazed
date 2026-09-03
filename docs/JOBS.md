# Jobs — Current State

## Civilian Jobs (`sunset_jobs`)

| Job | Status | Salary | Commands |
|-----|--------|--------|----------|
| `unemployed` | Active | $0 | Default |
| `trucker` | **Complete** | $150/hr | `/work` — depot spawn, trailer route, delivery, return |
| `garbage` | **Complete** | $130/hr | `/work` — bin pickup, truck dump, depot unload |
| `courier` | **Complete** | $110/hr | `/work` — warehouse pickup, on-foot delivery loop |
| `fisherman` | **Complete** | $120/hr | `/work` — fishing minigame, sell at pier |
| `mechanic` | **Complete** | $140/hr | `/work` — on duty, `/service mechanic` dispatch hook, vehicle repair |

Hire at Job Center (City Hall) or admin `/setjob`. Hiring **Unemployed** at the Job Center quits your civilian job. `/quitjob` and the M menu **Quit civilian job** button use the same server path. Use `/jobs` for the NUI panel, `/jobhelp` for tips, `/skills` for per-job XP.

When hired, GPS is set to that job's work location. `/work` sets GPS to the next objective for each active shift.

### Job Core

- **States:** `IDLE` → `STARTING` → `ACTIVE` → `RETURNING` → `COMPLETED` / `FAILED` / `CANCELLED`
- **Server:** enforced state transitions, start/work coordinates, registered work-vehicle checks, authoritative payouts (`AddMoney`), and job XP in `job_progress` (`sql/09-jobs.sql`)
- **Resilience:** disconnect clears session; work vehicle destroy fails shift; configurable timeout per job
- **Config:** `sunset_core/shared/jobs_config.lua`

### Per-Job Loops

| Job | Flow |
|-----|------|
| Trucker | Docks depot → spawn Phantom + trailer → pickup → delivery → return truck |
| Garbage | Depot → trash truck → bin pickup (E) → carry bag → dump at truck rear → full → depot unload |
| Courier | Warehouse loading dock → carry package → deliver addresses → repeat |
| Fisherman | Fishing spots → minigame catch → sell at pier buyer |
| Mechanic | Go on duty → receive `/service mechanic` dispatch via `sunset_dispatch` → accept (E) → repair nearby vehicle |

### Garbage Collector

1. Start at **Garbage Depot** (`/work`) — spawns a trash truck and assigns a shuffled bin route.
2. Drive to the GPS bin marker, exit the truck, press **E** at the bin to pick up a trash bag.
3. Walk to the **rear of your truck** (orange marker), press **E** to dump the bag — you earn per-bin pay and XP.
4. Repeat until the truck is full (8 bags by default).
5. Drive to the **depot unload point** in your truck to finish the shift and collect the unload bonus.

Server validates bin proximity on pickup and truck-rear proximity on dump; failed checks show an error notification instead of silently stalling.

## Faction Jobs (`sunset_factions`)

Factions are hired at HQ, not Job Center. See [FACTIONS.md](./FACTIONS.md).

| Faction | Gameplay depth |
|---------|----------------|
| LSPD | Wanted, arrest, detention, MDC — **substantial** |
| Taxi | Phone app + manual fare — **substantial** |
| EMS | Heal/revive only — **minimal** |
| LSFD | Heal/revive (rank-gated) — **minimal** |
| Mechanic (faction) | HQ repair + `/repairveh` — **basic** (separate from civilian roadside mechanic) |
| Gangs | HQ sell/fence — **basic** |

## Fuel recovery

Buy a **gas can** at any 24/7 store. At a gas pump on foot, hold **E** to fill the can (paid by the liter). Use the can from inventory while standing next to your vehicle to pour fuel into the tank.

## Commands

```
/jobs              — Jobs NUI (skills, descriptions, start work)
/work [cancel]     — Start or cancel civilian work shift
/jobhelp           — Help for your current job
/skills            — Job skill levels (XP in job_progress)
/setjob [id] [job] — Admin: set civilian job
```

## Admin Commands

```
/setjob [id|username] [civilian_job] [grade]
/setfaction [id|username] [faction] [grade]
/setfaction [id] none
/setleader [id] [faction]
/removeleader [id] [faction]
```
