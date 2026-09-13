-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield (server/detectors.lua)
--  Phase 1 detector engine: ONE 1 Hz loop over GetPlayers()
--  (spec §10 perf: never per-player timers). Detectors:
--    speed_check    §4.1  server coords delta vs vehicle-class ceiling
--    teleport_check §4.2  on-foot instant coord jump > 150 m in 1 s
--    fly_check      §4.3  sustained Z ascent corroborated by client sampler
--    health_check   §4.5  HP/armor jumps without MarkLegit('health')
--    damage_check   §4.4  independent weaponDamageEvent handler
--    spam_check     §4.10 clientTick event flood (>60/min)
--    heartbeat      §4.14 nonce heartbeat, missing 3 = flag
--  EVERY detector calls Context.IsLegit FIRST and respects cooldowns.
--  Client telemetry is ADVISORY only (spec §1.5): nothing here
--  solo-convicts on a client-reported value without server state.
-- ═══════════════════════════════════════════════════════════════

local Detectors = {}
Anticheat.Detectors = Detectors

local Cfg = SunsetAnticheat.Config
local ClassMax = SunsetAnticheat.ClassMaxSpeed
local Context = Anticheat.Context
local Strikes = Anticheat.Strikes

local LastSample = {}    -- [src] = { x, y, z, vehClass, at }
local SpeedSustain = {}  -- [src] = consecutive over-limit samples
local FlyAscent = {}     -- [src] = { streak = n, lastZ }
local HealthSnap = {}    -- [src] = { hp, armour, at }
local DamageWin = {}     -- [src] = { total, hpAtStart, armourAtStart, openedAt }
local Cooldown = {}      -- [src] = { [detector] = readyAt }
local SpamCount = {}     -- [src] = { window = at, count = n }
local Nonces = {}        -- [src] = { expected = n, missed = n, ackAt }
local LastTick = {}      -- [src] = os.time() of last clientTick (silence detection)
local Telemetry = {}     -- [src] = last client sampler payload (advisory)

local function now() return os.time() end

-- Detector event names ('speed_check') map to config keys ('speed').
local CFG_KEY = {
    speed_check = 'speed',
    teleport_check = 'teleport',
    fly_check = 'fly',
    damage_check = 'damage',
    health_check = 'health',
    vehicle_spawn_check = 'vehspawn',
    spam_check = 'spam',
    heartbeat_check = 'heartbeat',
}

-- Spec cooldowns for detectors whose config entry carries no cooldown field.
local DEFAULT_COOLDOWN = {
    spam_check = 300,
    heartbeat_check = 300,
    speed_check = 60,
    teleport_check = 30,
    fly_check = 120,
    damage_check = 60,
    health_check = 60,
}

local function detectorCfg(name)
    return Cfg.Detectors[CFG_KEY[name] or name] or {}
end

local function detectorEnabled(name)
    local cfg = detectorCfg(name)
    return cfg.enabled ~= false and cfg.logOnly ~= true
end

local function onCooldown(src, name)
    local entry = Cooldown[src]
    if entry and entry[name] and now() < entry[name] then return true end
    return false
end

local function setCooldown(src, name)
    local cd = tonumber(detectorCfg(name).cooldown) or DEFAULT_COOLDOWN[name] or 60
    Cooldown[src] = Cooldown[src] or {}
    Cooldown[src][name] = now() + cd
end

-- Detector names ('speed_check') map to Context check types ('speed').
local CHECK_TYPE = {
    speed_check = 'speed',
    teleport_check = 'teleport',
    fly_check = 'fly',
    damage_check = 'damage',
    health_check = 'health',
    vehicle_spawn_check = 'vehicle_spawn',
    spam_check = 'spam',
    heartbeat_check = 'heartbeat',
}

local function fire(src, detector, severity, measured)
    if onCooldown(src, detector) then return end
    if Context.IsLegit(src, CHECK_TYPE[detector] or detector) then return end
    setCooldown(src, detector)
    Strikes.AddTick(src, detector, severity, measured, Context.Snapshot(src))
end

local function clearPlayer(src)
    LastSample[src] = nil
    SpeedSustain[src] = nil
    FlyAscent[src] = nil
    HealthSnap[src] = nil
    DamageWin[src] = nil
    Cooldown[src] = nil
    SpamCount[src] = nil
    Nonces[src] = nil
    LastTick[src] = nil
    Telemetry[src] = nil
