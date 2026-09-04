# Police reliability pass — 2026-09-04

## Reported failures reproduced in code

- `/ticket` could never provide the required `violationCode`: the server expected it, but the NUI had no selector and discarded the ticket payload.
- `/arrest` required a hidden booking coordinate, cuff state, wanted state, proximity, duty, and rank while returning generic failure text on the client.
- `/help` added every LSPD command regardless of the current rank, creating commands the player could see but could not use.
- Cadet could cuff but had no uncuff permission; Officer could not complete a normal wanted/arrest patrol loop.
- Cuff was delivered through two synchronization paths and could replay the notification/animation; client restart/spawn did not hydrate the state bag.
- `/so` only gave the target a strong visual notification; surrounding players did not receive a clear chat event.
- The legacy `/fine` path accepted an arbitrary amount and immediately removed money, bypassing the citation accept/refuse workflow.
- A forged repeated refusal could add multiple wanted charges for one citation.
- Unhandled callback exceptions exposed raw internal errors to players.

## Corrections

- Added violation dropdown, target prefill, locked server-configured amount/reason, and preserved the panel on validation errors.
- Added `/booking`, map blips, blue world markers, GPS routing, and exact arrest prerequisites/distances.
- Wanted charges now accumulate stars and jail time under caps and broadcast to on-duty law enforcement.
- `/so` broadcasts a nearby `POLICE ALERT` chat line while retaining the target overlay.
- Normal Officer rank can perform the full patrol loop; Cadet can undo cuffs; personalized help is permission-filtered.
- Cuff rendering is idempotent, restores from `sunsetCuffed`, forces unarmed state, blocks gestures, and restores animation after interruption.
- `/fine [id]` routes to `/ticket [id]`; the legacy server callback is disabled.
- Citation pay/refuse uses a one-time database claim so repeated requests cannot duplicate consequences.
- Faction, Police, EMS, leader, target, distance, duty, rank, and callback failures now explain the failed prerequisite and recovery action.

## Verification boundary

Lua and JavaScript parsing, whitespace validation, manifest linkage, command registration, and static callback checks can be run without restarting the production server. A real two-player FiveM session is still required to prove GTA native behavior and database/network timing; this document does not claim that static checks can eliminate every future runtime defect.
