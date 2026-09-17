local STC = SunsetTuningClient
local EP = STC.ExhaustPtfx

local lastThrottle = 0.0
local lastRpm = 0.0
local lastGear = 0
local popCooldown = 0
local twostepArmed = false
local exhaustDebug = false
local lastDebugEvent = 'none'

local overrun = {
    active = false,
    veh = 0,
    peakRpm = 0.0,
    budget = 0,
    nextPopAt = 0,
}

local function syncFx(veh, kind, intensity, color, withFlames)
    if not NetworkGetEntityIsNetworked(veh) then return end
    local netId = VehToNet(veh)
    if netId and netId ~= 0 then
        TriggerServerEvent('sunset:tuning:syncExhaustFx', netId, kind, intensity, color, withFlames == true)
    end
end

function STC.PlayExhaustFx(veh, fxType, intensity, color, withFlames)
    EP.burst(veh, fxType, intensity, color, withFlames)
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
    overrun.budget = 0
    overrun.nextPopAt = 0
end

local function startOverrun(veh, rpm, now, budget)
    overrun.active = true
    overrun.veh = veh
    overrun.peakRpm = math.max(overrun.peakRpm, rpm, lastRpm)
    overrun.budget = math.max(1, tonumber(budget) or 2)
    overrun.nextPopAt = now
end

local function burstExhaust(veh, tune, mult, kind, withFlames, intensityScale)
    local intensity = ((mult and mult.popIntensity) or 0.75) * (tonumber(intensityScale) or 1.0)
    local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
    local color = flameColorOf(tune)
    local showFlames = withFlames and flamesActive(tune)
    lastDebugEvent = ('%s (int: %.2f, flm: %s)'):format(kind, intensity, showFlames and 'Y' or 'N')

    if kind == 'antilag' then
        EP.burst(veh, 'antilag', intensity * 0.85, color, false)
        syncFx(veh, 'antilag', intensity * 0.85, color, false)
        return
    end

    if kind == 'twostep' then
        EP.burst(veh, 'twostep', math.min(1.2, intensity * 1.05), color, showFlames)
        syncFx(veh, 'twostep', math.min(1.2, intensity * 1.05), color, showFlames)
        return
    end

    if kind == 'gearshift' then
        EP.burst(veh, 'gearshift', intensity, color, showFlames)
        syncFx(veh, 'gearshift', intensity, color, showFlames)
        return
    end

    if mode.diesel or kind == 'diesel' or tune.exhaust == 'diesel' then
        EP.burst(veh, 'diesel', intensity, color, false)
        syncFx(veh, 'diesel', intensity, color, false)
        return
    end

    -- Normal pop / crackle / bang
    EP.burst(veh, kind, intensity, color, showFlames)
    syncFx(veh, kind, intensity, color, showFlames)
end

function STC.BurstExhaust(veh, kind, count)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local state = STC.appliedVehicles[veh]
    local tune = state and state.tune
    if not tune or SunsetTuning.IsStockTune(tune) then return end
    local mult = state.mult or STC.getStageMultipliers(tune)
    count = math.max(1, math.min(6, tonumber(count) or 1))
    for i = 1, count do
        SetTimeout((i - 1) * 150, function()
            if DoesEntityExist(veh) then
                burstExhaust(veh, tune, mult, kind or 'crackle', true)
            end
        end)
    end
end

RegisterNetEvent('sunset:tuning:client:exhaustFx', function(netId, fxType, intensity, color, withFlames)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        EP.burst(veh, fxType, intensity, color, withFlames)
    end
end)