end

AddEventHandler('playerDropped', function()
    clearPlayer(source)
end)

-- ── Vehicle helpers (server natives available in CfxLua server) ──
local function playerVehicle(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 0 end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return 0 end
    return veh
end

local function vehClassExempt(class)
    -- 14 boat, 15 heli, 16 plane, 21 train: exempt entirely (spec §4.1)
    return class == 14 or class == 15 or class == 16 or class == 21
end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return c.x, c.y, c.z
end

-- ══════════════ §4.1 speed_check (1 Hz, per-player sample) ══════════════
local function speedCheck(src, dt)
    if not detectorEnabled('speed') then return end
    local x, y, z = coordsOf(src)
    if not x then LastSample[src] = nil return end

    local veh = playerVehicle(src)
    local inVeh = veh ~= 0
    local vehClass = inVeh and (GetVehicleClass(veh) or 1) or nil
    local prev = LastSample[src]
    LastSample[src] = { x = x, y = y, z = z, veh = inVeh, class = vehClass, at = now() }
    if not prev then SpeedSustain[src] = nil return end

    -- Only judge vehicles here; on-foot movement is teleport_check's job.
    if not inVeh then SpeedSustain[src] = nil return end
    if vehClassExempt(vehClass) then SpeedSustain[src] = nil return end
    -- Class change between samples (entered/exited, OneSync swap): resync.
    if prev.class ~= vehClass then SpeedSustain[src] = nil return end

    local classMax = ClassMax[vehClass]
    if not classMax then SpeedSustain[src] = nil return end

    local margin = detectorCfg('speed').margin or 1.35
    local limit = classMax * margin
    local dist = math.sqrt((x - prev.x) ^ 2 + (y - prev.y) ^ 2 + (z - prev.z) ^ 2)
    local elapsed = math.max(dt, 0.2)
    local speed = dist / elapsed

    if speed > limit then
        SpeedSustain[src] = (SpeedSustain[src] or 0) + 1
        local sustain = detectorCfg('speed').sustainSamples or 3
        if SpeedSustain[src] >= sustain then
            fire(src, 'speed_check', 2, ('%.1f m/s vs limit %.0f (class %d, %.2fx margin, %d samples)'):format(
                speed, limit, vehClass, margin, SpeedSustain[src]))
            SpeedSustain[src] = 0
        end
    else
        SpeedSustain[src] = 0
    end
end

-- ══════════════ §4.2 teleport_check (on foot > 150 m in 1 s) ══════════════
local function teleportCheck(src, prev)
    if not detectorEnabled('teleport') then return end
    if not prev then return end
    if prev.veh then return end -- vehicles get speed_check instead
    if playerVehicle(src) ~= 0 then return end
    local cur = LastSample[src]
    if not cur then return end
    local dist = math.sqrt((cur.x - prev.x) ^ 2 + (cur.y - prev.y) ^ 2 + (cur.z - prev.z) ^ 2)
    if dist > 150.0 then
        fire(src, 'teleport_check', 2, ('on-foot jump %.0f m in %ds (%.0f,%.0f,%.0f -> %.0f,%.0f,%.0f)'):format(
            dist, math.max(1, cur.at - prev.at), prev.x, prev.y, prev.z, cur.x, cur.y, cur.z))
    end
end

-- ══════════════ §4.3 fly_check (client sampler + server Z corroboration) ══════════════
-- Client reports IsPedFalling/ragdoll/parachute/swimming + Z velocity (advisory);
-- server corroborates with its OWN tracked Z ascent. Never solo-convicts on
-- the client claim alone — the server Z delta is the evidence.
local function flyCheck(src, prev)
    if not detectorEnabled('fly') then return end
    if playerVehicle(src) ~= 0 then FlyAscent[src] = nil return end
    local cur = LastSample[src]
    if not cur or not prev then FlyAscent[src] = nil return end

    local tel = Telemetry[src]
    local zVel = (cur.z - prev.z) / math.max(1, cur.at - prev.at)

    -- Client-reported legit flight states suppress the server ascent streak.
    if tel and (tel.falling or tel.ragdoll or tel.swimming or tel.inVehicle
        or (tel.parachute and tel.parachute >= 1)) then
        FlyAscent[src] = nil
        return
    end

    if zVel > 3.0 then
        FlyAscent[src] = (FlyAscent[src] or 0) + 1
        if FlyAscent[src] >= 5 then
            fire(src, 'fly_check', 3, ('sustained ascent %.1f m/s for %d samples on foot (no vehicle/fall/parachute/ragdoll)'):format(
                zVel, FlyAscent[src]))
            FlyAscent[src] = nil
        end
    else
        FlyAscent[src] = nil
    end
end

-- ══════════════ §4.5 health_check (0.2 Hz → sampled every 5th tick) ══════════════
local function healthCheck(src)
    if not detectorEnabled('health') then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local hp = GetEntityHealth(ped) or 0
    local armour = GetPedArmour(ped) or 0
    local snap = HealthSnap[src]
    HealthSnap[src] = { hp = hp, armour = armour, at = now() }
    if not snap then return end

    local hpJump = hp - snap.hp
    local armourJump = armour - snap.armour
    local age = now() - snap.at
    -- Instant HP jump (+50 in < 2 samples ≈ <10 s here) with no heal source.
    -- Legit heals must MarkLegit(src, 'health', 5) — EMS/bandage/hospital/admin.
    if hpJump >= 50 and age <= 10 and not Context.IsLegit(src, 'health') and not onCooldown(src, 'health_check') then
        fire(src, 'health_check', 3, ('HP %+d (%d -> %d) in %ds, armour %+d, no MarkLegit(health) source'):format(
            hpJump, snap.hp, hp, age, armourJump))
    elseif armourJump >= 50 and age <= 10 and not Context.IsLegit(src, 'health') and not onCooldown(src, 'health_check') then
        fire(src, 'health_check', 2, ('armour %+d (%d -> %d) in %ds, no MarkLegit(health) source'):format(
            armourJump, snap.armour, armour, age))
    end
end

-- ══════════════ §4.4 damage_check (independent weaponDamageEvent) ══════════════
-- Own handler in own resource — does NOT touch or resurrect the
-- sunset_licenses gate (spec §10: weaponDamageEvent is shared; additive
-- AddEventHandler is safe). Player-sourced damage only; tracks cumulative
-- incoming damage vs combined HP+armour loss over a 10 s window.
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not detectorEnabled('damage') then return end
    if type(data) ~= 'table' then return end
    local victimNet = tonumber(data.hitGlobalId)
    if not victimNet or victimNet == 0 then return end
    local victimEnt = NetworkGetEntityFromNetworkId(victimNet)
    if not victimEnt or victimEnt == 0 or not IsPedAPlayer(victimEnt) then return end

    local victimSrc = nil
    for _, pid in ipairs(GetPlayers()) do
        local s = tonumber(pid)
        if s and s ~= sender and GetPlayerPed(s) == victimEnt then
            victimSrc = s
            break
        end
    end
    if not victimSrc then return end

    local ped = victimEnt
    local hp = GetEntityHealth(ped) or 0
    local armour = GetPedArmour(ped) or 0
    local dmg = tonumber(data.weaponDamage) or tonumber(data.damage) or 0
    if dmg <= 0 then return end

    local win = DamageWin[victimSrc]
    local t = now()
    if not win or (t - win.openedAt) > 10 then
        DamageWin[victimSrc] = { total = dmg, combinedAtStart = hp + armour, openedAt = t }
        return
    end
    win.total = win.total + dmg
    local combinedLoss = win.combinedAtStart - (hp + armour)
    if win.total > 500 and combinedLoss < (win.combinedAtStart * 0.10) then
        fire(victimSrc, 'damage_check', 3, ('took %.0f cumulative damage in %ds but HP+armour only dropped %.0f (was %d, now %d)'):format(
            win.total, t - win.openedAt, math.max(0, combinedLoss), win.combinedAtStart, hp + armour))
        DamageWin[victimSrc] = nil
    end
end)

