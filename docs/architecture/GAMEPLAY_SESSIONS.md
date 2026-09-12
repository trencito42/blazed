# GAMEPLAY_SESSIONS — Canonical Server-Authoritative Session Framework

**Status:** IMPLEMENTED (Phase 2, 2026-09-12) — `sunset_sessions` resource ships the SessionService (server) + EmergencyCleanup (client) + central triggers (downed/jailed/drop/reconnect/timeout/resource-stop) + activity registry + reward idempotency API + admin diagnostics (`ListSessions`). Unit-tested via `sunset_testdriver` console command `sessiontest` (state machine, absorbing terminals, duplicate refusal, reward re-arm rejection).

**Adoption status (honest):**
- ALL civilian jobs (trucker/fisherman/courier/garbage/mechanic) are now MIRRORED into sunset_sessions (2026-09-12): StartSession creates a canonical `civilian_job` session (deadline monitoring, downed/jail/drop central triggers, entity registry with onEnd server-side deletion, ListSessions admin diagnostics); ClearSession ends it; registerVehicle registers the work vehicle entity; framework-ended sessions sync back into the local job table (no desync, re-entrancy guarded). High-frequency tick state intentionally stays local (documented tradeoff).
- Taxi is a FACTION activity (Sunset.Taxi.factionId, duty-gated), not a civilian job — confirmed it never touched sunset_jobs sessions; its ride lifecycle was hardened separately (P5-04 settling lock, P6-02 downed/jail cancel).
- Remaining ad-hoc (port candidates, documented): robbery (good state machine already), dice escrow (refund-safe now), turfs wars (redesigned with server-authoritative participants/respawn/loadouts), license exams.
- All NEW gameplay must be built on sunset_sessions directly. Do not extend the ad-hoc pattern.

Current systems are ad-hoc; robbery is the closest reference. This document defines the shared model every job/mission/quest/robbery/exam/faction-op/minigame must adopt. Do NOT build new gameplay on the old ad-hoc pattern.

## 1. Why

Today each system reinvents sessions: taxi (`Rides`), jobs (`Sessions`), robbery (`sessions.lua` — good), dice (escrow), turfs (`ActiveWars`), licenses (test sessions). They diverge on cleanup, reconnect, restart, idempotency. Result: the wedge/leak/stuck bugs found in the audit (P6-02 taxi wedge, P5-07 dice escrow, orphan vehicles). One model fixes the whole class.

## 2. Session record (server-authoritative)

```lua
Session = {
  id           = <string>,   -- unpredictable: base64(random 16 bytes). Never client-chosen.
  charId       = <int>,      -- owner character
  source       = <int>,      -- current source (updated on reconnect)
  activity     = <string>,   -- 'trucker' | 'robbery' | 'license_driving' | 'taxi' | ...
  state        = <enum>,     -- see state machine
  startedAt    = <os.time>,
  deadlineAt   = <os.time>,  -- timeout
  requiredEntities = {       -- net IDs the session depends on
     vehicle = <netId>, trailer = <netId>, ped = <netId>,
  },
  entityModels   = { vehicle = <hash>, ... },  -- expected models, validated server-side
  location     = { coords = <vector3>, radius = <m> },  -- allowed area / objective
  requiredItem = <string|nil>,
  progress     = { stage = <int>, ... },        -- activity-specific
  rewardState  = 'none'|'pending'|'granted',    -- idempotency guard
  cancelReason = <string|nil>,
  cleanup      = <function(session)>,           -- activity-specific teardown
  persisted    = <bool>,                        -- survives restart? (see §6)
}
```

## 3. State machine

```
IDLE → REQUESTED → STARTING → ACTIVE → OBJECTIVE_COMPLETE → REWARD_PENDING → COMPLETED
                       │          │             │                  │
                       └──────────┴─────────────┴──────────────────┴─→ { CANCELLED | FAILED | TIMED_OUT | PLAYER_DROPPED | ENTITY_LOST }
```

**Transition rules:**
- ONLY the server calls `transition(session, newState, reason)`. Clients request; never set state.
- Every transition is logged (observability §12) with `session.id` so a flow can be reconstructed.
- `REWARD_PENDING → COMPLETED` is the only path that grants a reward, and it is atomic + idempotent (guarded by `rewardState`; a DB unique key on `(charId, activity, sessionKey)` where a period applies).
- Terminal states run `cleanup` exactly once (guard flag).

## 4. Correct action sequence (canonical)

```
1. Client requests action (callback) with minimal data.
2. Server validates: authenticated char, ownership, permission, faction/rank,
   duty, player state (not downed/jailed via IsIncapacitated), distance,
   routing bucket, entity existence+model, seat, inventory, cooldown, no
   conflicting active session, submitted value ranges.
3. Server creates/advances the session (authoritative).
4. Server returns accepted session.id + authoritative instructions
   (where to go, what to spawn, what anim to play).
5. Client starts animation/UI/props ONLY after acceptance.
6. Client reports observations (arrived, attached, delivered) — never outcomes.
7. Server INDEPENDENTLY validates completion (coords, entity, trailer attach,
   item consumed) — never trusts the client's "done".
8. Server commits reward atomically (txn: ledger + items + progression).
9. Both sides run cleanup (server teardown + client `sunset:session:cleanup`).
```

