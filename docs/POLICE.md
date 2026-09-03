# LSPD / Law Enforcement

Built on `sunset_factions` with `factionType = law_enforcement`. Extends commit `8b0fb04` wanted system.

## Requirements

- Faction: `police` (LSPD)
- **On duty** (`/duty` at MRPD)
- Rank permissions in `factions.lua` grades

## Detention Flow (State Machine)

```
FREE → CUFFED → [ESCORTED] → [IN_VEHICLE] → ARRESTED → JAILED
```

| State | Command | Server callback |
|-------|---------|-----------------|
| Cuff | `/cuff [id]` | `sunset:detentionCuff` |
| Uncuff | `/uncuff [id]` | `sunset:detentionUncuff` |
| Escort | `/escort [id]` or `/drag [id]` | `sunset:detentionEscort` |
| Put in car | `/putinveh [id]` | `sunset:detentionPutInVehicle` |
| Remove | `/takeout [id]` | `sunset:detentionTakeOut` |
| Frisk | `/frisk [id]` | `sunset:detentionFrisk` |

All enforcement actions validate **proximity** server-side.

## Wanted & Arrest

| Command | Description |
|---------|-------------|
| `/su [id] [reason]` | Set wanted (type `/su` for reason codes) |
| `/so [id]` | Summon suspect (range check) |
| `/wanted` | Chat list of active wanted |
| `/arrest [id]` | Jail restrained suspect (near officer or MRPD jail point) |

Reason codes: `speeding`, `reckless`, `assault`, `robbery`, `evading`, `murder`

## Citations & MDC

| Command | Description |
|---------|-------------|
| `/fine [id] [amount] [reason]` | Text citation |
| `/ticket` | Citation UI panel |
| `/mdc` | Mobile Data Terminal (wanted list UI) |

## Other

| Command | Description |
|---------|-------------|
| `/m [message]` | Megaphone (35m radius) |
| `/backup` | Alert all on-duty LEO with map blip |
| `/pdgarage` | Spawn patrol vehicle |
| `/pd` | Command help |

## Suspect Commands

| Command | Description |
|---------|-------------|
| `/handsup` or `X` | Toggle hands up animation |

## Jail

- Coordinates: Bolingbroke (`Sunset.Police.jailCoords`)
- Release: `Sunset.Police.releaseCoords`
- **Client timer only** — persistence planned for next session

## Files

- `sunset_core/shared/police.lua` — config
- `sunset_factions/server/police.lua` — wanted/arrest
- `sunset_factions/server/detention.lua` — cuff/escort
- `sunset_factions/client/police.lua` — commands
- `sunset_factions/client/detention.lua` — anims/escort
