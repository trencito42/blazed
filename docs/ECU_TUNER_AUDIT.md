# ECU Tuner — System Audit

**Date:** 2026-09-11  
**Resource:** `sunset_tuning`  
**Persistence:** `vehicles.props` JSON (`ecu`, `cosmetics`)

## Scope

Audited all files under `resources/[sunset]/sunset_tuning`, integration with `sunset_vehicles`, `sunset_factions` (LSC), `sunset_menu`, `sunset_ui`, and SQL schema `vehicles.props`.

## File inventory

| Path | Role |
|------|------|
| `shared/config.lua` | Tune schema, stages, costs, sanitize, stock detection |
| `server/main.lua` | Ownership validation, save/load, dyno, FX auth |
| `client/apply.lua` | Handling + native mods apply (critical path) |
| `client/main.lua` | ECU NUI lifecycle, preview/save/cancel |
| `client/lsc_menu.lua` | LS Customs repair vs ECU chooser |
| `client/bootstrap.lua` | Load tune on driver seat enter |
| `client/effects.lua` | Pops, 2-step, anti-lag runtime |
| `client/exhaust_ptfx.lua` | Particles / sounds |
| `client/cosmetics.lua` | Paint / plate preview |
| `client/dyno.lua` | Dyno session |
| `web/app.js` | ECU NUI — all tabs/sliders |
| `sunset_vehicles/client/main.lua` | Spawn → `ApplyTune`, store → `ExportTuneForStore` |

## Lifecycle (as found)

```
LSC / Harmony [E]
  → sunset:tuning:getTune (server, props.ecu)
  → NUI open + client preview (ApplyTune persist=false)
  → tuningSave → server SanitizeTune + charge + UPDATE vehicles.props
  → TriggerClientEvent applyByPlate (-1)
Garage spawn
  → sunset_vehicles spawnOwnedVehicleEntity
  → exports.sunset_tuning:ApplyTune(vehicle, props.ecu)
  → sunset_tuning bootstrap thread (duplicate apply risk)
Store vehicle
  → ExportTuneForStore (only if persistedPlates[plate])
```

## Critical defects

### 1. Generic, model-agnostic performance
- `SunsetTuning.Stages` apply fixed multipliers (`civil 1.0`, `sport 1.06`, `race 1.14`) to **every** vehicle.
- Same `power`/`torque` sliders regardless of compact vs supercar.
- No vehicle profile or capability gate.

### 2. Handling modifier stacking (non-idempotent)
`client/apply.lua` applies **simultaneously**:
- `fInitialDriveForce *= stage * power`
- `SetVehicleEnginePowerMultiplier((mult.power - 1) * 100)`
- `SetVehicleEngineTorqueMultiplier(mult.torque)`
- `ModifyVehicleTopSpeed((mult.power - 1) * 22)`
- GTA performance mods via `applyHardware`

Re-applying tune without full baseline restore compounds changes. Baseline is captured on **first** `ApplyTune` call — if vehicle was already modified, baseline is wrong.

### 3. Client-only handling
`SetVehicleHandlingFloat` and engine multipliers run only on the applying client. `applyByPlate` broadcasts to all clients but each must receive the event; streaming players rely on bootstrap thread. No server-side handling state.

### 4. Invalid options exposed in UI
- All exhaust / anti-lag / turbo tabs shown for every vehicle.
- No bicycle / boat / aircraft block.
- No EV-specific tuning path.
- `SanitizeTune` auto-enables `turbo` when anti-lag or launch control is enabled.

### 5. Pops enabled without explicit opt-in
```lua
local popsOn = tune.pop.enabled or (tune.stage ~= 'civil')
EnableVehicleExhaustPops(veh, popsOn)
```
Sport/race stage enables pops even when player disabled pop & bang.

### 6. Preview vs persistence gaps
- Cancel restores saved tune (good).
- `ExportTuneForStore` skips unless `persistedPlates[plate]` — preview-only changes correctly not stored.
- Double apply on spawn (`sunset_vehicles` + `sunset:client:spawnOwnedVehicle` handler).

### 7. Server validation gaps
- `SanitizeTune` clamps numeric ranges but does **not** validate feature vs vehicle type.
- Client can POST arbitrary tune JSON; server only sanitizes bounds, not capability.

### 8. MDC / info mismatch
`GetVehicleTuningInfo` reads legacy `props.modEngine` top-level fields; current system stores mods in `props.ecu.hardware`.

## Database

No dedicated ECU table. Tune stored at:

```json
vehicles.props = {
  "ecu": { "stage", "power", "torque", "pop", "flames", "antiLag", ... },
  "cosmetics": { ... },
  "odometer": ...
}
```

**Decision:** Keep JSON persistence (matches garage architecture). Add `profileVersion` inside `ecu` for migration. No new SQL migration required unless future normalization demands it.

## Server obtainable vehicles (dealership)

`blista`, `issi2`, `prairie`, `asea`, `tailgater`, `buffalo`, `sultan`, `baller2`, `dubsta`, `bati`, `comet2`, `adder` (+ admin `/givecar` any model).

## Root cause summary

| Symptom | Cause |
|---------|--------|
| EV/bicycle get combustion options | No capability resolver |
| Stacking after respawn | Non-idempotent apply + wrong baseline |
| Supercar = compact tune | Universal stage multipliers |
| Pops on sport stage only | Stage-linked `EnableVehicleExhaustPops` |
| Other players different feel | Client-local handling natives |
| Extreme handling | Uncapped combined multipliers |

## Rewrite direction

1. `VehicleProfileResolver` — model → capabilities + limits  
2. `VehicleBaselineService` — immutable per-model baseline  
3. `VehicleTuneCalculator` — baseline + saved config → final handling (shared)  
4. `VehicleTuneApplicator` — idempotent client apply  
5. Server `ValidateTuneForProfile` before save  
6. NUI renders from `capabilities` object  
7. `/ecudebug` admin diagnostics  

See `docs/ECU_TUNER_IMPLEMENTATION.md` after implementation.
