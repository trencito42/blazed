# Taxi (Downtown Cab Co.)

## Overview

The taxi system combines the **Downtown Cab phone app** (`sunset_taxi`) with the unified **dispatch queue** (`sunset_dispatch`). Drivers on duty receive ride offers via the app and dispatch notifications.

## Requesting a ride

| Method | How |
|--------|-----|
| Phone app | Open phone → Downtown Cab → pick destination → request ride |
| Dispatch | `/service taxi [message]` — creates a dispatch call; drivers accept with `/accept taxi [id]` |

Both paths create a dispatch entry and notify on-duty taxi drivers.

## Driver workflow

1. Join Downtown Cab at HQ (`[E]` at yellow marker) and go **on duty** (`/duty`).
2. Spawn a cab at the depot (`[E]` at garage marker).
3. Turn on availability in the Cab app (drivers only).
4. Accept rides from the app or `/accept taxi [id]` for `/service` calls.
5. Drive to pickup → confirm pickup in app.
6. Drive to destination → complete trip in app.

## Fare meter (server-authoritative)

During an active trip (`in_progress`), the server tracks distance driven:

- Fare = `baseFare + meterKm × perKm` (see `sunset_taxi/shared/config.lua`)
- **Anti-idle**: fare only increases when the cab moves at least 4 m between ticks; standing still does not inflate the meter
- Final charge uses the meter fare (capped at 1.5× the estimated fare)
- Company cut (12%) goes to the `taxi` society

Manual fares via `/fare [id] [amount]` still work for ad-hoc charges.

## Faction activity

Completed app rides log `taxi_ride_complete` in `faction_audit_log` and emit `sunset:faction:activityComplete` for transport activity tracking.

## Commands

| Command | Who | Description |
|---------|-----|-------------|
| `/service taxi [msg]` | Anyone | Request taxi via dispatch |
| `/accept taxi [id]` | On-duty driver | Accept dispatch call |
| `/servicecalls` | On-duty provider | List open calls for your role |
| `/cancel taxi [id]` | Caller or responder | Cancel a call |
| `/fare [id] [amount]` | On-duty driver | Manual fare collection |
| `/duty` | Faction member | Toggle shift |

## Resources

- `resources/[sunset]/sunset_taxi` — ride state machine, meter, phone callbacks
- `resources/[sunset]/sunset_dispatch` — unified service queue
- `sql/06-taxi.sql` — `taxi_rides` history table
- `sql/09-dispatch-wanted-jail.sql` — `service_calls` table

## Exports

```lua
-- Dispatch (from sunset_dispatch)
exports.sunset_dispatch:CreateServiceCall(source, 'taxi', coords, metadata, description)
exports.sunset_dispatch:CompleteCall(source, 'taxi', callId)
```

Events: `sunset:dispatch:callAccepted`, `sunset:faction:activityComplete`
