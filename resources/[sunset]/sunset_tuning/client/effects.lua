local STC = SunsetTuningClient

local ptfxReady = false
local lastThrottle = 0.0
local lastRpm = 0.0
local popCooldown = 0

local PTFX = {
    { asset = 'core', name = 'veh_backfire' },
    { asset = 'core', name = 'ent_sht_flame' },
    { asset = 'core', name = 'exp_grd_bzgas_smoke' },
    { asset = 'core', name = 'ent_sht_electrical_box' },
    { asset = 'scr_recartheft', name = 'scr_wheel_burnout' },
    { asset = 'scr_trevor1', name = 'scr_trev1_trailer_boosh' },
}

local function ensurePtfx()
    if ptfxReady then return true end
    for _, fx in ipairs(PTFX) do
        RequestNamedPtfxAsset(fx.asset)
    end
    local timeout = GetGameTimer() + 8000
    while GetGameTimer() < timeout do
        local all = true
        for _, fx in ipairs(PTFX) do
            if not HasNamedPtfxAssetLoaded(fx.asset) then
                all = false
                break
            end
        end
        if all then
            ptfxReady = true
            return true
        end
        Wait(10)
    end
    return HasNamedPtfxAssetLoaded('core')
end

CreateThread(function()
    ensurePtfx()
end)

local function eachExhaustBone(veh, fn)
    local bones = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4', 'engine', 'bumper_r', 'boot' }
    for _, name in ipairs(bones) do
        local bone = GetEntityBoneIndexByName(veh, name)
        if bone ~= -1 then fn(bone, name) end
    end
end

local function exhaustCoords(veh, bone)
    return GetWorldPositionOfEntityBone(veh, bone)
end

local function playPopSound(veh, intensity)
    local soundId = GetSoundId()
    PlaySoundFromEntity(soundId, 'Backfire', veh, 'DLC_Tuner_Car_Meet_Sounds', false, 0)
    ReleaseSoundId(soundId)
    if intensity > 0.55 then
        local sid2 = GetSoundId()
        PlaySoundFromEntity(sid2, 'Crash', veh, 'DLC_HEIST_FLEECA_SOUNDSET', false, 0)
        ReleaseSoundId(sid2)
    end
end

function STC.PlayExhaustFx(veh, fxType, intensity)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not ensurePtfx() then return end
    intensity = math.max(0.25, math.min(1.0, tonumber(intensity) or 0.65))

    if fxType == 'pop' or fxType == 'antilag' then
        eachExhaustBone(veh, function(bone)
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedOnEntityBone('veh_backfire', veh, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, 1.25 * intensity, false, false, false)
            UseParticleFxAssetNextCall('scr_trevor1')
            StartParticleFxNonLoopedOnEntityBone('scr_trev1_trailer_boosh', veh, 0.0, -0.08, 0.0, 0.0, 0.0, 0.0, bone, 0.55 * intensity, false, false, false)
            local c = exhaustCoords(veh, bone)
            AddOwnedExplosion(PlayerPedId(), c.x, c.y, c.z, 61, 0.0, true, false, 0.0)
        end)
        playPopSound(veh, intensity)
    end

    if fxType == 'flame' or fxType == 'extra' then
        eachExhaustBone(veh, function(bone)
            local coords = exhaustCoords(veh, bone)
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedAtCoord('ent_sht_flame', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.85 * intensity, false, false, false)
            UseParticleFxAssetNextCall('scr_recartheft')
            StartParticleFxNonLoopedAtCoord('scr_wheel_burnout', coords.x, coords.y, coords.z - 0.12, 0.0, 0.0, 0.0, 0.55 * intensity, false, false, false)
        end)
        local c = GetEntityCoords(veh)
        DrawLightWithRange(c.x, c.y, c.z - 0.75, 255, 110, 35, 4.5, 10.0 * intensity)
    end

    if fxType == 'diesel' or fxType == 'smoke' then
        eachExhaustBone(veh, function(bone)
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedOnEntityBone('exp_grd_bzgas_smoke', veh, 0.0, -0.12, 0.0, 0.0, 0.0, 0.0, bone, 1.1 * intensity, false, false, false)
            local coords = exhaustCoords(veh, bone)
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedAtCoord('ent_sht_electrical_box', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.4 * intensity, false, false, false)
        end)
    end

    if fxType == 'flash' then
        local c = GetEntityCoords(veh)
        DrawLightWithRange(c.x, c.y, c.z, 255, 190, 90, 7.0, 16.0 * intensity)
        eachExhaustBone(veh, function(bone)
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedOnEntityBone('ent_sht_electrical_box', veh, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, 0.65 * intensity, false, false, false)
        end)
    end
end

local function syncFx(veh, fxType, intensity)
    if not NetworkGetEntityIsNetworked(veh) then return end
    local netId = VehToNet(veh)
    if netId and netId ~= 0 then
        TriggerServerEvent('sunset:tuning:syncExhaustFx', netId, fxType, intensity)
    end
end

