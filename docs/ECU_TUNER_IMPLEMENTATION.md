# ECU Tuner — Implementation Summary

## What was wrong (old architecture)

- **Single generic multiplier path** in `client/apply.lua` — same stage/power for all models.
- **Stacking** — `fInitialDriveForce`, `SetVehicleEnginePowerMultiplier`, `ModifyVehicleTopSpeed` applied together; re-apply compounded changes.
- **No capability gate** — EV/bicycle/motorcycle saw identical UI and effects.
- **Baseline captured too late** — first apply could cache already-tuned handling.
- **Client-only** handling (FiveM limitation) — mitigated via `applyByPlate` broadcast + per-client idempotent apply from model baseline.
- **Server** only clamped numbers, not feature validity.

## New architecture

```
VehicleProfileResolver (shared/profile_resolver.lua + vehicle_profiles.lua)
        ↓ capabilities + limits
VehicleTuneValidator (shared/tune_validator.lua) — server save gate
        ↓
VehicleTuneCalculator (shared/tune_calculator.lua) — baseline + tune → handling
        ↓
VehicleBaselineService (client/baseline.lua) — per-model-hash immutable baseline
        ↓
VehicleTuneApplicator (client/apply.lua) — restore baseline → apply once (idempotent)
        ↓
VehicleTuneEffects (client/effects.lua) — exhaust FX gated by capabilities
```

**Persistence:** unchanged — `vehicles.props.ecu` JSON with `profileVersion: 2`.

**Migration:** v1 tunes auto-mapped in `SanitizeTune` (`migrateLegacyTune`) — power/torque 85–120 → 0–100 scale.

## Profile resolution order

1. `SunsetTuning.VehicleProfiles[model]` explicit override
2. Electric model list (`raiden`, `cyclone`, …)
3. Class archetype fallback (motorcycle, bicycle, super, …)
4. **Unknown addon** — performance allowed, combustion extras **disabled** until profile added

## Supported dealership vehicles

| Model | Propulsion | Induction | Max power % |
|-------|------------|-----------|-------------|
| blista | petrol | NA | 45 |
| issi2 | petrol | NA | 42 |
| prairie | petrol | NA | 48 |
| asea | petrol | NA | 50 |
| tailgater | petrol | NA | 58 |
| buffalo | petrol | NA | 62 |
| sultan | petrol | turbo | 68 |
| comet2 | petrol | NA | 72 |
| baller2 | petrol | NA | 55 |
| dubsta | petrol | NA | 58 |
| adder | petrol | NA | 85 |
| bati | petrol | NA | 70 (motorcycle UI subset) |

## Handling fields modified (and why)

| Field | Purpose |
|-------|---------|
| `fInitialDriveForce` | Primary acceleration (relative to baseline) |
| `fDriveInertia` | Torque response / rev feel |
| `fInitialDriveMaxFlatVel` | Top speed bias (trade vs acceleration) |
| `fTractionCurveMax/Min/Lateral` | Grip / drift |
| `fBrakeForce` | Brake upgrade + handling slider |
| `fSteeringLock` | Turn-in |
| `fSuspensionForce/ReboundDamp` | Stiffness |
| `fLowSpeedTractionLossMult` | Traction slider |
| `fClutchChangeRateScaleUp/Down` | Shift speed (combustion only) |

**Removed stacking:** `SetVehicleEnginePowerMultiplier` set to 0 for tuned maps; torque mult capped (~1.08 max).

## Adding a new add-on vehicle

Edit `shared/vehicle_profiles.lua`:

```lua
myaddon_car = {
    propulsion = 'petrol',
    induction = 'turbo',
    drivetrain = 'awd',
    archetype = 'sport',
    limits = { power = 70, topSpeed = 48, shiftSpeed = 75 },
},
```

Restart `sunset_tuning`. Until added, unknown models get safe defaults without pops/turbo/anti-lag.

## Commands

- `/ecudebug` — admin level 2+, in vehicle: model, profile, baseline, tune, applied handling

## Files created

- `docs/ECU_TUNER_AUDIT.md`
- `docs/ECU_TUNER_TEST_PLAN.md`
- `docs/ECU_TUNER_IMPLEMENTATION.md`
- `shared/vehicle_profiles.lua`
- `shared/profile_resolver.lua`
- `shared/tune_calculator.lua`
- `shared/tune_validator.lua`
- `client/baseline.lua`
- `client/diagnostics.lua`

## Files modified

- `shared/config.lua` — v2 schema, migration, caps-aware sanitize
- `client/apply.lua` — idempotent applicator
- `client/main.lua` — capabilities to NUI, model name, baseline capture
- `client/effects.lua` — capability gate for exhaust loop
- `server/main.lua` — validation + model in sync event
- `fxmanifest.lua` — shared modules, exports
- `web/app.js` — capability-driven tabs/sliders
- `web/index.html` — drivetrain label
- `sunset_vehicles/client/main.lua` — baseline capture before apply

## Known limitations (documented, not faked)

- GTA/FiveM handling natives are **client-side** — all clients must run `ApplyTune` when vehicle streams (existing broadcast + bootstrap).
- True rev-limiter RPM cap is not exposed as a reliable native — no fake rev-limiter slider effect beyond audio in anti-lag/2-step.
- Dyno HP remains an estimate from handling values, not chassis dyno simulation.

## Deploy

```
ensure sunset_tuning
ensure sunset_vehicles
```

No SQL migration required.
