# Sunset ECU — Exhaust Effects

Documentație tehnică pentru pop & bang, flăcări, diesel smoke și anti-lag.

## Nu folosim resurse externe

Totul rulează din **asset-uri native GTA V** încărcate la runtime cu `RequestNamedPtfxAsset`. Nu e nevoie de `bnExhaust`, `InteractSound` sau alte dependențe.

| Efect | PTFX Asset | Particle Name | Referință |
|-------|------------|---------------|-----------|
| Pop / backfire | `core` | `veh_backfire` | ak4y-hud Nitro, Advanced Nitro System |
| Flăcări nitro | `veh_xs_vehicle_mods` | `veh_nitrous` | Cfx.re forum — XS Vehicle Mods DLC |
| Flash flame | `core` | `ent_sht_flame` | Standard exhaust flame |
| Burnout puff | `scr_recartheft` | `scr_wheel_burnout` | Secondary flame visual |
| Diesel smoke | `core` | `exp_grd_bzgas_smoke` | Rolling coal style scripts |
| Thick smoke | `core` | `ent_amb_exhaust_thick` | RollCoal / diesel |

### Sunet

| Sunet | Soundset |
|-------|----------|
| `backfire` | `dlc_xs_vehicle_mods_sounds` |
| `Backfire` | `DLC_Tuner_Car_Meet_Sounds` |

## Implementare corectă (FiveM)

**Greșit** (nu apare vizual pentru alții / uneori deloc):
```lua
StartParticleFxNonLoopedOnEntityBone('veh_backfire', veh, 0,0,0, 0,0,0, bone, scale, ...)
```

**Corect** (pattern folosit în scripturi care funcționează):
```lua
local pos = GetWorldPositionOfEntityBone(veh, boneIndex)
local off = GetOffsetFromEntityGivenWorldCoords(veh, pos.x, pos.y, pos.z)
UseParticleFxAssetNextCall('core')
StartNetworkedParticleFxNonLoopedOnEntity('veh_backfire', veh, off.x, off.y, off.z, 0,0,0, scale, false, false, false)
```

Fișier: `client/exhaust_ptfx.lua`

## Când se declanșează efectele

| Feature | Condiție în joc |
|---------|-----------------|
| **Pop & bang** | RPM ridicat + eliberezi accelerația (lift-off) sau scădere bruscă RPM |
| **2-step** | Mașina stă pe loc, RPM > 78%, fără gaz |
| **Anti-lag** | Accelerație medie (W), RPM 22–90% |
| **Flăcări** | Tab Flammen/Extra Loud + toggle FLĂCĂRI, sau RPM mare cu gaz |
| **Diesel** | Mod evacuare Diesel, RPM mediu |
| **Flash la intrare** | La urcare în mașină cu ECU salvat — 3 burst-uri de confirmare |
| **Flash la save** | La salvare ECU cu flash — 5 burst-uri |

## Schema tune (`vehicles.props.ecu`)

```json
{
  "stage": "race",
  "power": 100,
  "torque": 100,
  "exhaust": "extra",
  "pop": { "enabled": true, "rpmMax": 95, "durationMs": 100, "secondBurst": true },
  "flames": { "enabled": true },
  "antiLag": { "enabled": true, "intensity": 100 },
  "drift": { "enabled": false },
  "hud": { "enabled": true },
  "dyno": { "lastHp": 980, "lastTorque": 1100 }
}
```

- `pop.enabled` — evacuare activă / pop & bang
- `flames.enabled` — flăcări (auto ON pentru `exhaust: flames` sau `extra`)
- `exhaust` — `pop_bang` | `flames` | `diesel` | `extra`

## Acces în joc

- **LS Customs HQ** (Mechanic) — [E] în vehicul → Reparație sau ECU Tuning
- **Harmony** — doar ECU Tuning
- Fără `/ecu`

## Fișiere

| Fișier | Rol |
|--------|-----|
| `client/exhaust_ptfx.lua` | Particule + sunet (layer jos) |
| `client/effects.lua` | Logică RPM/throttle, anti-lag, sync |
| `client/bootstrap.lua` | Încarcă ECU la intrare în vehicul |
| `client/apply.lua` | Handling / putere motor |
| `server/main.lua` | `syncExhaustFx` pentru jucători din zonă |

## Test rapid

1. Intră pe Zentorno cu ECU salvat → ar trebui 3 pop-uri la ~0.6s după intrare
2. Ține W până la RPM 80%+, apoi lasă — pop & bang
3. La loc, RPM sus fără gaz — 2-step pops
4. Anti-lag ON + W la RPM mediu — pop-uri rapide continue
