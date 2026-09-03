# EMS (Pillbox Medical)

## Overview

Emergency medical services use faction capabilities from `faction_core.lua` (`ems` archetype). Medical commands live in `sunset_factions` (`server/ems.lua`, `client/ems.lua`) and integrate with **downed state** in `sunset_death`.

## Downed state

When a player dies:

1. They enter a **downed** state (writhe animation) instead of instant hospital respawn.
2. Bleedout timer: 5 minutes (`Sunset.Death.bleedoutSeconds`).
3. After bleedout or `/respawn`, they are sent to Pillbox with a hospital bill.
4. On-duty EMS/LSFD within 500 m are notified.
5. On-duty LEO/EMS/LSFD receive **officer backup** alerts (`/backup`) with map blip via `sunset_dispatch`.

## Medical commands

All commands require **on duty** at Pillbox EMS (or LSFD for field stabilization). Distance checks apply unless you are an admin.

| Command | Perm | Range | Effect |
|---------|------|-------|--------|
| `/stabilize [id]` | `stabilize` (Trainee+) | 5 m | Slows bleedout on a downed patient |
| `/heal [id]` | `heal` (Paramedic+) | 5 m | Restore HP/armor (not for downed — stabilize first) |
| `/revive [id]` | `revive` (Paramedic+) | 4 m | Revive a downed player in place |

Omit `[id]` on `/heal` to treat yourself.

## Dispatch

| Command | Description |
|---------|-------------|
| `/service medic [message]` | Request medical assistance |
| `/accept medic [id]` | EMS accepts the call |
| `/cancel medic [id]` | Cancel an active call |

Completing a revive on a player with an active medic dispatch call auto-completes the dispatch entry.

## Ranks (medic faction)

| Grade | Perms |
|-------|-------|
| Trainee | stabilize |
| Paramedic+ | stabilize, heal, revive |
| Doctor+ | + invite |
| Chief Medical | + promote |

LSFD shares `stabilize`/`heal`; `revive` at Engineer rank and above.

## Resources

- `resources/[sunset]/sunset_factions/server/ems.lua` — callbacks, distance checks, activity logging
- `resources/[sunset]/sunset_death` — downed/bleedout state
- `resources/[sunset]/sunset_dispatch` — `/service medic` queue

## Exports

```lua
exports.sunset_death:IsPlayerDowned(source)
exports.sunset_death:StabilizePlayer(targetId)
exports.sunset_death:RevivePlayer(targetId)
```

Callbacks: `sunset:emsStabilize`, `sunset:emsHeal`, `sunset:emsRevive`

Events: `sunset:death:playerDowned`, `sunset:dispatch:serviceCommand`
