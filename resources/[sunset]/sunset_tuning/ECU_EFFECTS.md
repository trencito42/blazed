# Sunset Performance — ECU, hardware and exhaust

## What the system installs

The saved map remains backward-compatible in `vehicles.props.ecu`, but now contains two distinct layers:

- GTA V hardware mods: engine, brakes, transmission, suspension, armor and turbo.
- Fine calibration: power, torque, steering, brake force, suspension response and traction.
- Exhaust: overrun pop & bang, flames, diesel smoke, anti-lag and launch-control/2-step.
- Per-vehicle dyno history, ECU HUD and drift setup.

The UI offers Factory, Street, Track and Drift starting builds. Every control can then be adjusted individually. Hardware levels are clamped to the number of mods supported by the current model.

## Exhaust implementation

Particles use native GTA V assets (`core/veh_backfire`, `veh_xs_vehicle_mods/veh_nitrous` and `core/ent_sht_metal`). They are attached to every valid `exhaust`, `exhaust_2` … `exhaust_16` bone. Sounds use the GTA Tuner and XS Vehicle Mods audio banks.

The origin client renders one local burst. It sends only the vehicle network ID and requested effect to the server; the server verifies the sender is the driver, owns that exact vehicle, has a compatible saved map and respects the rate limit. Only then are nearby clients asked to render their local copy. No explosion native is used as an audio workaround.

| Effect | Trigger |
| --- | --- |
| Pop & bang | throttle lift after high RPM, followed by a short RPM-dependent overrun sequence |
| 2-step | launch control installed, vehicle almost stationary and high RPM |
| Anti-lag | turbo/anti-lag installed and a throttle blip inside the spool range |
| Sparks | strong 2-step or anti-lag bursts only |
| Flames | explicit flames/extra exhaust configuration |
| Diesel smoke | diesel exhaust at low/medium RPM |

## Persistence and pricing

The server sanitizes the complete tune, verifies driver seat, plate, ownership and workshop proximity, calculates the install price from the old saved build, removes money, and refunds it if the database update fails. The UI quote mirrors the same calculation but is informational; the server total is authoritative.

Dyno runs use a paid, single-use session token. The dyno can no longer be abused to save an unsold draft tune for the cheaper dyno fee. The saved build is measured and the token expires after the run window.

## Runtime files

| File | Responsibility |
| --- | --- |
| `shared/config.lua` | schema, limits, hardware slots and authoritative price calculation |
| `client/apply.lua` | actual GTA mod slots and reversible handling changes |
| `client/effects.lua` | RPM/throttle state machine and nearby synchronization request |
| `client/exhaust_ptfx.lua` | exhaust-bone particles, sparks and layered native audio |
| `client/dyno.lua` | in-place dyno sequence and measurement |
| `server/main.lua` | ownership/shop validation, persistence, pricing, dyno sessions and FX security |

## Manual QA

1. Open the shop in an owned car and verify unsupported hardware levels are disabled.
2. Apply each quick build, cancel, and confirm the original handling/mods return.
3. Save a build, store/retrieve the car and reconnect; hardware, handling and effects must return.
4. Rev above the configured threshold, release throttle and check that pops follow RPM decay instead of looping constantly.
5. Confirm 2-step is silent until Launch Control is installed, and anti-lag forces turbo installation.
6. Observe the same exhaust burst with a second nearby player; it must render once per client.
7. Try save/dyno away from the shop, from the passenger seat, with another player's plate, and with insufficient bank money.
8. Start a dyno and cancel/fail it; the fee must be refunded. Complete it and confirm the token cannot be reused.
