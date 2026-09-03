# Jobs — Current State & Roadmap

## Civilian Jobs (`sunset_jobs`)

| Job | Status | Salary | Notes |
|-----|--------|--------|-------|
| `unemployed` | Active | $0 | Default |
| `trucker` | **Stub** | $150/hr | Hire at Job Center — no routes |
| `fisherman` | **Stub** | $120/hr | Hire at Job Center — no minigame |

Hire via Job Center UI or admin `/setjob [id] [job] [grade]`.

## Faction Jobs (`sunset_factions`)

Factions are hired at HQ, not Job Center. See [FACTIONS.md](./FACTIONS.md).

| Faction | Gameplay depth |
|---------|----------------|
| LSPD | Wanted, arrest, detention, MDC — **substantial** |
| Taxi | Phone app + manual fare — **substantial** |
| EMS | Heal/revive only — **minimal** |
| LSFD | Heal/revive (rank-gated) — **minimal** |
| Mechanic | HQ repair + `/repairveh` — **basic** |
| Gangs | HQ sell/fence — **basic** |

## Planned (Not This Session)

### Trucker
- Pickup/delivery routes with cargo props
- Pay per distance + bonus
- Company depot at docks

### Garbage
- Route waypoints, bin props
- Society payout split

### Courier
- Package pickup timer
- Random delivery addresses

### Fire Department (beyond foundation)
- Hose/synced fire entities
- Callout dispatch from `/d` or phone
- Scene stabilization XP

## Admin Commands

```
/setjob [id|username] [civilian_job] [grade]
/setfaction [id|username] [faction] [grade]
/setfaction [id] none
/setleader [id] [faction]
/removeleader [id] [faction]
```