-- ══════════════ §4.10 spam_check + §4.14 heartbeat (clientTick event) ══════════════
RegisterNetEvent('sunset:anticheat:clientTick', function(payload)
    local src = source
    if not Cfg.Enabled then return end
    LastTick[src] = now()

    -- Spam: > 60 clientTick events/min = tick (sampler is 1 Hz = 60/min legit).
    if detectorEnabled('spam') then
        local t = now()
        local sc = SpamCount[src]
        if not sc or (t - sc.window) >= 60 then
            sc = { window = t, count = 0 }
            SpamCount[src] = sc
        end
        sc.count = sc.count + 1
        if sc.count > 75 then
            fire(src, 'spam_check', 1, ('%d clientTick events in 60s (sampler is 60/min)'):format(sc.count))
        end
    end

    if type(payload) ~= 'table' then return end

    -- Heartbeat nonce: payload must echo the rotating nonce we acked with.
    if detectorEnabled('heartbeat') then
        local n = Nonces[src]
        if n then
            if tonumber(payload.nonce) == n.expected then
                n.missed = 0
            else
                n.missed = n.missed + 1
                if n.missed >= 3 then
                    fire(src, 'heartbeat_check', 2,
                        ('client module not responding: %d missed nonce heartbeats (last ok %ds ago)'):format(
                            n.missed, now() - (n.ackAt or now())))
                end
            end
        end
        Nonces[src] = Nonces[src] or { expected = 0, missed = 0, ackAt = now() }
        Nonces[src].expected = math.random(100000, 999999)
        Nonces[src].ackAt = now()
        TriggerClientEvent('sunset:anticheat:tickAck', src, Nonces[src].expected)
    end

    -- Store advisory telemetry for fly corroboration (server Z is the evidence).
    Telemetry[src] = {
        speed = tonumber(payload.speed) or 0.0,
        falling = payload.falling == true,
        inVehicle = payload.inVehicle == true,
        swimming = payload.swimming == true,
        ragdoll = payload.ragdoll == true,
        parachute = tonumber(payload.parachute) or 0,
        fps = tonumber(payload.fps) or 0,
        at = now(),
    }
end)

