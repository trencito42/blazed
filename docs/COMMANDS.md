# Player Commands (English)

## General
| Command | Description |
|---------|-------------|
| `/faction` | Faction info, rank, salary, your commands |
| `/duty` | Toggle on/off shift |
| `/leavefaction` | Leave current faction |
| `/quitfaction` | Same as `/leavefaction` |
| `/quitjob` | Quit civilian job at Job Center (not faction) |
| `/handsup` | Toggle hands up (`X` key) |

## Faction Chat
| Command | Description |
|---------|-------------|
| `/f [message]` | Faction chat |
| `/r [message]` | On-duty faction radio |
| `/d [message]` | Law enforcement dispatch |
| `/gov [message]` | On-duty government factions |

## Faction Leadership
| Command | Description |
|---------|-------------|
| `/finvite [id]` | Recruit player |
| `/funinvite [id]` | Remove member |
| `/fpromote [id] [grade]` | Promote member |
| `/fgiverank [id] [grade]` | Set member rank |
| `/fwarn [id] [reason]` | Issue faction warning |
| `/fmotd [message]` | Set message of the day |
| `/fmembers` | List online members |

## LSPD / Law Enforcement
| Command | Description |
|---------|-------------|
| `/pd` | LSPD help |
| `/pdgarage` | Spawn patrol vehicle |
| `/cuff [id]` | Restrain suspect |
| `/uncuff [id]` | Remove restraints |
| `/escort [id]` | Escort/drag suspect |
| `/putinveh [id]` | Put suspect in vehicle |
| `/takeout [id]` | Remove suspect from vehicle |
| `/frisk [id]` | Search suspect |
| `/su [id] [reason]` | Add a wanted charge; `/su` lists valid reason codes |
| `/so [id]` | Order a nearby suspect to stop; target gets overlay and nearby players get chat alert |
| `/wanted` | List wanted players |
| `/booking` | Set GPS to nearest MRPD/Bolingbroke booking marker |
| `/arrest [id]` | Arrest a cuffed, wanted suspect inside a booking marker |
| `/fine [id]` | Alias that opens the safe citation UI |
| `/ticket [id]` | Select an official server-priced violation and issue citation |
| `/mdc` | Mobile data terminal |
| `/m [message]` | Megaphone |
| `/backup` | Request emergency backup (notifies on-duty LEO, EMS, LSFD + map blip) |
| `/cbackup` | Cancel your active backup request |

## EMS / LSFD
| Command | Description |
|---------|-------------|
| `/heal [id]` | Heal player (self if no id) |
| `/revive [id]` | Revive unconscious player |

## Taxi
| Command | Description |
|---------|-------------|
| `/fare [id] [amount]` | Manual fare collection |

## Service Dispatch
| Command | Description |
|---------|-------------|
| `/service [type] [message]` | Request taxi, medic, fire, or mechanic |
| `/servicecalls` | List open calls (on-duty providers) |
| `/accept [type] [id]` | Accept a service call |
| `/cancel [type] [id]` | Cancel a service call |

## Mechanic
| Command | Description |
|---------|-------------|
| `/repairveh [id]` | Repair player vehicle |

## Criminal Factions
| Command | Description |
|---------|-------------|
| `/sellpouch` | Cartel — sell sealed pouch at HQ |
| `/fence` | Syndicate — fence contraband at HQ |

## Admin (level varies)
| Command | Description |
|---------|-------------|
| `/setjob [id] [job] [grade]` | Civilian job |
| `/setfaction [id] [faction] [grade]` | Set faction |
| `/setleader [id] [faction]` | Assign faction leader |
| `/removeleader [id] [faction]` | Remove faction leader |
| `/kick`, `/ban`, `/tp`, `/heal`, `/revive`, etc. | See `sunset_admin` |
| `/setcp [name]` | Save current position as checkpoint (moderator+) |
| `/delcp [name]` | Delete saved checkpoint (moderator+) |
| `/gotocp [name]` | Teleport to saved checkpoint; omit or `list` to show names (moderator+) |
| `/gotoloc [id or name]` | Teleport to predefined world location (moderator+) |
| `/speed [multiplier]` | Vehicle speed boost while driving (moderator+); `/speed off` to reset |
