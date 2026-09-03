# LSPD / Law Enforcement

Built on `sunset_factions` with `factionType = law_enforcement`. Extends commit `8b0fb04` wanted system.

## Requirements

- Faction: `police` (LSPD)
- **On duty** (`/duty` at MRPD)
- Rank permissions in `factions.lua` grades

## Detention Flow (State Machine)

```
FREE → COMPLIANT → CUFFED → ESCORTED → IN_VEHICLE → JAILED
```

| State | Trigger | Server |
|-------|---------|--------|
| FREE | Default / uncuff / sentence complete | `sunsetDetention` state bag |
| COMPLIANT | `/handsup` or `X` | `sunset:server:handsUp` |
| CUFFED | `/cuff [id]` | `sunset:detentionCuff` |
| ESCORTED | `/escort [id]` or `/drag [id]` | `sunset:detentionEscort` |
| IN_VEHICLE | `/putinveh [id]` or cuffed ped enters vehicle | `sunset:detentionPutInVehicle` |
| JAILED | `/arrest [id]` at jail zone | `sunset:policeArrest` |

| Command | Server callback |
|---------|-----------------|
| Uncuff | `/uncuff [id]` | `sunset:detentionUncuff` |
| Remove from car | `/takeout [id]` | `sunset:detentionTakeOut` |
| Frisk | `/frisk [id]` | `sunset:detentionFrisk` |

All enforcement actions validate **proximity** and **law_enforcement capability** server-side.

## Wanted & Arrest

| Command | Description |
|---------|-------------|
| `/su [id] [reason]` | Set wanted (type `/su` for reason codes) — **persisted** |
| `/so [id]` | Summon suspect (range check) + NUI alert |
| `/wanted` | Chat list of active wanted (online + offline DB records) |
| `/clear [id]` | Clear wanted (Sergeant+) — **persisted** |
| `/arrest [id]` | Jail restrained suspect at MRPD/Bolingbroke booking zone |

Reason codes: `speeding`, `reckless`, `assault`, `robbery`, `evading`, `murder`

## Citations & MDC

| Command | Description |
|---------|-------------|
| `/fine [id] [amount] [reason]` | Text citation |
| `/ticket` | Citation UI panel (violations from `Sunset.Police.violations`) |
| `/mdc` | Mobile Data Terminal (persisted wanted list UI) |
| `/confiscate [id]` | Remove configured contraband items |

## Radar

| Command | Description |
|---------|-------------|
| `/startradar` | Activate mobile speed radar (forward cone) |
| `/stopradar` | Deactivate mobile radar |
| `/radars` | List fixed speed camera locations |

## Other

| Command | Description |
|---------|-------------|
| `/m [message]` | Megaphone (35m radius) |
| `/backup` | Alert all on-duty LEO, EMS, and LSFD with map blip via `sunset_dispatch` |
| `/cbackup` | Cancel active backup request and remove responder blips |
| `/pdgarage` | Spawn patrol vehicle |
| `/pd` | Command help |

## Suspect Commands

| Command | Description |
|---------|-------------|
| `/handsup` or `X` | Toggle hands up animation (COMPLIANT state) |

## Jail

- Coordinates: Bolingbroke (`Sunset.Police.jailCoords`)
- Booking zones: MRPD (`Sunset.Police.pdJailPoint`) or Bolingbroke intake
- Release: `Sunset.Police.releaseCoords`
- **Persisted** in `character_jail` — disconnect/reconnect serves remaining time
- Arrest bounty paid to officer bank from `Sunset.Police.bounties`

## State Bags

| Bag | Scope | Purpose |
|-----|-------|---------|
| `sunsetWanted` | Player | `{ level, reason, reasonCode, decayAt }` |
| `sunsetJailed` | Player | `{ releaseAt, minutes }` |
| `sunsetDetention` | Player | `FREE` / `COMPLIANT` / `CUFFED` / `ESCORTED` / `IN_VEHICLE` / `JAILED` |
| `sunsetCuffed` | Player | boolean |

`sunset_hud` reads `sunsetWanted` for wanted stars on reconnect.

## Files

- `sunset_core/shared/police.lua` — config (reasons, violations, radar, confiscatable)
- `sunset_factions/server/police.lua` — wanted/arrest/jail persistence
- `sunset_factions/server/detention.lua` — cuff/escort state machine
- `sunset_factions/client/police.lua` — commands, radar, jail client
- `sunset_factions/client/detention.lua` — anims/escort
- `sql/09-dispatch-wanted-jail.sql` — `wanted_records`, `jail_sentences` (integration owner)
- `sql/10-police-persist.sql` — `police_confiscations`

## Implementation Status

| Feature | Status |
|---------|--------|
| Wanted persistence (`wanted_records` from sql/09) | Done |
| Jail persistence (`jail_sentences` from sql/09) | Done |
| Reconnect jail / wanted hydration | Done |
| State bags (wanted, jail, detention) | Done |
| Detention state machine | Done |
| `/so` NUI summon alert event | Done (`summonAlert` — UI agent can style) |
| `/clear`, `/confiscate`, radar commands | Done |
| Ticket violations config | Done (`Sunset.Police.violations`) |
| MDC offline wanted records | Done |
| Arrest: cuffed + jail zone + bounty | Done |
| `sunset_hud` wanted from state bag | Done |

- **Ticket amounts** are resolved server-side from `Sunset.Police.violations` — client cannot set price.
- **Jail release** requires server-validated `releaseAt` — client timer triggers request but server rejects early release.
