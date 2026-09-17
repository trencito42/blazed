--- Nitrous Oxide (NOS) Controller
--- Dedicated, persistent nitrous injection subsystem with progressive torque delivery,
--- layered exhaust plume PTFX, 3D entity audio, and network synchronization.

local STC = SunsetTuningClient
local EP = STC.ExhaustPtfx

local isNosPressed = false
local isNosActive = false
local currentVeh = 0
local rampFactor = 0.0
local activePtfx = {}
local activeSoundId = nil
local lastSyncState = false

-- Runtime bottle charges: [veh] = number 0.0-100.0
local bottles = {}

-- Remote vehicle NOS states: [netId] = { active = bool, color = table, ptfx = table }
local remoteVehicles = {}

local DRAIN_RATES = {
    [1] = 8.33,   -- ~12.0 seconds total capacity
    [2] = 11.11,  -- ~9.0 seconds total capacity
    [3] = 14.28,  -- ~7.0 seconds total capacity
}

local RECHARGE_RATE = 1.6  -- % per second when engine on and NOS not firing

local BOOST_TIERS = {
    [1] = { power = 1.22, torque = 1.20 },
    [2] = { power = 1.38, torque = 1.35 },
    [3] = { power = 1.55, torque = 1.50 },
}

local function clearLocalPtfx()
    for _, handle in ipairs(activePtfx) do
        if DoesParticleFxLoopedExist(handle) then
            StopParticleFxLooped(handle, false)
        end
    end
    activePtfx = {}
end

local function stopLocalNosSound()
    if activeSoundId then
        pcall(function()
            StopSound(activeSoundId)
            ReleaseSoundId(activeSoundId)
        end)
        activeSoundId = nil
    end
end

local function startLocalNosSound(veh)
    if activeSoundId then return end
    pcall(function()
        activeSoundId = GetSoundId()
        PlaySoundFromEntity(activeSoundId, 'tuner_hatch02_limiter_pops', veh, 'DLC_TUNER_CAR_MEET_SOUNDS', true, 0)
    end)
end

