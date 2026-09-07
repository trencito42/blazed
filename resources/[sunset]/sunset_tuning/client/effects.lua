local STC = SunsetTuningClient

local lastThrottle = 0.0
local lastRpm = 0.0

local function playExhaustPop(veh, intensity)
    if not DoesEntityExist(veh) then return end
    local scale = 0.4 + (intensity * 0.8)
    local bones = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4' }
    for _, name in ipairs(bones) do
        local bone = GetEntityBoneIndexByName(veh, name)
        if bone ~= -1 then
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedOnEntityBone('veh_backfire', veh, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, scale, false, false, false)
        end
    end
    PlaySoundFromEntity(-1, 'Crackle', veh, 'DLC_HEIST_FLEECA_SOUNDSET', false, 0)
end

local function flameBurst(veh, intensity)
    if not DoesEntityExist(veh) then return end
    local coords = GetOffsetFromEntityInWorldCoords(veh, 0.0, -2.2, 0.2)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_sht_flame', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.5 + intensity * 0.4, false, false, false)
end

local function exhaustActive(tune)
    if not tune or not tune.pop or not tune.pop.enabled then return false end
    local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
    return mode ~= nil
end

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            lastThrottle = 0.0
            lastRpm = 0.0
            Wait(500)
            goto continue
        end

        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then
            Wait(250)
            goto continue
        end

        local state = STC.appliedVehicles[veh]
        local tune = state and state.tune
        if not tune or SunsetTuning.IsStockTune(tune) then
            Wait(400)
            goto continue
        end

        local mult = state.mult or STC.getStageMultipliers(tune)
        local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
        local rpm = GetVehicleCurrentRpm(veh)
        local throttle = GetControlNormal(0, 71)
        local rpmThreshold = (tonumber(tune.pop.rpmMax) or 88) / 100.0
        local liftThrottle = lastThrottle > 0.45 and throttle < 0.15
        local highRpm = rpm >= math.max(0.55, rpmThreshold - 0.12) or lastRpm >= rpmThreshold

        if tune.antiLag.enabled and throttle > 0.55 and rpm > 0.32 and rpm < 0.78 then
            if math.random() < ((tonumber(tune.antiLag.intensity) or 55) / 280.0) then
                playExhaustPop(veh, mult.popIntensity * 0.75)
            end
        end

        if exhaustActive(tune) and liftThrottle and highRpm and rpm > 0.45 then
            if math.random() < (0.18 + mult.popIntensity * 0.28) then
                playExhaustPop(veh, mult.popIntensity)
                if mode.flames then flameBurst(veh, mult.popIntensity) end
                if tune.pop.secondBurst and math.random() < 0.5 then
                    Wait(tonumber(tune.pop.durationMs) or 100)
                    playExhaustPop(veh, mult.popIntensity * 0.85)
                    if mode.flames then flameBurst(veh, mult.popIntensity * 0.75) end
                end
            end
        elseif mode.diesel and tune.pop.enabled and throttle > 0.35 and rpm > 0.22 and rpm < 0.58 then
            if math.random() < 0.045 then
                playExhaustPop(veh, mult.popIntensity * 0.45)
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

RegisterNetEvent('sunset:tuning:client:setPlateTune', function(plate, tune)
    STC.plateTunes[STC.normalizePlate(plate)] = SunsetTuning.SanitizeTune(tune)
end)