local function tuneHasEffects(tune, caps)
    if not tune or SunsetTuning.IsStockTune(tune) then return false end
    if caps and not caps.hasExhaust then return false end
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
            lastGear = 0
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
        local caps = state and state.caps
        if STC.dynoActive or not tuneHasEffects(tune, caps) then
            clearOverrun()
            Wait(300)
            goto continue
        end

        local mult = state.mult or STC.getStageMultipliers(tune)
        local mode = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang
        local now = GetGameTimer()

        -- Canonical telemetry extraction
        local telem = nil
        if GetResourceState('sunset_vehicles') == 'started' then
            pcall(function()
                telem = exports.sunset_vehicles:GetVehicleTelemetry(veh)
            end)
        end

        local rawRpm = telem and telem.rawRpm or GetVehicleCurrentRpm(veh)
        local displayRpm = telem and telem.displayRpm or math.max(0.0, math.min(1.0, (rawRpm - 0.2) / 0.8))
        local gear = telem and telem.gear or GetVehicleCurrentGear(veh)
        local throttle = telem and telem.throttle or GetControlNormal(0, 71)
        local brake = telem and telem.brake or GetControlNormal(0, 72)
        local speed = telem and telem.speedKmh or (GetEntitySpeed(veh) * 3.6)

        -- Metrics declared in order: no forward-local references
        local rpmDrop = math.max(0.0, lastRpm - displayRpm)
        local rpmFalling = rpmDrop > 0.015
        local throttleDrop = lastThrottle - throttle
        local rpmTarget = (tonumber(tune.pop.rpmMax) or 85) / 100.0
        local triggerThreshold = math.max(0.42, rpmTarget - 0.10)
        local wasHighRpm = lastRpm >= triggerThreshold
        local liftOff = lastThrottle > 0.38 and throttle < 0.15 and throttleDrop > 0.22 and rpmFalling
        local minOverrunRpm = 0.25

        -- 1. Single crisp report on high-RPM upshift under load
        if (tune.pop.enabled or tune.antiLag.enabled) and gear ~= lastGear and lastGear > 0 and gear > lastGear and displayRpm > 0.55 and lastThrottle > 0.45 and not IsEntityInAir(veh) then
            if now > popCooldown then
                popCooldown = now + 250
                burstExhaust(veh, tune, mult, 'gearshift', flamesActive(tune), 1.15)
            end
        end

        -- 2. Lift-off overrun initiation with bounded event budget
        if tune.pop.enabled and liftOff and wasHighRpm and not overrun.active then
            local budget = 2
            if tune.exhaust == 'extra' then
                budget = math.random(4, 6)
            elseif tune.exhaust == 'pop_bang' or tune.stage == 'race' then
                budget = math.random(2, 5)
            else
                budget = math.random(1, 3)
            end

            startOverrun(veh, displayRpm, now, budget)
            if now > popCooldown then
                popCooldown = now + 90
                burstExhaust(veh, tune, mult, 'crackle', flamesActive(tune), 0.95)
                overrun.budget = overrun.budget - 1
                overrun.nextPopAt = now + math.random(90, 140)
            end
        end

        -- 3. Overrun sequence state machine
        if overrun.active then
            if veh ~= overrun.veh or displayRpm < minOverrunRpm or throttle > 0.25 or brake > 0.70 or overrun.budget <= 0 then
                clearOverrun()
            elseif tune.pop.enabled and now >= overrun.nextPopAt and now > popCooldown then
                overrun.budget = overrun.budget - 1
                local isBang = (overrun.budget == 1 and math.random() < 0.40) or (math.random() < 0.25)
                local kind = isBang and 'bang' or 'crackle'
                local strength = 0.70 + (displayRpm * 0.40)

                burstExhaust(veh, tune, mult, kind, flamesActive(tune), strength)
                popCooldown = now + 75
                overrun.nextPopAt = now + math.random(95, 150)

                if overrun.budget <= 0 then
                    clearOverrun()
                end
            end
        end

        -- 4. 2-step launch control at standstill (brake + full throttle)
        if tune.pop.enabled and tune.hardware and tune.hardware.launchControl and speed < 5.0 and displayRpm > 0.75 then
            if throttle > 0.75 and brake > 0.60 then
                twostepArmed = true
            end
            if twostepArmed and now > popCooldown and throttle > 0.60 then
                popCooldown = now + 160
                burstExhaust(veh, tune, mult, 'twostep', flamesActive(tune), 1.05)
            end
        else
            twostepArmed = false
        end

        -- 5. Anti-lag blip
        if tune.antiLag.enabled and not overrun.active and brake < 0.30 and displayRpm > 0.40 and displayRpm < 0.85 then
            if throttleDrop > 0.22 and lastThrottle > 0.45 and throttle < 0.28 and now > popCooldown then
                popCooldown = now + 200
                burstExhaust(veh, tune, mult, 'antilag', false, 0.95)
            end
        end

        -- 6. Diesel soot puff
        if mode.diesel and tune.pop.enabled and speed < 30.0 and throttle > 0.30 and displayRpm > 0.20 and displayRpm < 0.60 then
            if now > popCooldown and math.random() < 0.04 then
                popCooldown = now + 450
                burstExhaust(veh, tune, mult, 'diesel', false, 0.85)
            end
        end

        lastThrottle = throttle
        lastRpm = displayRpm
        lastGear = gear
        Wait(waitMs)
        ::continue::
    end
