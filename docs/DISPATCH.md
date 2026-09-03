# Dispatch / Service Core

Unified server-authoritative dispatch for civilian service requests. Other resources (taxi fare meter, EMS heal, fire incidents, mechanic repair) hook into this core via exports and events.

## Service types

| Type | Providers | Faction |
|------|-----------|---------|
| `taxi` | On-duty transport faction | Downtown Cab (`taxi`) |
| `medic` | On-duty EMS | Pillbox EMS (`medic`) |
| `fire` | On-duty fire rescue | LSFD (`lsfd`) |
| `mechanic` | On-duty mechanics + civilian `/work` mechanics | LS Customs (`mechanic`) + `sunset_jobs` |
| `police_backup` | Broadcast-only — on-duty LEO, EMS, LSFD | LSPD officer caller |

## Call states

```
OPEN → ASSIGNED → EN_ROUTE → ARRIVED → IN_PROGRESS → COMPLETED
  ↓        ↓          ↓          ↓            ↓
CANCELLED (from any non-terminal state; IN_PROGRESS cancel restricted for responders)
```

- **OPEN** — waiting for a provider
- **ASSIGNED** — provider accepted (atomic DB `UPDATE … WHERE status = 'OPEN'`)
- **EN_ROUTE** — provider heading to caller
- **ARRIVED** — provider on scene
- **IN_PROGRESS** — gameplay hook active (fare, heal, extinguish, repair)
- **COMPLETED** / **CANCELLED** — terminal

## Player commands

| Command | Description |
|---------|-------------|
| `/service [type] [message]` | Request taxi, medic, fire, or mechanic at your location |
| `/servicecalls` | List open calls for your on-duty service role |
| `/accept [type] [id]` | Accept a call (sets GPS waypoint) |
| `/cancel [type] [id]` | Cancel a call (caller, assigned responder, or duty provider) |

## Server exports (`sunset_dispatch`)

```lua
-- Create a call (coords optional; defaults to player position)
local call, err = exports.sunset_dispatch:CreateServiceCall(source, 'medic', nil, { priority = 2 }, 'Injured at Legion')

-- Accept (atomic — returns nil if already taken)
local call, err = exports.sunset_dispatch:AcceptCall(source, 'medic', callId)

-- State machine
exports.sunset_dispatch:UpdateCallState(source, 'medic', callId, 'EN_ROUTE')
exports.sunset_dispatch:CompleteCall(source, 'medic', callId)
exports.sunset_dispatch:CancelCall(source, 'medic', callId, 'reason')

-- Queries
local open = exports.sunset_dispatch:GetActiveCalls('taxi', { status = 'OPEN' })
local mine = exports.sunset_dispatch:GetPlayerActiveCall(source)
local isEms = exports.sunset_dispatch:IsProviderForType(source, 'medic')
```

`CreateCall` is an alias for `CreateServiceCall`.

## Events

| Event | When |
|-------|------|
| `sunset:dispatch:callCreated` | New call inserted |
| `sunset:dispatch:callAccepted` | Provider assigned |
| `sunset:dispatch:callStateChanged` | Status transition |
| `sunset:dispatch:callCancelled` | Cancelled or timeout |
| `sunset:dispatch:callCompleted` | (via state change to COMPLETED) |

Client events: `sunset:dispatch:newCall`, `sunset:dispatch:callAccepted`, `sunset:dispatch:waypoint`, `sunset:dispatch:callUpdated`, `sunset:dispatch:callEnded`, `sunset:dispatch:callTaken`.

## Callbacks

| Callback | Purpose |
|----------|---------|
| `sunset:getServiceCalls` | Open calls for provider UI |
| `sunset:getMyServiceCall` | Caller's or responder's active call |
| `sunset:dispatchAcceptCall` | Accept by ID (infers type) |
| `sunset:dispatchCancelCall` | Cancel active call |
| `sunset:dispatchUpdateState` | Transition state |

## Persistence

Table `service_calls` in `sql/09-dispatch-wanted-jail.sql`. Open calls reload on resource start. Disconnect cleanup:

- **Caller disconnect** → cancel call
- **Responder disconnect (pre-IN_PROGRESS)** → reopen as OPEN
- **Responder disconnect (IN_PROGRESS)** → cancel call

## Rate limits

Configured in `sunset_core/shared/dispatch.lua`: create 30s, accept 2s, cancel 5s per player.

## Police backup

| Command | Description |
|---------|-------------|
| `/backup` | Officer requests backup — creates `police_backup` dispatch call |
| `/cbackup` | Officer cancels active backup — removes responder blips |

- Notifies all on-duty **law enforcement, EMS, and fire rescue** with notification + 60s temp blip.
- Rate limit: 30s between requests; one active backup per officer.
- Auto-cancel on officer disconnect, death, or server restart (open calls re-broadcast on load).

## Integration notes

- **Taxi** (`sunset_taxi`): use `CreateServiceCall` for `/service taxi`; implement fare meter separately and call `CompleteCall` when paid.
- **EMS** (`sunset_factions` / `sunset_death`): `/service medic`; heal/revive commands validate distance then `UpdateCallState` / `CompleteCall`.
- **Fire** (`sunset_fire`): `/service fire`; incident scripts drive ARRIVED → IN_PROGRESS → COMPLETED.
- **Mechanic** (`sunset_jobs`): civilian `/work` shift listens to `sunset:jobs:notifyMechanicCall` and `sunset:dispatch:newCall`; uses `AcceptCall(source, 'mechanic', id)` and `CompleteCall(source, 'mechanic', id)`.
- **Police backup** (`sunset_factions`): `/backup` and `/cbackup` via `CreateServiceCall` / `CancelCall` with type `police_backup`.

Shared contract: `sunset_core/shared/dispatch.lua`.