-- ══════════════ §4.14 heartbeat silence (sampler stopped entirely) ══════════════
-- Nonce mismatch above catches forged/replayed ticks; total silence catches a
-- stopped sampler. Only fires for players with a loaded character (not while
-- loading/respawning) and never kicks — staff flag only (spec §4.14).
local function heartbeatSilenceCheck(src)
    if not detectorEnabled('heartbeat') then return end
    local last = LastTick[src]
    if not last then
        -- First sighting: seed the clock, don't judge (player may be loading).
        LastTick[src] = now()
        return
    end
    if now() - last < 30 then return end  -- 3 missed 10 s heartbeats
    local hasChar = false
    if GetResourceState('sunset_core') == 'started' then
        pcall(function() hasChar = exports.sunset_core:GetCharacter(src) ~= nil end)
    end
    if not hasChar then LastTick[src] = now() return end
    fire(src, 'heartbeat_check', 2, ('client module silent: no telemetry for %ds while connected with loaded character'):format(now() - last))
    LastTick[src] = now() -- reset window; cooldown prevents repeats
end

-- ══════════════ The ONE 1 Hz loop (spec §10 perf budget) ══════════════
local healthCounter = 0
CreateThread(function()
    Wait(8000) -- let spawn/character load settle before first sample
    while Cfg.Enabled do
        Wait(1000)
        local ok, err = pcall(function()
            healthCounter = healthCounter + 1
            local runHealth = (healthCounter % 5) == 0  -- 0.2 Hz per spec §4.5
            for _, id in ipairs(GetPlayers()) do
                local src = tonumber(id)
                if src then
                    local ped = GetPlayerPed(src)
                    if ped and ped ~= 0 then
                        local prev = LastSample[src]
                        local prevCopy = prev and { x = prev.x, y = prev.y, z = prev.z, veh = prev.veh, class = prev.class, at = prev.at } or nil
                        speedCheck(src, 1.0)
                        teleportCheck(src, prevCopy)
                        flyCheck(src, prevCopy)
                        if runHealth then healthCheck(src) end
                    end
                    heartbeatSilenceCheck(src)
                end
            end
        end)
        if not ok then
            print(('^1[sunset_anticheat]^7 detector loop error: %s'):format(tostring(err)))
        end
    end
end)

-- Accessor for the panel (FPS/ping quick stats, spec §6.2).
function Detectors.GetTelemetry(src)
    return Telemetry[tonumber(src or 0)]
end
