# SunsetMP — Command Reference (from code registration)

Generated from `RegisterCommand` across `resources/[sunset]`.  
**T-chat** routes via `sunset:chat:runCommand` → `command_router.lua` (after local fixes).

## Routing rules (post-fix)

| Type | Examples | Execution |
|------|----------|-----------|
| Server chat | `/f`, `/r`, `/d`, `/gov`, `/m`, `/cmotd`, `/fmotd` | `RunChatCommand` on server |
| Server registered | `/buylevel`, `/rob`, `/service`, `/heal`, house cmds | `ExecutePlayerCommand` exports |
| Client only | `/help`, `/pass`, `/stats`, `/faction`, police UX cmds | `sunset:chat:executeCommand` |
| Admin | `/kick`, `/tp`, `/setstat` | `sunset_admin:ExecutePlayerCommand` |
| Dual-side | `/accept` | &lt;2 args → client (faction); else dispatch server |

## Dual-side commands (review when changing router)

| Command | Client | Server |
|---------|--------|--------|
| accept | faction invite | dispatch `type id` |
| clan, clans | open NUI | trigger open NUI |
| f, r, d | forward to server chat | authoritative chat |
| startradar, setradar, radar, stopradar | UI | server validation |

---

## General & UI

| Command | Side | Description |
|---------|------|-------------|
| /help | client | Personalized command guide |
| /stats | client | M-menu statistics |
| /pass | client | Blaze Pass panel |
| /missions | client | Pass missions |
| /inventory | client | Inventory |
| /phone | client | Phone |
| /crafting | client | Crafting |
| /documents, /id, /licenses | client | Documents |
| /properties, /sethome | client | Properties UI |
| /jobs, /work, /jobhelp, /skills, /quitjob | client | Civilian jobs |
| /emotes, /e, /stopemote | client | Emotes |
| /sunset_menu | client | M menu (keybind) |

## Chat

| Command | Side | Description |
|---------|------|-------------|
| /me, /do | server | Proximity roleplay |
| /sunset_chat | client | Open chat (T) |

## Faction & police (client unless noted)

| Command | Notes |
|---------|-------|
| /faction, /factions | Dashboard / directory |
| /duty | Toggle duty |
| /f, /r, /d, /gov, /m | Chat (server authoritative) |
| /finvite, /acceptfaction, /declinefaction, /accept | Faction invite flow |
| /fpromote, /fgiverank, /funinvite, /fwarn, /fw, /fmotd, /fmembers | Leadership |
| /leavefaction, /quitfaction, /factionquit, /quitgroup | Leave faction |
| /cuff, /uncuff, /fine, /repairveh, /fare | Role commands |
| /su, /so, /clear, /unjail, /find, /wanted, /arrest, /booking | Police |
| /backup, /cbackup, /mdc, /ticket, /confiscate | Police |
| /startradar, /setradar, /radar, /stopradar, /radars | Radar |
| /stabilize, /heal, /revive | EMS (server for heal/revive) |
| /handsup, /frisk, /drag, /escort, /putinveh, /takeout | Detention |
| /pd, /fd, /pdgarage | Faction shortcuts |
| /sellpouch, /fence | Illegal economy |

## Clan

| Command | Side | Notes |
|---------|------|-------|
| /clan, /group, /clans | both/client+server | Panel / directory |
| /c | server | Clan chat |
| /cmotd | server (post-fix) | MOTD read/set |
| /cwarn, /cw | client | Warnings |
| /acceptclan, /declineclan | client | Invites |

## Admin (server)

| Command | Level |
|---------|-------|
| kick, tp, bring, coords, heal*, revive*, arespawn, astats | 2+ |
| ban, unban, car, dv, noclip, god, announce, setjob, setfaction, givecar, giveitem, givegun, setleader, removeleader, acreatehouse, ahouseedit, setstat, setjobstat, setrob | 3+ |
| setadmin | 5 |

\*EMS on duty bypasses admin level via faction perm.

Client-only admin UX: `/setcp`, `/delcp`, `/gotocp`, `/gotoloc`, `/speed`, `/hudexport`, `/dealershipadmin`

## Properties (server)

/acreatehouse, /houseinteriors, /houselock, /houserent, /housemaxrenters, /houseinterior, /hdescription, /houserenters, /housekickrenter, /sellhouse, /ahouseedit, /aenablerent, /renthouse, /unrent

## Dispatch (server)

/service, /servicecalls, /accept, /cancel, /calls (client list)

## Economy & progression

| Command | Side |
|---------|------|
| /buylevel | server |
| /rob, /robdebug | server |
| /givecar | server (admin) |

## Vehicles (client)

/garage, /v, /park, /givekeys, /takekeys, /recovertrailer, sunset_lock, sunset_engine, sunset_seatbelt, sunset_lights

## Fire

/firestart, /firecalls

## Fisherman

/fish, /sellfish

## Death

/respawn, /112, /spawnmenu

## Dealership

/dealership, /dealershipadmin

---

## /help behavior

- Server builds categories: General, Faction (if member), Job (if employed), On Duty, Admin (if level &gt; 0).
- Returns error string if character not loaded — **never nil**.
- Suggestions registered client-side from same data.