end)

-- Developer telemetry overlay command
RegisterCommand('exhaustdebug', function()
    exhaustDebug = not exhaustDebug
    TriggerEvent('chat:addMessage', {
        args = { '^3[EXHAUST DEBUG]', exhaustDebug and '^2ENABLED' or '^1DISABLED' }
    })
end, false)

-- On-screen HUD / Debug drawing
CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            Wait(600)
            goto continue
        end

        local veh = GetVehiclePedIsIn(ped, false)
        local state = STC.appliedVehicles[veh]
        local tune = state and state.tune
        local showEcuHud = tune and tune.hud and tune.hud.enabled

        if not showEcuHud and not exhaustDebug then
            Wait(400)
            goto continue
        end

        local rpm = math.floor(GetVehicleCurrentRpm(veh) * 100)
        local speed = math.floor(GetEntitySpeed(veh) * 3.6)
        local boost = 0
        pcall(function() boost = math.floor((GetVehicleTurboPressure(veh) or 0.0) * 100) end)

        if showEcuHud then
            local stage = tune and SunsetTuning.Stages[tune.stage] and SunsetTuning.Stages[tune.stage].label or (tune and tune.stage or 'STOCK')
            SetTextFont(4)
            SetTextScale(0.32, 0.32)
            SetTextColour(255, 153, 51, 215)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentSubstringPlayerName(('ECU %s  |  %d km/h  |  RPM %d%%  |  BOOST %d%%'):format(stage, speed, rpm, boost))
            DrawText(0.015, 0.92)
        end

        if exhaustDebug then
            local nosState = 'N/A'
            if GetResourceState('sunset_tuning') == 'started' then
                local ok, nState = pcall(function() return exports.sunset_tuning:GetNitrousHudState(veh) end)
                if ok and type(nState) == 'table' then
                    nosState = ('Installed: %s, Lvl: %d, Act: %s, Bottle: %d%%'):format(
                        nState.installed and 'Y' or 'N',
                        nState.tier or 1,
                        nState.active and 'YES' or 'NO',
                        math.floor(nState.level or 0)
                    )
                end
            end

            local lines = {
                '~y~--- EXHAUST & TELEMETRY DEBUG ---~s~',
                ('Veh: ~b~%d~s~ | Speed: ~g~%d km/h~s~ | Gear: ~g~%d~s~'):format(veh, speed, GetVehicleCurrentGear(veh)),
                ('RPM: Raw ~c~%.2f~s~ | Disp ~y~%.2f~s~ (Target: ~o~%s%%~s~)'):format(
                    GetVehicleCurrentRpm(veh),
                    lastRpm,
                    tune and tune.pop and tune.pop.rpmMax or 'N/A'
                ),
                ('Throttle: ~b~%.2f~s~ | Brake: ~r~%.2f~s~'):format(lastThrottle, GetControlNormal(0, 72)),
                ('Overrun: ~p~%s~s~ | Budget: ~p~%d~s~'):format(overrun.active and 'ACTIVE' or 'IDLE', overrun.budget),
                ('Last Event: ~w~%s~s~'):format(lastDebugEvent),
                ('Nitrous: ~c~%s~s~'):format(nosState),
            }

            for idx, text in ipairs(lines) do
                SetTextFont(0)
                SetTextScale(0.28, 0.28)
                SetTextColour(255, 255, 255, 230)
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentSubstringPlayerName(text)
                DrawText(0.015, 0.35 + (idx - 1) * 0.022)
            end
        end

        ::continue::
    end
end)
