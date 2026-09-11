# ECU Tuner — Test Plan

## Vehicle matrix

| Vehicle | Model | Expected profile | Must NOT show |
|---------|-------|------------------|---------------|
| Blista | `blista` | Petrol compact | EV regen, turbo (NA) |
| Sultan | `sultan` | Turbo petrol | EV regen |
| Adder | `adder` | Super NA | Turbo/anti-lag without turbo install |
| Bati | `bati` | Motorcycle | Full car exhaust tabs |
| Bicycle | any cycle class | **Blocked** | Entire ECU UI |
| Raiden | `raiden` | Electric | Pops, flames, turbo, anti-lag |
| Unknown addon | unlisted model | Conservative | Pops, flames, anti-lag, turbo |

## Functional tests

### Tuning lifecycle
1. Open LSC ECU on owned `sultan`
2. Change power slider → preview immediate
3. Cancel → handling restored to saved tune
4. Save → bank charged, tune in DB
5. Store vehicle in garage
6. Respawn → same tune applied
7. `/ecudebug` shows baseline + applied values

### Idempotency
1. Apply tune on spawn
2. Re-enter vehicle / resource restart `ensure sunset_tuning`
3. Run `/ecudebug` twice — applied `driveForce` identical

### Server validation
1. Attempt save with `antiLag.enabled` on `blista` (NA) via modified NUI — rejected
2. Attempt save pops on `raiden` — rejected

### Networking
1. Player A saves tune
2. Player B streams same vehicle — tune applied via `applyByPlate`
3. Exhaust FX visible to nearby players when pops enabled

### Presets
1. Stage 1 on `blista` vs `adder` — different absolute `driveForce` delta (same slider %)

## Dev measurements (optional)
- `/ecudebug` after stage changes
- Compare `fInitialDriveMaxFlatVel` before/after top speed bias

## Regression
- Cosmetics / vanity plate still save
- Dyno session still charges and persists HP
- Mechanic repair menu unchanged
- Garage ECU info strip in `/v` menu
