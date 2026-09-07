local STC = SunsetTuningClient

local function playExhaustPop(veh, intensity)
    if not DoesEntityExist(veh) then return end
    local scale = 0.35 + (intensity * 0.65)
    local bones = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4' }
    for _, name in ipairs(bones) do
        local bone = GetEntityBoneIndexByName(veh, name)
        if bone ~= -1 then
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedOnEntityBone('veh_backfire', veh, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, scale, false, false, false)
        end
    end
end

local function flameBurst(veh, intensity)
    if not DoesEntityExist(veh) then return end
    local coords = GetOffsetFromEntityInWorldCoords(veh, 0.0, -2.2, 0.2)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_sht_flame', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.45 + intensity * 0.35, false, false, false)
end

local function shouldPop(tune, rpm)
    if not tune.pop.enabled then return false end
    local maxRpm = (tonumber(tune.pop.rpmMax) or 92) / 100.0
    return rpm >= maxRpm
end

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
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
        if not tune then
            Wait(400)
            goto continue
        end

        local mult = state.mult or STC.getStageMultipliers(tune)
        local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
        local rpm = GetVehicleCurrentRpm(veh)
        local throttle = GetControlNormal(0, 71)
        local popping = shouldPop(tune, rpm)

        if tune.antiLag.enabled and throttle > 0.65 and rpm > 0.35 and rpm < 0.72 then
            if math.random() < ((tonumber(tune.antiLag.intensity) or 55) / 400.0) then
                playExhaustPop(veh, mult.popIntensity * 0.8)
            end
        end

        if popping and throttle < 0.12 and rpm > 0.55 then
            if math.random() < (0.12 + mult.popIntensity * 0.22) then
                playExhaustPop(veh, mult.popIntensity)
                if mode.flames then flameBurst(veh, mult.popIntensity) end
                if tune.pop.secondBurst and math.random() < 0.45 then
                    Wait(tonumber(tune.pop.durationMs) or 100)
                    playExhaustPop(veh, mult.popIntensity * 0.85)
                    if mode.flames then flameBurst(veh, mult.popIntensity * 0.8) end
                end
            end
        elseif mode.diesel and throttle > 0.4 and rpm > 0.25 and rpm < 0.55 then
            if math.random() < 0.03 then
                playExhaustPop(veh, mult.popIntensity * 0.5)
            end
        end

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
