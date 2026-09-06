# Factions Guide

SunsetMP uses a **capability-based faction framework**. Factions are not hardcoded by name — code checks `factionType` and rank permissions.

## Faction Types

| Type | Factions | Capabilities |
|------|----------|--------------|
| `law_enforcement` | LSPD (`police`) | Cuff, arrest, wanted, fines, MDC, backup (`/backup`, `/cbackup`) |
| `ems` | Pillbox EMS (`medic`) | Heal, revive |
| `fire_rescue` | LSFD (`lsfd`) | Heal, revive (Engineer+) |
| `transport` | Downtown Cab (`taxi`) | Fares, phone app rides |
| `mechanic` | LS Customs (`mechanic`) | Repairs |
| `criminal_org` | Cartel, Syndicate | Craft/sell/fence at HQ |

## Joining & Duty

1. Go to faction HQ (map blip / world marker).
2. Press `[E]` to join (must not be in another faction).
3. Use `/duty` to toggle shift. **Salary requires ON DUTY.**
4. `/leavefaction` or `/quitfaction` to quit voluntarily (leaders are auto-demoted).

## Faction headquarters

| Faction ID | Label | HQ marker `[E]` | Notes |
|------------|-------|-----------------|-------|
| `police` | LSPD | Mission Row PD — `441.15, -981.95, 30.69` | MRPD fleet garage nearby |
| `medic` | Pillbox EMS | Pillbox entrance — `298.0, -584.0, 43.28` (exterior) | Hospital interior closed (bob74 default); RP outside |
| `taxi` | Downtown Cab Co. | `903.32, -170.14, 74.08` | Cab depot at same block |
| `mechanic` | LS Customs | `337.52, -136.57, 39.01` | Drive-in repair when in vehicle |
| `lsfd` | LS Fire Department | `1194.82, -1464.01, 34.86` | Fire station garage |
| `fib` | FIB | `105.52, -745.12, 45.75` | Interior lift (`136.25, -761.65, 45.75`) → motor pool on Power St |
| `sheriff` | San Andreas Sheriff | `387.74, -1607.92, 29.29` (exterior) | Fleet garage in parking lot south of station |
| `sunset_cartel` | Sunset Cartel | `1394.72, 1141.98, 114.33` | Invite-only; members-only blip |
| `night_syndicate` | Night Syndicate | `-1520.88, 849.55, 181.59` | Invite-only; members-only blip |

Hospital respawn (`HospitalSpawn`) uses Pillbox exterior at `298.0, -584.0, 43.28`. EMS supply crafting is at `296.0, -582.0, 43.28` (exterior near entrance).

**Pillbox interior:** GTA V has no clean walkable native lobby IPL — `rc12b_hospitalinterior` is the heist disaster state. bob74_ipl keeps `rc12b_default` (closed glass doors, visible interior). Admins can place a door checkpoint: stand at the main entrance (`309.0, -595.5, 43.28`) and run `/setcp pillbox_door`.

## Chat Channels

| Command | Who | Notes |
|---------|-----|-------|
| `/f [msg]` | All faction members | Rate limited |
| `/r [msg]` | On-duty faction members | Radio |
| `/d [msg]` | On-duty law enforcement | Dispatch |
| `/gov [msg]` | On-duty LSPD / EMS / LSFD | Government (all players read) |

## Leadership

Admins: `/setleader [id] [faction]`, `/removeleader [id] [faction]` — logged to `faction_audit_log`.

Leaders (or ranks with permission):

| Command | Permission |
|---------|------------|
| `/finvite [id]` | invite |
| `/funinvite [id]` | uninvite |
| `/fpromote [id] [grade]` | promote |
| `/fgiverank [id] [grade]` | giverank |
| `/fwarn [id] [reason]` | fwarn |
| `/fmotd` | Any member can read the current MOTD in chat |
| `/fmotd [message]` | fmotd permission required to update it |
| `/fmembers` | members |

## Data Model

`/faction` opens the member dashboard with roster, leaders, MOTD, duty/rank/salary, fleet and current weekly activity target. `/factions` opens the public server directory with each organization's leaders, population, on-duty count and recruitment status.

- Membership: `characters.metadata.faction`, `metadata.faction_grade`
- Leaders: `faction_leaders` table
- MOTD: `faction_motd` table
- Warnings: `faction_warnings` table
- Audit: `faction_audit_log` table

## Shared Code

- `sunset_core/shared/faction_core.lua` — `Sunset.HasFactionCapability()`
- `sunset_factions/server/core.lua` — duty, rate limits
- `sunset_factions/server/leaders.lua` — management commands
