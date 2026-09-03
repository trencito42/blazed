# Fire (LS Fire Department)

## Overview

The LS Fire Department (`lsfd` faction) responds to vehicle fires via `sunset_fire`. Faction config (HQ, depot, grades) is in `sunset_core/shared/factions.lua`. Gameplay uses real extinguisher interaction — aim and spray at the fire, not a press-E prompt.

## Faction setup

- **Faction ID**: `lsfd`
- **Archetype**: `fire_rescue` (see `faction_core.lua`)
- **HQ**: Davis fire station — join/toggle duty at `[E]`
- **Fleet**: `firetruk` at depot marker
- **Society**: `lsfd`

## Incidents

The server spawns **vehicle fire** incidents at configured map points (max 3 active). On-duty firefighters receive:

- Blip/waypoint to the scene
- Burning vehicle entity with script fire
- Server-tracked `fireHealth` (100 by default)

### Extinguisher gameplay

1. Go on duty and respond to the incident (`/firecalls` lists active scenes).
2. Within 8 m of the fire, you receive a fire extinguisher (`WEAPON_FIREEXTINGUISHER`).
3. **Aim at the vehicle and shoot** the extinguisher — each tick reduces server-side fire health.
4. When fire health reaches 0, the incident completes and you earn payout ($350 default, 15% to society).

Anti-cheat: server validates distance on every extinguish tick.

## Dispatch

| Command | Description |
|---------|-------------|
| `/service fire [message]` | Civilian fire/emergency request |
| `/accept fire [id]` | LSFD accepts the dispatch call |
| `/firecalls` | List active auto-spawned incidents (on duty) |

Auto-spawned incidents broadcast directly to on-duty LSFD (no dispatch row). Player `/service fire` calls use the dispatch queue.

## Commands (shared with EMS)

LSFD field stabilization uses the same medical commands as EMS:

- `/stabilize [id]` — Probationary+
- `/heal [id]` — Firefighter+
- `/revive [id]` — Engineer+

See [EMS.md](./EMS.md) for details.

## Configuration

`resources/[sunset]/sunset_fire/shared/config.lua`:

- `incidentIntervalSec` — time between auto spawns (900 s)
- `extinguishRange` — max distance to spray (8 m)
- `extinguishRate` — health removed per tick (12)
- `spawnPoints` — incident locations

## Resources

- `resources/[sunset]/sunset_fire` — incident spawn, extinguisher sync, payouts
- `resources/[sunset]/sunset_dispatch` — `/service fire`
- `resources/[sunset]/sunset_factions` — duty, fleet, medical commands

## Callbacks

- `sunset:fireGetIncidents` — list active fires
- `sunset:fireExtinguish` — server-validated extinguish progress

Events: `sunset:fire:newIncident`, `sunset:fire:incidentEnded`, `sunset:faction:activityComplete`
