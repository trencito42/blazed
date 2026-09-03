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
4. `/leavefaction` to quit.

## Chat Channels

| Command | Who | Notes |
|---------|-----|-------|
| `/f [msg]` | All faction members | Rate limited |
| `/r [msg]` | On-duty faction members | Radio |
| `/d [msg]` | On-duty law enforcement | Dispatch |
| `/gov [msg]` | On-duty legal factions | Government |

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
| `/fmotd [message]` | fmotd |
| `/fmembers` | members |

## Data Model

- Membership: `characters.metadata.faction`, `metadata.faction_grade`
- Leaders: `faction_leaders` table
- MOTD: `faction_motd` table
- Warnings: `faction_warnings` table
- Audit: `faction_audit_log` table

## Shared Code

- `sunset_core/shared/faction_core.lua` — `Sunset.HasFactionCapability()`
- `sunset_factions/server/core.lua` — duty, rate limits
- `sunset_factions/server/leaders.lua` — management commands
