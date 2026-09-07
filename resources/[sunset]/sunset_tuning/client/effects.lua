local STC = SunsetTuningClient
local EP = STC.ExhaustPtfx

local lastThrottle = 0.0
local lastRpm = 0.0
local popCooldown = 0
local twostepArmed = false
local overrun = {
    active = false,
    veh = 0,
    peakRpm = 0.0,
    untilMs = 0,
}

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

local function clearOverrun()
    overrun.active = false
    overrun.veh = 0
    overrun.peakRpm = 0.0
    overrun.untilMs = 0
end

local function startOverrun(veh, rpm, now, tune)
    local duration = tonumber(tune.pop.durationMs) or 100
    local holdMs = 1800 + math.min(1400, duration * 8)
    overrun.active = true
    overrun.veh = veh
    overrun.peakRpm = math.max(overrun.peakRpm, rpm, lastRpm)
    overrun.untilMs = now + holdMs
end

local function burstExhaust(veh, tune, mult, kind, withFlames, intensityScale)
    local intensity = ((mult and mult.popIntensity) or 0.75) * (tonumber(intensityScale) or 1.0)
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
        EP.burst(veh, 'flame', intensity * 1.15, color)
        syncFx(veh, 'flame', intensity, color)
    end

    if mode.diesel or kind == 'diesel' or tune.exhaust == 'diesel' then
        EP.burst(veh, 'diesel', intensity, color)
        syncFx(veh, 'diesel', intensity, color)
    end

    if tune.pop.secondBurst and kind == 'pop' then
        SetTimeout(tonumber(tune.pop.durationMs) or 90, function()
            if DoesEntityExist(veh) then
                EP.burst(veh, 'pop', intensity * 0.9, color)
                if showFlames and math.random() < 0.65 then
                    EP.burst(veh, 'flame', intensity * 0.75, color)
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
        local waitMs = 35
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            lastThrottle = 0.0
            lastRpm = 0.0
            twostepArmed = false
            clearOverrun()
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
            clearOverrun()
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
        local minOverrunRpm = 0.26

        local liftOff = lastThrottle > 0.35 and throttle < 0.22
        local wasHighRpm = lastRpm >= math.max(0.52, rpmThreshold - 0.15)
        local rpmFalling = (lastRpm - rpm) > 0.018

        -- Pop & bang: arm overrun on lift-off, then pops while RPM spins down.
        if tune.pop.enabled and liftOff and wasHighRpm and lastRpm >= rpmThreshold - 0.1 then
            startOverrun(veh, rpm, now, tune)
            if now > popCooldown then
                popCooldown = now + 105
                burstExhaust(veh, tune, mult, mode.diesel and 'diesel' or 'pop', true, 1.18)
            end
        end

        if overrun.active then
            if veh ~= overrun.veh or now > overrun.untilMs or rpm < minOverrunRpm or throttle > 0.42 or brake > 0.5 then
                clearOverrun()
            elseif tune.pop.enabled and throttle < 0.28 and rpm > minOverrunRpm and now > popCooldown then
                local rpmRange = math.max(0.15, overrun.peakRpm - minOverrunRpm)
                local rpmPos = (rpm - minOverrunRpm) / rpmRange
                local rpmDrop = math.max(0.0, lastRpm - rpm)
                local chance = 0.10 + mult.popIntensity * 0.22
                if rpmFalling then chance = chance + math.min(0.52, rpmDrop * 12.0) end
                if rpmPos > 0.62 then chance = chance + 0.16 end
                if tune.pop.secondBurst then chance = chance + 0.08 end

                if math.random() < chance then
                    -- Sharp individual reports high in the rev range, with
                    -- progressively wider spacing as the engine spins down.
                    local gap = 105 + math.floor((1.0 - rpmPos) * 145) + math.random(0, 38)
                    popCooldown = now + gap
                    local strength = 0.82 + rpmPos * 0.48 + math.min(0.2, rpmDrop * 4.0)
                    burstExhaust(veh, tune, mult, mode.diesel and 'diesel' or 'pop', true, strength)
                end
            end
        end

        -- 2-step at standstill
        if tune.pop.enabled and tune.hardware and tune.hardware.launchControl and speed < 6.0 and rpm > 0.82 then
            if throttle < 0.12 and lastThrottle > 0.55 then twostepArmed = true end
            if twostepArmed and now > popCooldown and throttle < 0.1 and rpm > 0.78 then
                if math.random() < 0.6 then
                    popCooldown = now + 200
                    twostepArmed = false
                    burstExhaust(veh, tune, mult, 'twostep', true)
                end
            end
        else
            twostepArmed = false
        end

        if tune.antiLag.enabled and brake < 0.35 and not overrun.active then
            local throttleBlip = lastThrottle > 0.42 and throttle < 0.28 and rpm > 0.38 and rpm < 0.82
            if now > popCooldown and throttleBlip and math.random() < ((tonumber(tune.antiLag.intensity) or 55) / 280.0) then
                popCooldown = now + 260
                burstExhaust(veh, tune, mult, 'antilag', false)
            end
        end

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