Idempotency: every action handler is safe to call twice (state-gated). A duplicate `OBJECTIVE_COMPLETE` while already `REWARD_PENDING` is a no-op.

## 5. Universal emergency cleanup (client)

One exported function every activity calls on ANY exit (complete/cancel/timeout/death/arrest/bucket-change/vehicle-exit/resource-stop/reconnect). Target: `exports.sunset_ui:EmergencyCleanup()` or a shared `sunset_sessions` client export.

```lua
function EmergencyCleanup(reason)
  -- animation / scenario
  ClearPedTasksImmediately(ped); ClearPedSecondaryTask(ped)
  -- frozen / invincible / collision
  FreezeEntityPosition(ped, false); SetEntityInvincible(ped, false)
  SetPlayerInvincible(PlayerId(), false); SetEntityCollision(ped, true, true)
  -- attached entities (escort, props)
  DetachEntity(ped, true, true)
  -- spawned props / objects / peds tracked by the session
  for _, e in ipairs(sessionEntities) do if DoesEntityExist(e) then DeleteEntity(e) end end
  -- cameras
  DestroyAllCams(true); RenderScriptCams(false, true, 0, true, false)
  -- routing bucket
  SetPlayerRoutingBucket(PlayerId(), 0)
  -- NUI focus + modals
  exports.sunset_ui:Send('sessionForceClose', { reason = reason })
  exports.sunset_ui:SetFocus(false, false, false, 'force')
  -- screen effects
  ClearTimecycleModifier(); DoScreenFadeIn(300); AnimpostfxStopAll()
  -- checkpoints / blips
  DeleteCheckpoint(cp); for _, b in ipairs(blips) do RemoveBlip(b) end
  -- mission vehicles (only if session-owned and not player-persisted)
  for _, v in ipairs(missionVehicles) do if DoesEntityExist(v) then SetEntityAsMissionEntity(v,true,true); DeleteVehicle(v) end end
  -- controls
  SetPlayerControl(PlayerId(), true, 0)
end
```

Server side: `SessionService.cancel(session, reason)` runs the server teardown (delete tracked entities it owns, release locks, persist-or-clear) then tells the client `TriggerClientEvent('sunset:session:cleanup', src, session.id, reason)`.

## 6. Reconnect / restart behavior (per activity, declared)

Each activity declares one of:
- **ABANDON** — on drop/restart, cancel + cleanup + no reward (robbery, dice, most minigames).
- **SUSPEND** — persist minimal state to DB; on `characterSelected` re-attach if still valid within a window (long deliveries, license exams mid-progress).
- **PERSIST** — full DB-backed session rehydrated on restart (dispatch already does this — reference).

The session framework provides `onPlayerReconnect(charId)` and `onResourceStart()` hooks that walk persisted sessions and either re-attach or cancel-with-cleanup. No player may be left frozen/invisible/attached/stuck (INVARIANT S7/S8).

## 7. Triggers that force session end (wired centrally)

| Trigger | Action |
|---|---|
| `sunset:death:playerDowned` | cancel sessions requiring mobility; ABANDON |
| `sunset:faction:playerJailed` | cancel all; ABANDON |
| entered cuff/escort | cancel; ABANDON |
| routing-bucket change (property enter) | cancel outdoor sessions |
| required entity destroyed/lost | ENTITY_LOST → recover-or-cancel per activity |
| left required vehicle (grace period) | warn → cancel after grace |
| playerDropped | per declared reconnect behavior |
| onResourceStop | cancel + cleanup all (no frozen state survives) |
| timeout (deadlineAt) | TIMED_OUT → cleanup |

## 8. Migration path (how to adopt without big-bang rewrite)

1. Create `sunset_sessions` resource (server SessionService + client EmergencyCleanup) — no gameplay yet.
2. Port ONE activity as the reference vertical slice: **Trucker** (see vertical-slice plan). Prove every state, every trigger, every reconnect path.
3. Add automated session tests (REGRESSION_MATRIX) against Trucker.
4. Port remaining activities one at a time (taxi, robbery, licenses, dice, turfs), deleting their ad-hoc session tables as they move over.
5. Keep robbery's existing good state machine as-is until its turn; do not regress it.

Until an activity is ported, it must at minimum: use `IsIncapacitated` gates, register cleanup on `playerDropped`/`onResourceStop`, and guarantee single reward. (Most now do, post-audit.)

## 9. Anti-patterns this framework forbids

- Starting an anim/task because the client pressed a key (must be server-accepted first).
- Trusting a client "I delivered" / "I attached" / "I'm at the checkpoint" without server coords/entity check.
- Granting reward outside `REWARD_PENDING → COMPLETED`.
- Mutable session state keyed by `source` that survives a character switch (key by charId; map source→session).
- Cleanup only on the happy path.
- Two subsystems both believing they own the same entity.
