local STC = SunsetTuningClient
local EP = STC.ExhaustPtfx

local lastThrottle = 0.0
local lastRpm = 0.0
local popCooldown = 0
local twostepArmed = false

local function syncFx(veh, kind, intensity, color)
    if not NetworkGetEntityIsNetworked(veh) then return end
    local netId = VehToNet(veh)
    if netId and netId ~= 0 then
        TriggerServerEvent('sunset:tuning:syncExhaustFx', netId, kind, intensity, color)
    end
end

function STC.PlayExhaustFx(veh, fxType, intensity, color)
    EP.burst(veh, fxType, intensity, color)
end

local function flamesActive(tune)
    if not tune then return false end
    local mode = SunsetTuning.ExhaustModes[tune.exhaust]
    return (tune.flames and tune.flames.enabled) or (mode and mode.flames) or tune.exhaust == 'extra' or tune.exhaust == 'flames'
end

local function flameColorOf(tune)
    if tune and tune.flames and tune.flames.color then
        return STC.ExhaustPtfx.normalizeColor(tune.flames.color)
    end
    return STC.ExhaustPtfx.normalizeColor(nil)
end

local function burstExhaust(veh, tune, mult, kind, withFlames)
    local intensity = (mult and mult.popIntensity) or 0.75
    local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
    local color = flameColorOf(tune)
    local showFlames = withFlames and flamesActive(tune)

    if kind == 'antilag' then
        EP.burst(veh, 'antilag', intensity * 0.85, color)
        if showFlames and math.random() < 0.22 then
            EP.burst(veh, 'flame', intensity * 0.65, color)
        end
        syncFx(veh, 'pop', intensity, color)
        return
    end

    if kind == 'twostep' then
        EP.burst(veh, 'twostep', math.min(1.2, intensity * 1.05), color)
        if showFlames then EP.burst(veh, 'flame', intensity * 0.75, color) end
        syncFx(veh, 'pop', intensity, color)
        return
    end

    EP.burst(veh, 'pop', intensity, color)
    syncFx(veh, 'pop', intensity, color)

    if showFlames then
        EP.burst(veh, 'flame', intensity * 0.8, color)
        syncFx(veh, 'flame', intensity, color)
    end

    if mode.diesel or kind == 'diesel' or tune.exhaust == 'diesel' then
        EP.burst(veh, 'diesel', intensity, color)
        syncFx(veh, 'diesel', intensity, color)
    end

    if tune.pop.secondBurst and kind == 'pop' then
        SetTimeout(tonumber(tune.pop.durationMs) or 90, function()
            if DoesEntityExist(veh) then
                EP.burst(veh, 'pop', intensity * 0.85, color)
                if showFlames and math.random() < 0.6 then
                    EP.burst(veh, 'flame', intensity * 0.7, color)
                end
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
        SetTimeout((i - 1) * 160, function()
            if DoesEntityExist(veh) then
                burstExhaust(veh, tune, mult, kind or 'pop', true)
            end
        end)
    end
end

RegisterNetEvent('sunset:tuning:client:exhaustFx', function(netId, fxType, intensity, color)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        EP.burst(veh, fxType, intensity, color)
    end
end)

local function tuneHasEffects(tune)
    if not tune or SunsetTuning.IsStockTune(tune) then return false end
    local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
    return tune.pop.enabled or tune.antiLag.enabled or flamesActive(tune) or mode.diesel or tune.exhaust == 'diesel'
end

CreateThread(function()
    while true do
        local waitMs = 50
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            lastThrottle = 0.0
            lastRpm = 0.0
            twostepArmed = false
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
        if STC.dynoActive or not tuneHasEffects(tune) then
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

        -- Real pop & bang: lift-off after high RPM (decel), not while holding gas.
        local liftOff = lastThrottle > 0.45 and throttle < 0.18
        local rpmFalling = (lastRpm - rpm) > 0.055 and lastRpm >= (rpmThreshold - 0.08)
        local wasHighRpm = lastRpm >= math.max(0.58, rpmThreshold - 0.12)

        if tune.pop.enabled and now > popCooldown and liftOff and wasHighRpm and rpm > 0.28 then
            local chance = 0.52 + mult.popIntensity * 0.38
            if math.random() < chance then
                popCooldown = now + 160
                burstExhaust(veh, tune, mult, mode.diesel and 'diesel' or 'pop', true)
                if mult.popIntensity > 0.7 and math.random() < 0.45 then
                    SetTimeout(110, function()
                        if DoesEntityExist(veh) then
                            EP.burst(veh, 'pop', mult.popIntensity, flameColorOf(tune))
                        end
                    end)
                end
            end
        end

        -- 2-step / launch: stationary rev limiter — only on repeated lift at very high RPM.
        if tune.pop.enabled and speed < 6.0 and rpm > 0.82 then
            if throttle < 0.12 and lastThrottle > 0.55 then twostepArmed = true end
            if twostepArmed and now > popCooldown and throttle < 0.1 and rpm > 0.78 then
                if math.random() < 0.55 then
                    popCooldown = now + 220
                    twostepArmed = false
                    burstExhaust(veh, tune, mult, 'twostep', true)
                end
            end
        else
            twostepArmed = false
        end

        -- Anti-lag: short burps on throttle blips in spool range — never constant hold.
        if tune.antiLag.enabled and brake < 0.35 then
            local throttleBlip = lastThrottle > 0.42 and throttle < 0.28 and rpm > 0.38 and rpm < 0.82
            local spoolHold = throttle > 0.55 and rpm > 0.48 and rpm < 0.72 and (now % 900) < 40
            if now > popCooldown and (throttleBlip or spoolHold) then
                local chance = ((tonumber(tune.antiLag.intensity) or 55) / 320.0)
                if math.random() < chance then
                    popCooldown = now + 280
                    burstExhaust(veh, tune, mult, 'antilag', false)
                end
            end
        end

        -- Diesel smoke: low RPM crawl only, rare.
        if mode.diesel and tune.pop.enabled and speed < 25 and throttle > 0.25 and rpm > 0.15 and rpm < 0.55 then
            if now > popCooldown and math.random() < 0.03 then
                popCooldown = now + 400
                burstExhaust(veh, tune, mult, 'diesel', false)
            end
        end

        lastThrottle = throttle
        lastRpm = rpm
        Wait(waitMs)
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
