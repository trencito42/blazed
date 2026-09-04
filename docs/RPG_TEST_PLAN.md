# RPG Framework Test Plan

## Faction Core

- [ ] Join LSPD at MRPD — auto on duty, loadout applied
- [ ] `/duty` toggles off — uniform removed, weapons cleared
- [ ] `/leavefaction` clears faction, cannot use `/f`
- [ ] `/f` only visible to same faction; rate limit after spam
- [ ] `/r` only works on duty; off-duty members don't see it
- [ ] `/d` only for on-duty LEO
- [ ] `/gov` works for on-duty medic/police; not for gangs
- [ ] `/setleader` + `/fmembers` shows [LEADER] tag
- [ ] `/fmotd` persists across `/fmembers`
- [ ] `faction_audit_log` row on invite/uninvite/warn

## Detention Security

- [ ] `/cuff` fails when >3.5m away
- [ ] `/cuff` fails without on-duty + permission
- [ ] Cannot cuff without server callback (no NetEvent exploit)
- [ ] `/escort` attaches suspect to officer; toggle off works
- [ ] `/putinveh` places cuffed player in nearby seat
- [ ] `/frisk` lists inventory items to officer chat only
- [ ] `/handsup` plays anim; disables combat controls

## Police

- [ ] `/su [id] speeding` sets ★1 wanted on target HUD
- [ ] `/wanted` lists online wanted with decay timer
- [ ] `/booking` sets GPS; markers render at MRPD basement and Bolingbroke intake
- [ ] `/arrest` rejects in order with a precise reason unless target is online, wanted, cuffed, at booking, and within 5m
- [ ] Arrest pays bounty to officer bank
- [ ] Jail teleports + disables controls until timer ends
- [ ] `/ticket [id]` shows violation selector and server price; pay/refuse works once, repeated requests do not double charge/add wanted
- [ ] `/so [id]` gives target overlay and a nearby `POLICE ALERT` chat message
- [ ] Cuff persists through duplicate sync, vehicle enter/exit, animation interruption, and player respawn
- [ ] `/mdc` UI shows wanted list
- [ ] `/backup` notifies on-duty LEO, EMS, LSFD with blip via dispatch
- [ ] `/cbackup` cancels backup and removes blips
- [ ] Jail early release exploit blocked (server `releaseAt` check)
- [ ] Ticket UI cannot set custom amount (server config only)
- [ ] `/fare` fails when driver >8m from passenger
- [ ] `/revive` fails when >4m or target not downed
- [ ] Civilian mechanic `/work` receives and completes dispatch calls
- [ ] `/m` heard only within ~35m

## EMS / LSFD

- [ ] Join EMS at Pillbox, `/duty`, `/heal [id]` works
- [ ] Trainee cannot `/revive`; Paramedic+ can
- [ ] LSFD Engineer+ can `/revive`

## Taxi

- [ ] Passenger requests ride via phone — driver accepts
- [ ] Complete ride only at destination radius
- [ ] Payment server-side; driver receives cut
- [ ] `/fare` manual charge works on duty

## Economy

- [ ] On-duty faction payday at :00 to bank
- [ ] Off-duty faction gets $0 salary
- [ ] Civilian job salary without duty requirement

## Regression

- [ ] Friendly fire off between on-duty same faction
- [ ] Scoreboard shows faction label
- [ ] Character select preserves metadata faction after relog
- [ ] Taxi app still loads after faction refactor

## Not in scope (verify still stubbed)

- [ ] Trucker has no routes
- [ ] Fire hose does not exist
- [ ] Wanted survives server restart (expected fail until Phase B)
