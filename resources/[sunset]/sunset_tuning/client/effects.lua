local STC = SunsetTuningClient
local EP = STC.ExhaustPtfx

local lastThrottle = 0.0
local lastRpm = 0.0
local popCooldown = 0

local function syncFx(veh, kind, intensity)
    if not NetworkGetEntityIsNetworked(veh) then return end
    local netId = VehToNet(veh)
    if netId and netId ~= 0 then
        TriggerServerEvent('sunset:tuning:syncExhaustFx', netId, kind, intensity)
    end
end

function STC.PlayExhaustFx(veh, fxType, intensity)
    EP.burst(veh, fxType, intensity)
end

local function flamesActive(tune)
    if not tune then return false end
    local mode = SunsetTuning.ExhaustModes[tune.exhaust]
    return (tune.flames and tune.flames.enabled) or (mode and mode.flames) or tune.exhaust == 'extra' or tune.exhaust == 'flames'
end

local function burstExhaust(veh, tune, mult, kind)
    local intensity = (mult and mult.popIntensity) or 0.75
    local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang

    EP.burst(veh, (kind == 'antilag') and 'antilag' or 'pop', intensity)
    syncFx(veh, 'pop', intensity)

    if flamesActive(tune) or kind == 'flame' or kind == 'extra' then
        EP.burst(veh, 'flame', intensity)
        syncFx(veh, 'flame', intensity)
    end

    if mode.diesel or kind == 'diesel' or tune.exhaust == 'diesel' then
        EP.burst(veh, 'diesel', intensity)
        syncFx(veh, 'diesel', intensity)
    end

    if tune.pop.secondBurst and kind ~= 'antilag' then
        SetTimeout(tonumber(tune.pop.durationMs) or 90, function()
            if DoesEntityExist(veh) then
                EP.burst(veh, 'pop', intensity * 0.9)
                if flamesActive(tune) then EP.burst(veh, 'flame', intensity * 0.8) end
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
    count = math.max(1, math.min(8, tonumber(count) or 1))
    for i = 1, count do
        SetTimeout((i - 1) * 130, function()
            if DoesEntityExist(veh) then burstExhaust(veh, tune, mult, kind or 'pop') end
        end)
    end
end

RegisterNetEvent('sunset:tuning:client:exhaustFx', function(netId, fxType, intensity)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        EP.burst(veh, fxType, intensity)
    end
end)

local function tuneHasEffects(tune)
    if not tune or SunsetTuning.IsStockTune(tune) then return false end
    local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
    return tune.pop.enabled or tune.antiLag.enabled or flamesActive(tune) or mode.diesel or tune.exhaust == 'diesel'
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
            Wait(300)
            goto continue
        end

        local mult = state.mult or STC.getStageMultipliers(tune)
        local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
        local rpm = GetVehicleCurrentRpm(veh)
        local throttle = GetControlNormal(0, 71)
        local brake = GetControlNormal(0, 72)
        local speed = GetEntitySpeed(veh) * 3.6
        local now = GetGameTimer()
        local rpmThreshold = (tonumber(tune.pop.rpmMax) or 88) / 100.0
        local liftThrottle = lastThrottle > 0.22 and throttle < 0.2
        local rpmDrop = (lastRpm - rpm) > 0.04 and rpm > 0.32
        local highRpm = rpm >= math.max(0.45, rpmThreshold - 0.2) or lastRpm >= rpmThreshold

        -- Anti-lag: pops while accelerating in mid RPM
        if tune.antiLag.enabled and throttle > 0.3 and rpm > 0.22 and rpm < 0.9 and brake < 0.4 then
            local chance = ((tonumber(tune.antiLag.intensity) or 55) / 100.0)
            if now > popCooldown and math.random() < chance then
                popCooldown = now + 45
                burstExhaust(veh, tune, mult, 'antilag')
            end
        end

        -- Pop & bang: lift-off deceleration
        if tune.pop.enabled then
            if now > popCooldown and (liftThrottle or rpmDrop) and highRpm and rpm > 0.3 then
                if math.random() < (0.55 + mult.popIntensity * 0.35) then
                    popCooldown = now + 80
                    burstExhaust(veh, tune, mult, mode.diesel and 'diesel' or 'pop')
                end
            elseif highRpm and throttle > 0.65 and rpm > (rpmThreshold - 0.05) then
                if now > popCooldown and math.random() < 0.18 then
                    popCooldown = now + 100
                    burstExhaust(veh, tune, mult, 'pop')
                end
            elseif speed < 8.0 and rpm > 0.78 and throttle < 0.15 then
                -- 2-step style at standstill
                if now > popCooldown and math.random() < 0.35 then
                    popCooldown = now + 70
                    burstExhaust(veh, tune, mult, 'antilag')
                end
            elseif mode.diesel and throttle > 0.2 and rpm > 0.15 and rpm < 0.68 then
                if now > popCooldown and math.random() < 0.12 then
                    popCooldown = now + 140
                    burstExhaust(veh, tune, mult, 'diesel')
                end
            end
        end

        -- Flames while on throttle at high RPM
        if flamesActive(tune) and rpm > 0.55 and throttle > 0.4 then
            if now > popCooldown + 30 and math.random() < 0.1 then
                popCooldown = now + 110
                EP.burst(veh, 'flame', mult.popIntensity * 0.85)
                syncFx(veh, 'flame', mult.popIntensity * 0.85)
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