local function burstExhaust(veh, tune, mult, kind)
    local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
    local intensity = (mult and mult.popIntensity) or 0.7

    STC.PlayExhaustFx(veh, 'pop', intensity)
    syncFx(veh, 'pop', intensity)

    if mode.flames or tune.exhaust == 'extra' or tune.exhaust == 'flames' then
        STC.PlayExhaustFx(veh, 'flame', intensity)
        STC.PlayExhaustFx(veh, 'flash', intensity * 0.85)
        syncFx(veh, 'flame', intensity)
    end

    if mode.diesel or kind == 'diesel' or tune.exhaust == 'diesel' then
        STC.PlayExhaustFx(veh, 'diesel', intensity)
        STC.PlayExhaustFx(veh, 'smoke', intensity * 0.9)
        syncFx(veh, 'diesel', intensity)
    end

    if tune.pop.secondBurst and kind ~= 'antilag' then
        SetTimeout(tonumber(tune.pop.durationMs) or 90, function()
            if DoesEntityExist(veh) then
                STC.PlayExhaustFx(veh, 'pop', intensity * 0.9)
                if mode.flames then STC.PlayExhaustFx(veh, 'flame', intensity * 0.8) end
            end
        end)
    end
end

function STC.BurstExhaust(veh, kind, count)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local state = STC.appliedVehicles[veh]
    local tune = state and state.tune
    if not tune or SunsetTuning.IsStockTune(tune) then return end
    local mult = state.mult or STC.getStageMultipliers(tune)
    count = math.max(1, math.min(6, tonumber(count) or 1))
    for i = 1, count do
        SetTimeout((i - 1) * 140, function()
            if DoesEntityExist(veh) then burstExhaust(veh, tune, mult, kind or 'pop') end
        end)
    end
end

RegisterNetEvent('sunset:tuning:client:exhaustFx', function(netId, fxType, intensity)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        STC.PlayExhaustFx(veh, fxType, intensity)
    end
end)

local function tuneHasEffects(tune)
    if not tune or SunsetTuning.IsStockTune(tune) then return false end
    local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
    return tune.pop.enabled or tune.antiLag.enabled or mode.flames or mode.diesel or tune.exhaust == 'extra'
end

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            lastThrottle = 0.0
            lastRpm = 0.0
            Wait(400)
            goto continue
        end

        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then
            Wait(250)
            goto continue
        end

        local state = STC.appliedVehicles[veh]
        local tune = state and state.tune
        if not tuneHasEffects(tune) then
            Wait(350)
            goto continue
        end

        local mult = state.mult or STC.getStageMultipliers(tune)
        local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
        local rpm = GetVehicleCurrentRpm(veh)
        local throttle = GetControlNormal(0, 71)
        local brake = GetControlNormal(0, 72)
        local now = GetGameTimer()
        local rpmThreshold = (tonumber(tune.pop.rpmMax) or 88) / 100.0
        local liftThrottle = lastThrottle > 0.28 and throttle < 0.22
        local rpmDrop = (lastRpm - rpm) > 0.045 and rpm > 0.38
        local highRpm = rpm >= math.max(0.48, rpmThreshold - 0.18) or lastRpm >= rpmThreshold

        if tune.antiLag.enabled and throttle > 0.35 and rpm > 0.25 and rpm < 0.88 and brake < 0.35 then
            local chance = ((tonumber(tune.antiLag.intensity) or 55) / 140.0)
            if now > popCooldown and math.random() < chance then
                popCooldown = now + 55
                burstExhaust(veh, tune, mult, 'antilag')
            end
        end

        if tune.pop.enabled then
            if now > popCooldown and (liftThrottle or rpmDrop) and highRpm and rpm > 0.35 then
                if math.random() < (0.42 + mult.popIntensity * 0.38) then
                    popCooldown = now + 95
                    burstExhaust(veh, tune, mult, mode.diesel and 'diesel' or 'pop')
                end
            elseif highRpm and throttle > 0.72 and rpm > rpmThreshold then
                if now > popCooldown and math.random() < 0.14 then
                    popCooldown = now + 110
                    burstExhaust(veh, tune, mult, 'pop')
                end
            elseif mode.diesel and throttle > 0.25 and rpm > 0.18 and rpm < 0.65 then
                if now > popCooldown and math.random() < 0.09 then
                    popCooldown = now + 160
                    burstExhaust(veh, tune, mult, 'diesel')
                end
            end
        end

        if (mode.flames or tune.exhaust == 'extra') and rpm > 0.62 and throttle > 0.45 then
            if now > popCooldown + 40 and math.random() < 0.06 then
                popCooldown = now + 130
                STC.PlayExhaustFx(veh, 'flame', mult.popIntensity * 0.75)
                syncFx(veh, 'flame', mult.popIntensity * 0.75)
            end
        end

        lastThrottle = throttle
        lastRpm = rpm
        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            Wait(800)
            goto continue
        end

        local veh = GetVehiclePedIsIn(ped, false)
        local state = STC.appliedVehicles[veh]
        local tune = state and state.tune
        if not tune or not tune.hud.enabled then
            Wait(500)
            goto continue
        end

        local rpm = math.floor(GetVehicleCurrentRpm(veh) * 100)
        local speed = math.floor(GetEntitySpeed(veh) * 3.6)
        local boost = 0
        pcall(function() boost = math.floor((GetVehicleTurboPressure(veh) or 0.0) * 100) end)
        local stage = SunsetTuning.Stages[tune.stage] and SunsetTuning.Stages[tune.stage].label or tune.stage

        SetTextFont(4)
        SetTextScale(0.32, 0.32)
        SetTextColour(255, 153, 51, 215)
        SetTextOutline()
        SetTextEntry('STRING')
        AddTextComponentSubstringPlayerName(('ECU %s  |  %d km/h  |  RPM %d%%  |  BOOST %d%%'):format(stage, speed, rpm, boost))
        DrawText(0.015, 0.92)

        ::continue::
    end
end)