local function spawnNosFlameLayers(veh, color)
    clearLocalPtfx()
    if not EP.ensureAssets() then return end
    if not HasNamedPtfxAssetLoaded('veh_xs_vehicle_mods') then return end

    local c = EP.normalizeColor(color or { r = 50, g = 120, b = 255 })
    EP.eachExhaustBone(veh, function(bone, off, pos)
        -- Layer 1: Outer tinted nitrous jet
        UseParticleFxAssetNextCall('veh_xs_vehicle_mods')
        local outer = StartParticleFxLoopedOnEntityBone(
            'veh_nitrous', veh,
            0.0, -0.18, 0.0,
            0.0, 0.0, 0.0,
            bone, 0.75, false, false, false
        )
        if outer and outer ~= 0 then
            SetParticleFxLoopedColour(outer, c.r / 255.0, c.g / 255.0, c.b / 255.0, false)
            SetParticleFxLoopedAlpha(outer, 0.95)
            activePtfx[#activePtfx + 1] = outer
        end

        -- Layer 2: Hot white/ice core jet
        UseParticleFxAssetNextCall('veh_xs_vehicle_mods')
        local core = StartParticleFxLoopedOnEntityBone(
            'veh_nitrous', veh,
            0.0, -0.10, 0.0,
            0.0, 0.0, 0.0,
            bone, 0.42, false, false, false
        )
        if core and core ~= 0 then
            SetParticleFxLoopedColour(core, 0.85, 0.95, 1.0, false)
            SetParticleFxLoopedAlpha(core, 0.85)
            activePtfx[#activePtfx + 1] = core
        end
    end)
end

local function stopLocalNos(veh, tune)
    if not isNosActive and rampFactor <= 0.0 then return end
    isNosActive = false
    clearLocalPtfx()
    stopLocalNosSound()

    if veh and veh ~= 0 and DoesEntityExist(veh) then
        local state = STC.appliedVehicles[veh]
        local mult = state and state.mult or (tune and STC.getStageMultipliers(tune))
        local baseP = mult and mult.power or 1.0
        local baseT = mult and mult.torque or 1.0
        SetVehicleEnginePowerMultiplier(veh, baseP)
        SetVehicleEngineTorqueMultiplier(veh, baseT)

        if NetworkGetEntityIsNetworked(veh) and lastSyncState then
            lastSyncState = false
            TriggerServerEvent('sunset:tuning:syncNosState', VehToNet(veh), false)
        end
    end
end

-- Key mapping for Nitrous (+nitrous / -nitrous)
RegisterKeyMapping('+nitrous', 'Nitrous Oxide Boost', 'keyboard', 'LSHIFT')

RegisterCommand('+nitrous', function()
    isNosPressed = true
end, false)

RegisterCommand('-nitrous', function()
    isNosPressed = false
end, false)

-- Local player nitrous controller loop
CreateThread(function()
    local lastTick = GetGameTimer()

    while true do
        Wait(0)
        local now = GetGameTimer()
        local deltaSec = math.max(0.001, math.min(0.1, (now - lastTick) / 1000.0))
        lastTick = now

        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            if isNosActive then stopLocalNos(currentVeh, nil) end
            currentVeh = 0
            rampFactor = 0.0
            Wait(300)
            goto continue
        end

        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then
            if isNosActive then stopLocalNos(currentVeh, nil) end
            currentVeh = 0
            rampFactor = 0.0
            Wait(250)
            goto continue
        end

        currentVeh = veh
        local state = STC.appliedVehicles[veh]
        local tune = state and state.tune
        local isNosInstalled = tune and tune.nitrous and tune.nitrous.installed == true

        if not isNosInstalled then
            if isNosActive then stopLocalNos(veh, tune) end
            rampFactor = 0.0
            Wait(350)
            goto continue
        end

        local bottle = bottles[veh] or 100.0
        local tier = math.max(1, math.min(3, tune.nitrous.level or 1))
        local drainRate = DRAIN_RATES[tier] or 10.0
        local boostSpec = BOOST_TIERS[tier] or BOOST_TIERS[1]

        local engineRunning = GetIsVehicleEngineRunning(veh)
        local throttle = GetControlNormal(0, 71)
        local isAirborne = IsEntityInAir(veh)
        local speed = GetEntitySpeed(veh) * 3.6
        local gear = GetVehicleCurrentGear(veh)

        local canEngage = isNosPressed
            and engineRunning
            and bottle > 0.0
            and not isAirborne
            and throttle > 0.45
            and gear > 0
            and speed > 5.0

        if canEngage then
            if not isNosActive then
                isNosActive = true
                spawnNosFlameLayers(veh, tune.nitrous.color)
                startLocalNosSound(veh)
                if NetworkGetEntityIsNetworked(veh) and not lastSyncState then
                    lastSyncState = true
                    TriggerServerEvent('sunset:tuning:syncNosState', VehToNet(veh), true, tune.nitrous.color, tier)
                end
            end

            -- Progressive torque/power ramp over ~200ms
            rampFactor = math.min(1.0, rampFactor + (deltaSec / 0.20))

            -- Bottle consumption
            bottle = math.max(0.0, bottle - (drainRate * deltaSec))
            bottles[veh] = bottle

            if bottle <= 0.0 then
                -- Sudden bottle empty: sputter and disengage
                EP.burst(veh, 'crackle', 0.65, tune.nitrous.color, false)
                stopLocalNos(veh, tune)
            end
        else
            if isNosActive then
                stopLocalNos(veh, tune)
            end

            -- Ramp back down smoothly
            if rampFactor > 0.0 then
                rampFactor = math.max(0.0, rampFactor - (deltaSec / 0.12))
            end

            -- Passive recharge when cruising/idle with engine on
            if engineRunning and bottle < 100.0 then
                bottle = math.min(100.0, bottle + (RECHARGE_RATE * deltaSec))
                bottles[veh] = bottle
            end
        end

        -- Apply progressive engine multipliers
        if rampFactor > 0.001 then
            local mult = state and state.mult or STC.getStageMultipliers(tune)
            local baseP = mult and mult.power or 1.0
            local baseT = mult and mult.torque or 1.0
            local effP = baseP * (1.0 + (boostSpec.power - 1.0) * rampFactor)
            local effT = baseT * (1.0 + (boostSpec.torque - 1.0) * rampFactor)
            SetVehicleEnginePowerMultiplier(veh, effP)
            SetVehicleEngineTorqueMultiplier(veh, effT)

            -- Light illumination behind exhaust tips
            local pos = GetEntityCoords(veh)
            local forward = GetEntityForwardVector(veh)
            local lightPos = pos - forward * 2.2
            local col = tune.nitrous.color or { r = 50, g = 120, b = 255 }
            DrawLightWithRange(lightPos.x, lightPos.y, lightPos.z + 0.2, col.r, col.g, col.b, 3.5, 4.0 * rampFactor)
        end

        ::continue::
    end
end)

-- Network sync handler for remote vehicles
RegisterNetEvent('sunset:tuning:client:nosState', function(netId, active, color, tier)
    netId = tonumber(netId)
    if not netId or netId == 0 then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if veh == currentVeh and isNosActive then return end -- Own vehicle already handled locally

    local remote = remoteVehicles[netId] or { ptfx = {} }
    remoteVehicles[netId] = remote

    if active then
        -- Clear old effects if any
        for _, handle in ipairs(remote.ptfx) do
            if DoesParticleFxLoopedExist(handle) then StopParticleFxLooped(handle, false) end
        end
        remote.ptfx = {}

        if EP.ensureAssets() and HasNamedPtfxAssetLoaded('veh_xs_vehicle_mods') then
            local c = EP.normalizeColor(color or { r = 50, g = 120, b = 255 })
            EP.eachExhaustBone(veh, function(bone)
                UseParticleFxAssetNextCall('veh_xs_vehicle_mods')
                local outer = StartParticleFxLoopedOnEntityBone(
                    'veh_nitrous', veh,
                    0.0, -0.18, 0.0,
                    0.0, 0.0, 0.0,
                    bone, 0.70, false, false, false
                )
                if outer and outer ~= 0 then
                    SetParticleFxLoopedColour(outer, c.r / 255.0, c.g / 255.0, c.b / 255.0, false)
                    SetParticleFxLoopedAlpha(outer, 0.90)
                    table.insert(remote.ptfx, outer)
                end
            end)
        end
    else
        for _, handle in ipairs(remote.ptfx) do
            if DoesParticleFxLoopedExist(handle) then StopParticleFxLooped(handle, false) end
        end
        remote.ptfx = {}
    end
end)

-- Export for HUD and Speedometer telemetry
exports('GetNitrousHudState', function(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local state = STC.appliedVehicles[veh]
    local tune = state and state.tune
    if not tune or not tune.nitrous or not tune.nitrous.installed then
        return { installed = false, active = false, level = 0, tier = 1 }
    end

    local bottle = bottles[veh] or 100.0
    return {
        installed = true,
        active = isNosActive and currentVeh == veh,
        level = math.floor(bottle),
        tier = tune.nitrous.level or 1,
        color = tune.nitrous.color or { r = 50, g = 120, b = 255 },
    }
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    clearLocalPtfx()
    stopLocalNosSound()
    if currentVeh and currentVeh ~= 0 and DoesEntityExist(currentVeh) then
        SetVehicleEnginePowerMultiplier(currentVeh, 1.0)
        SetVehicleEngineTorqueMultiplier(currentVeh, 1.0)
    end
    for _, remote in pairs(remoteVehicles) do
        for _, handle in ipairs(remote.ptfx or {}) do
            if DoesParticleFxLoopedExist(handle) then StopParticleFxLooped(handle, false) end
        end
    end
end)
