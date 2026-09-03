# RPG plan verification — jobs, departments and factions

**Verified:** 2026-09-04
**Baseline:** `614c4f9` plus the current audit fixes
**Method:** code-path verification from configuration → manifest → client entrypoint → server callback → persistence/reward/dispatch outcome. Previous status documents were treated as untrusted.

## Civilian jobs

| Job | Runtime verdict | Verified flow | Important audit correction |
|---|---|---|---|
| Trucker | Complete MVP | depot → assigned truck/trailer → pickup → delivery payout/XP → depot return | Start is now depot-bound; pickup/delivery/return require the registered correct work truck. Trailer attachment still needs live OneSync QA. |
| Garbage | Complete MVP | depot → trash truck → ordered bin route → capacity → unload payout/XP | Start is depot-bound; collection requires the registered truck nearby and unload requires driving it. |
| Courier | Complete MVP | warehouse pickup → four randomized deliveries → per-package payout/XP | Start is warehouse-bound and deliveries are server-rejected while inside a vehicle, matching the on-foot plan. |
| Fisherman | Complete MVP | fishing area → timed catch → accumulated value → fish buyer payout/XP | Start is location-bound and server catch cooldown now matches the minigame duration, preventing callback farming. |
| Roadside mechanic | Complete MVP after fix | depot duty → mechanic dispatch → atomic accept → assigned customer repair → payout/XP → dispatch completion | Civilian mechanics are now valid dispatch providers. Payout requires an accepted call, the assigned caller in a nearby vehicle, and a server cooldown. |

All five jobs use one active server session per player, coordinate validation, authoritative payout and `job_progress` persistence. Session transitions now enforce the shared `Sunset.JobSession` contract rather than merely documenting it.

## Departments and legal factions

| Department | Verdict | Working | Still partial |
|---|---|---|---|
| LSPD | Substantial / MVP complete | grades, duty, fleet authorization, loadout, faction/radio/dispatch chat, wanted persistence, cuff/escort/vehicle detention, arrest/jail persistence, citations, confiscation, backup, radar display, MDC for online targets | Full offline MDT person search/history and evidence chain are absent. Radar readings originate from the officer client and are informational only. |
| Pillbox EMS | Functional but partial | grades, duty, ambulance, nearby downed alerts, medic dispatch, stabilize/heal/revive, activity audit, automatic dispatch completion | No stretcher, hospital intake/bed workflow, treatment inventory or medical record UI. |
| LSFD | Functional but partial | grades, duty, fire truck, fire dispatch, vehicle-fire incidents, distance-checked extinguisher progress, payout/society cut, medical rescue capabilities | Incident entities are client-created; no hose, building fires, spreading fire, extraction tools or durable incident history. Live multi-client entity cleanup needs QA. |
| Downtown Cab | Substantial / MVP complete | grades, duty, cab validation, phone ride lifecycle, atomic dispatch bridge, server meter, idle handling, proximity/drop-off checks, company cut and history | No customer rating/reputation. Manual fare remains an intentionally separate nearby-player flow. |
| LS Customs faction | Basic / partial | grades, duty, tow fleet, HQ paid repair, nearby player repair, society income | No parts inventory consumption, upgrade/customization shop, invoice/accept flow or faction mechanic dispatch lifecycle. The civilian mechanic job supplies roadside dispatch instead. |

## Illegal factions

| Faction | Verdict | Working | Still partial |
|---|---|---|---|
| Sunset Cartel | Basic | invite-only membership, hidden member blip, grades, chat/duty, crafting capability and pouch sale | No missions, production chain, turf, laundering or progression. |
| Night Syndicate | Basic | invite-only membership, hidden member blip, grades, chat/duty, illegal crafting and fencing | No robberies, turf, crew missions or progression. |

## Configuration and hierarchy fixes

- Joining a legal faction now requires server-verified proximity to its HQ; illegal factions are invite-only.
- Going on duty requires HQ proximity. Going off duty remains possible remotely so a player is never trapped on shift.
- Fleet spawning now requires a server authorization at the correct faction depot; the server supplies the allowed model and plate prefix.
- `setjob`/`setfaction` and the core reject undefined grades.
- `/setleader` now selects the actual highest configured grade. Previously it hardcoded grade 4, which broke Taxi and LS Customs because their maximum grade is 3.
- LSFD Captain and Battalion Chief now retain `stabilize`; rank permissions are explicit and are not inherited automatically.

## Dispatch verification

- Call creation, atomic DB acceptance, provider assignment, state transitions, completion/cancellation and disconnect recovery exist.
- Civilian mechanics are included as providers while their work session is active.
- Successful revive/extinguish/repair now advances skipped dispatch states before completion. Previously an actual completed incident could remain `OPEN` because `OPEN → COMPLETED` was rejected by the state machine.
- Taxi pickup now requires the passenger to be inside the driver's cab, and request pickup coordinates are taken from the server player entity rather than the browser/client payload.

## Honest completion assessment

The original Phase A–D plan is implemented at MVP depth after these corrections. Statements that every department/faction is fully complete are false. LSPD, Taxi and the five civilian jobs have complete primary loops. EMS, LSFD, faction mechanic and both criminal organizations remain partial by the larger RPG scope.

## Required live acceptance pass

Static validation cannot prove entity ownership, routing coordinates or two-player interaction inside FiveM. Before calling the build deployed/complete, run one staging session with two clients:

1. Execute each civilian job from its depot through payout and reconnect persistence.
2. Attempt remote `/work`, forged job vehicle, repeated fishing catch and mechanic repair without an accepted call; all must fail.
3. Join each legal faction at HQ, attempt remote join/duty/fleet spawn, and verify every rank's commands.
4. Run one Police arrest/jail reconnect, one EMS revive call, one LSFD incident and one Taxi trip with passenger in/out of the cab.
5. Restart resources during open dispatch calls and verify reload/reassignment/cleanup.
