local practicalState = nil
local testVehicle = 0
local testBlips = {}
local targetProps = {}
local weaponServerHits = 0

local function notify(msg, kind)
    exports.sunset_ui:Notify(msg, kind or 'info', 7000)
end

local function asVector3(value)
    if type(value) == 'vector3' then return value end
    if type(value) == 'vector4' then return vector3(value.x, value.y, value.z) end
    if type(value) == 'table' then
        return vector3(tonumber(value.x) or 0.0, tonumber(value.y) or 0.0, tonumber(value.z) or 0.0)
    end
    return vector3(0.0, 0.0, 0.0)
end

local function resolvePracticalCfg(licenseType, payload)
    local cfg = SunsetLicenses.Practical[licenseType]
    if cfg then return cfg end
    return payload and payload.practical
end

local function notifyOnce(state, msg, kind)
    state = state or {}
    local now = GetGameTimer()
    if state.msg == msg and state.at and (now - state.at) < 5000 then return end
    state.msg = msg
    state.at = now
    notify(msg, kind)
end

local function clearBlips()
    for _, b in ipairs(testBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    testBlips = {}
end

local function clearTargets()
    for _, ent in ipairs(targetProps) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    targetProps = {}
end

local function loadModel(model)
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(model)
end

local function spawnTestVehicle(model, spawn, opts)
    opts = opts or {}
    if testVehicle ~= 0 and DoesEntityExist(testVehicle) then
        DeleteEntity(testVehicle)
    end
    if not loadModel(model) then return nil end
    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    local engineOn = opts.engineOff ~= true
    SetVehicleEngineOn(veh, engineOn, true, false)
    SetVehicleKeepEngineOnWhenAbandoned(veh, engineOn)
    if opts.engineOff then
        TriggerEvent('sunset:vehicles:setEngineState', veh, false)
    end
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    Wait(50)
    SetFollowPedCamViewMode(1)
    local netId = VehToNet(veh)
    SetNetworkIdCanMigrate(netId, true)
    SetModelAsNoLongerNeeded(model)
    testVehicle = veh
    local registered, registerError
    for _ = 1, 20 do
        registered, registerError = Sunset.AwaitCallback('sunset:license:registerTestVehicle', netId)
        if registered then break end
        Wait(100)
    end
    if not registered then
        DeleteEntity(veh)
        testVehicle = 0
        return nil, registerError or 'The training vehicle could not be verified by the server.'
    end
    return veh
end

local function addCheckpointBlips(checkpoints, color)
    clearBlips()
    for i, cp in ipairs(checkpoints or {}) do
        local point = asVector3(cp)
        local blip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, color or 47)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, i ~= 1)
        if i == 1 then
            SetBlipRoute(blip, true)
            SetBlipRouteColour(blip, color or 47)
        end
        testBlips[#testBlips + 1] = blip
    end
end

local function updateRoute(index)
    for i, blip in ipairs(testBlips) do
        SetBlipRoute(blip, i == index)
    end
end

local function failTest(msg)
    notify(msg or 'License test failed.', 'error')
    Sunset.AwaitCallback('sunset:license:abortTest')
    CleanupPracticalTest()
end

function CleanupPracticalTest()
    practicalState = nil
    clearBlips()
    clearTargets()
    HideLicenseTestHud()
    if testVehicle ~= 0 and DoesEntityExist(testVehicle) then
        DeleteEntity(testVehicle)
    end
    testVehicle = 0
    weaponServerHits = 0
    RemoveWeaponFromPed(PlayerPedId(), joaat('WEAPON_PISTOL'))
end

local function completeTest(licenseType, extra)
    local ok, err = Sunset.AwaitCallback('sunset:license:validateFinish', licenseType, extra or {})
    if not ok then
        return failTest(err)
    end
    local granted, gErr = Sunset.AwaitCallback('sunset:license:completePractical', licenseType)
    if not granted then
        return failTest(gErr)
    end
    notify('License issued — check /licenses.', 'success')
    CreateThread(function()
        ShowLicenseTestHud({
            licenseType = licenseType,
            state = 'success',
            title = 'Test Passed',
            message = 'Congratulations — your license has been issued.',
            progress = 100,
        })
        Wait(2500)
        CleanupPracticalTest()
    end)
end

local function briefingRequirementMet(step, cfg, spawn)
    local req = step and step.require
    if not req then return true end
    local state = GetTestVehicleState()
    local pos = GetEntityCoords(PlayerPedId())
    if req == 'engine_on' then
        if state and state.engineOn == true then return true end
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        return veh ~= 0 and GetIsVehicleEngineRunning(veh)
    end
    if req == 'seatbelt' then return state and state.seatbelt == true end
    if req == 'lights' then return state and (state.lightMode or 0) > 0 end
    if req == 'depart' then
        if cfg.departGate then
            local gp = vector3(cfg.departGate.x, cfg.departGate.y, cfg.departGate.z)
            return #(pos - gp) <= (cfg.gateRadius or 10.0)
        end
        if spawn then
            local sp = vector3(spawn.x, spawn.y, spawn.z)
            return #(pos - sp) >= (cfg.departureRadius or 14.0)
        end
    end
    if req == 'ready' then return false end
    return true
end

local function runBriefing(licenseType, cfg, spawn, onComplete)
    local steps = cfg.briefing or {}
    if #steps == 0 then
        if onComplete then onComplete() end
        return
    end

    local stepIndex = 1
    local readyPressed = false
    local stepShownAt = {}

    ShowLicenseTestHud({
        licenseType = licenseType,
        state = licenseType,
        title = steps[1].title or (licenseType == 'driver' and 'Driving School' or 'License Test'),
        step = 1,
        total = #steps,
        message = steps[1].message,
        progress = 0,
    })

    CreateThread(function()
        while practicalState and practicalState.licenseType == licenseType and stepIndex <= #steps do
            Wait(200)
            local step = steps[stepIndex]
            local met
            if not step.require then
                stepShownAt[stepIndex] = stepShownAt[stepIndex] or GetGameTimer()
                met = (GetGameTimer() - stepShownAt[stepIndex]) >= 3200
            else
                met = briefingRequirementMet(step, cfg, spawn)
            end
            if step.require == 'ready' and IsControlJustReleased(0, 38) then
                readyPressed = true
                met = true
            elseif step.require == 'ready' then
                met = readyPressed
            end

            UpdateLicenseTestHud({
                licenseType = licenseType,
                state = licenseType,
                title = step.title or (licenseType == 'driver' and 'Driving School' or 'License Test'),
                step = stepIndex,
                total = #steps,
                message = step.message,
                progress = math.floor(((stepIndex - 1) / #steps) * 100),
            })

            if met then
                stepIndex = stepIndex + 1
                readyPressed = false
                if stepIndex > #steps and onComplete then
                    onComplete()
                    return
                end
            end
        end
    end)
end

local function maxDriverPenalties(cfg)
    return cfg.maxPenalties or cfg.maxSpeedStrikes or 4
end

local function newPenaltyState(cfg)
    return {
        count = 0,
        max = maxDriverPenalties(cfg),
        countdownEnd = 0,
        lockUntil = 0,
    }
end

local function failOnPenalties(penalties, reason)
    if penalties.count >= penalties.max then
        failTest(reason or ('Too many penalties (%d/%d) — test failed.'):format(penalties.count, penalties.max))
        return true
    end
    return false
end

local function addPenalty(penalties, reason)
    penalties.count = penalties.count + 1
    penalties.countdownEnd = 0
    penalties.lockUntil = GetGameTimer() + 2500
    if failOnPenalties(penalties, reason) then
        return penalties.count, true
    end
    return penalties.count, false
end

local function isOverSpeedLimit(speed, limit, hard, cfg)
    local grace = cfg.speedGraceKmh or 5
    if speed > hard then return true end
    return speed > (limit + grace)
end

local function trackVehicleDamage(veh, cfg, penalties)
    penalties = penalties or newPenaltyState(cfg)
    if veh == 0 or not DoesEntityExist(veh) then return penalties end

    local body = GetVehicleBodyHealth(veh)
    local prevBody = penalties.lastBody or body
    penalties.lastBody = body

    if not HasEntityCollidedWithAnything(veh) then return penalties end

    local impactKmh = GetEntitySpeed(veh) * 3.6
    local minImpact = cfg.minImpactKmh or 28
    if impactKmh < minImpact then
        ClearEntityLastDamageEntity(veh)
        return penalties
    end

    if (prevBody - body) >= 18.0 and GetGameTimer() >= (penalties.lockUntil or 0) then
        local count, failed = addPenalty(penalties, ('Too many penalties (%d/%d) — test failed.'):format(
            penalties.count, penalties.max))
        UpdateLicenseTestHud({
            licenseType = 'driver',
            state = 'warning',
            title = 'Driving School',
            penalties = count,
            maxPenalties = penalties.max,
            message = ('PENALTY %d/%d — HARD IMPACT. Drive carefully.'):format(count, penalties.max),
        })
        if failed then return penalties end
    end
    ClearEntityLastDamageEntity(veh)
    return penalties
end

local function driverSpeedLimit(cpIndex, cfg, finishing)
    if finishing then return 40 end
    cpIndex = tonumber(cpIndex) or 1
    for _, zone in ipairs(cfg.speedZones or {}) do
        if cpIndex >= zone.from and cpIndex <= zone.to then
            return zone.limit or cfg.speedLimitDefault or 80
        end
    end
    return cfg.speedLimitDefault or 80
end

local function checkpointHint(cfg, cpIndex, finishing)
    if finishing then return cfg.finishHint end
    local hints = cfg.checkpointHints or {}
    return hints[cpIndex] or 'Follow the route markers and obey the speed limit.'
end

local function trackDriverSpeed(veh, cfg, cpIndex, finishing, penalties)
    penalties = penalties or newPenaltyState(cfg)
    penalties.max = maxDriverPenalties(cfg)
    if veh == 0 or not DoesEntityExist(veh) then
        return penalties, 0, driverSpeedLimit(cpIndex, cfg, finishing), checkpointHint(cfg, cpIndex, finishing), 'driver'
    end

    local speed = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)
    local limit = driverSpeedLimit(cpIndex, cfg, finishing)
    local hard = cfg.speedLimitHard or 115
    local countdownSec = cfg.speedCountdownSec or 5
    local now = GetGameTimer()
    local over = isOverSpeedLimit(speed, limit, hard, cfg)
    local message
    local state = 'driver'

    if over and now >= (penalties.lockUntil or 0) then
        state = 'warning'
        if penalties.countdownEnd <= 0 then
            penalties.countdownEnd = now + (countdownSec * 1000)
        end
        local remaining = math.max(1, math.ceil((penalties.countdownEnd - now) / 1000))
        message = ('REDUCE SPEED IN %d'):format(remaining)

        if now >= penalties.countdownEnd then
            if isOverSpeedLimit(speed, limit, hard, cfg) then
                local count, failed = addPenalty(penalties, ('Too many penalties (%d/%d) — test failed.'):format(
                    penalties.count, penalties.max))
                message = ('PENALTY %d/%d — YOU DID NOT SLOW DOWN.'):format(count, penalties.max)
                state = 'warning'
                if failed then
                    return penalties, speed, limit, message, state
                end
            else
                penalties.countdownEnd = 0
                message = checkpointHint(cfg, cpIndex, finishing)
                state = 'driver'
            end
        end
    else
        penalties.countdownEnd = 0
        message = checkpointHint(cfg, cpIndex, finishing)
    end

    return penalties, speed, limit, message, state
end

local function pickTestSpawn(cfg)
    local spawns = cfg.spawns
    if type(spawns) == 'table' and #spawns > 0 then
        return spawns[math.random(1, #spawns)]
    end
    return cfg.spawn
end

local function runDriverBriefing(cfg, spawn)
    local steps = cfg.briefing or {}
    if #steps == 0 then return end

    CreateThread(function()
        local stepIndex = 1
        local readyPressed = false
        local stepShownAt = {}
        local lastHudKey = ''

        while practicalState and practicalState.licenseType == 'driver' and stepIndex <= #steps do
            Wait(250)
            local step = steps[stepIndex]
            local met
            if not step.require then
                stepShownAt[stepIndex] = stepShownAt[stepIndex] or GetGameTimer()
                met = (GetGameTimer() - stepShownAt[stepIndex]) >= 2800
            else
                met = briefingRequirementMet(step, cfg, spawn)
            end
            if step.require == 'ready' and IsControlJustReleased(0, 38) then
                readyPressed = true
                met = true
            elseif step.require == 'ready' then
                met = readyPressed
            end

            local hudKey = ('%d:%s'):format(stepIndex, step.message or '')
            if hudKey ~= lastHudKey then
                lastHudKey = hudKey
                UpdateLicenseTestHud({
                    licenseType = 'driver',
                    state = 'driver',
                    title = step.title or 'Driving School',
                    step = stepIndex,
                    total = #steps,
                    message = step.message,
                    progress = math.floor(((stepIndex - 1) / #steps) * 100),
                })
            end

            if met then
                stepIndex = stepIndex + 1
                readyPressed = false
            end
        end
    end)
end

local function runDriverRoute(cfg, vehicle)
    local cpIndex = 1
    local penalties = newPenaltyState(cfg)
    penalties.lastBody = GetVehicleBodyHealth(vehicle)
    local hudMessage = checkpointHint(cfg, 1, false)
    local hudState = 'driver'
    local checkpoints = cfg.checkpoints or {}
    local checkpointNotify = {}

    addCheckpointBlips(checkpoints, 47)

    UpdateLicenseTestHud({
        licenseType = 'driver',
        state = 'driver',
        title = 'Driving School',
        checkpoint = 0,
        checkpoints = #checkpoints,
        penalties = 0,
        maxPenalties = penalties.max,
        speed = 0,
        speedLimit = driverSpeedLimit(1, cfg, false),
        message = hudMessage,
        progress = 0,
    })

    CreateThread(function()
        local lastHudKey = ''
        while practicalState and practicalState.licenseType == 'driver' do
            local waitMs = penalties.countdownEnd > 0 and 250 or 600
            Wait(waitMs)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local finishing = cpIndex > #checkpoints
            local speed, limit
            penalties, speed, limit, hudMessage, hudState = trackDriverSpeed(veh, cfg, cpIndex, finishing, penalties)
            local progress
            if finishing then
                progress = 95
            else
                progress = math.floor((math.max(cpIndex - 1, 0) / math.max(#checkpoints, 1)) * 100)
            end
            local hudKey = ('%d:%d:%d:%d:%s:%s'):format(
                cpIndex, speed or 0, penalties.count, penalties.countdownEnd or 0, hudState or '', hudMessage or '')
            if hudKey == lastHudKey then goto continue end
            lastHudKey = hudKey
            UpdateLicenseTestHud({
                licenseType = 'driver',
                state = hudState,
                title = 'Driving School',
                checkpoint = math.min(cpIndex - 1, #checkpoints),
                checkpoints = #checkpoints,
                penalties = penalties.count,
                maxPenalties = penalties.max,
                speed = speed,
                speedLimit = limit,
                message = hudMessage,
                progress = progress,
            })
            ::continue::
        end
    end)

    CreateThread(function()
        local started = GetGameTimer()
        local validationCooldown = 0
        local finishHudKey = ''
        while practicalState and practicalState.licenseType == 'driver' do
            Wait(0)
            if cfg.maxTimeSec and (GetGameTimer() - started) > cfg.maxTimeSec * 1000 then
                return failTest('Time expired — test failed.')
            end

            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            penalties = trackVehicleDamage(veh, cfg, penalties)

            if cpIndex <= #checkpoints then
                local cp = asVector3(checkpoints[cpIndex])
                local radius = cfg.checkpointRadius or 8.0
                if #(pos - cp) <= radius and GetGameTimer() >= validationCooldown then
                    validationCooldown = GetGameTimer() + 1000
                    local ok, err = Sunset.AwaitCallback('sunset:license:validateCheckpoint', 'driver', cpIndex)
                    if ok then
                        cpIndex = cpIndex + 1
                        updateRoute(cpIndex)
                        hudMessage = checkpointHint(cfg, cpIndex, cpIndex > #checkpoints)
                            UpdateLicenseTestHud({
                                licenseType = 'driver',
                                state = hudState,
                                title = 'Driving School',
                                checkpoint = cpIndex - 1,
                                checkpoints = #checkpoints,
                                penalties = penalties.count,
                                maxPenalties = penalties.max,
                                message = ('Checkpoint %d/%d — %s'):format(cpIndex - 1, #checkpoints, hudMessage),
                                progress = math.floor(((cpIndex - 1) / math.max(#checkpoints, 1)) * 100),
                            })
                    elseif err then
                        notifyOnce(checkpointNotify, err, 'error')
                    end
                end
            else
                local finish = cfg.finish
                if finish then
                    local fr = cfg.finishRadius or 10.0
                    local fp = asVector3(finish)
                    if #(pos - fp) <= fr then
                        local engineOn = veh ~= 0 and GetIsVehicleEngineRunning(veh)
                        local finishMsg = engineOn
                            and 'Turn off the engine, then press E to finish.'
                            or 'Press E to finish the driving test.'
                        local finishKey = engineOn and 'engine_on' or 'engine_off'
                        if finishKey ~= finishHudKey then
                            finishHudKey = finishKey
                            UpdateLicenseTestHud({
                                licenseType = 'driver',
                                state = 'driver',
                                title = 'Driving School',
                                checkpoint = #checkpoints,
                                checkpoints = #checkpoints,
                                penalties = penalties.count,
                                maxPenalties = penalties.max,
                                message = finishMsg,
                                progress = 95,
                            })
                        end
                        if IsControlJustReleased(0, 38) then
                            return completeTest('driver', {
                                engineOn = engineOn,
                                penalties = penalties.count,
                            })
                        end
                    else
                        finishHudKey = ''
                    end
                end
            end
        end
    end)
end

local function runDriverTest(cfg)
    local spawn = pickTestSpawn(cfg)
    if not spawn then return failTest('Driving test spawn is not configured.') end

    local vehicle, spawnError = spawnTestVehicle(cfg.vehicle or 'blista', spawn, {
        engineOff = cfg.engineOffOnSpawn == true,
    })
    if not vehicle then return failTest(spawnError or 'Could not spawn the training vehicle.') end

    local steps = cfg.briefing or {}
    ShowLicenseTestHud({
        licenseType = 'driver',
        state = 'driver',
        title = (steps[1] and steps[1].title) or 'Driving School',
        step = #steps > 0 and 1 or nil,
        total = #steps > 0 and #steps or nil,
        checkpoint = 0,
        checkpoints = #(cfg.checkpoints or {}),
        penalties = 0,
        maxPenalties = maxDriverPenalties(cfg),
        message = (steps[1] and steps[1].message) or 'Follow the orange GPS route to each checkpoint.',
        progress = 0,
    })

    runDriverBriefing(cfg, spawn)
    runDriverRoute(cfg, vehicle)
end

local function runWeaponTest(cfg)
    local ped = PlayerPedId()
    local targetNetIds = {}
    for i, t in ipairs(cfg.targets or {}) do
        local model = joaat('prop_range_target_01')
        if loadModel(model) then
            local obj = CreateObject(model, t.x, t.y, t.z - 1.0, true, true, false)
            SetEntityHeading(obj, t.w or 0.0)
            FreezeEntityPosition(obj, true)
            targetProps[#targetProps + 1] = obj
            local netId = ObjToNet(obj)
            SetNetworkIdCanMigrate(netId, true)
            targetNetIds[#targetNetIds + 1] = netId
        end
    end
    local registered, registerError
    for _ = 1, 20 do
        registered, registerError = Sunset.AwaitCallback('sunset:license:registerWeaponTargets', targetNetIds)
        if registered then break end
        Wait(100)
    end
    if not registered then return failTest(registerError or 'The range targets could not be verified.') end
    weaponServerHits = 0

    runBriefing('weapon', cfg, nil, function()
        GiveWeaponToPed(ped, joaat(cfg.weapon or 'WEAPON_PISTOL'), cfg.ammo or 48, false, true)
        ShowLicenseTestHud({
            licenseType = 'weapon',
            state = 'weapon',
            title = 'LSSI Firearms Range',
            targetsHit = 0,
            targetsRequired = cfg.targetsRequired or 5,
            message = 'Hit every target, then return to the booth and press E.',
            progress = 0,
        })

    CreateThread(function()
        local claimed = {}
        while practicalState and practicalState.licenseType == 'weapon' do
            Wait(0)
            if IsPedShooting(ped) then
                for index, target in ipairs(targetProps) do
                    if not claimed[index] and DoesEntityExist(target)
                        and HasEntityBeenDamagedByEntity(target, ped, true) then
                        local accepted = Sunset.AwaitCallback(
                            'sunset:license:claimWeaponTargetHit', ObjToNet(target))
                        if accepted then claimed[index] = true end
                        ClearEntityLastDamageEntity(target)
                    end
                end
            end
            local booth = SunsetLicenses.Facilities.range.marker
            local pos = GetEntityCoords(ped)
            if weaponServerHits >= (cfg.targetsRequired or 5) and #(pos - booth) <= 5.5 then
                DrawMarker(1, booth.x, booth.y, booth.z - 1.0, 0, 0, 0, 0, 0, 0,
                    1.8, 1.8, 1.0, 255, 145, 25, 120, false, false, 2, false, nil, nil, false)
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentString('Press ~INPUT_CONTEXT~ to finish the verified range test')
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustReleased(0, 38) then return completeTest('weapon') end
            else
                UpdateLicenseTestHud({
                    licenseType = 'weapon',
                    state = 'weapon',
                    title = 'LSSI Firearms Range',
                    targetsHit = weaponServerHits,
                    targetsRequired = cfg.targetsRequired or 5,
                    message = 'Keep firing at the marked targets downrange.',
                    progress = math.floor((weaponServerHits / (cfg.targetsRequired or 5)) * 100),
                })
            end
        end
    end)
    end)
end

RegisterNetEvent('sunset:licenses:weaponProgress', function(hits, required)
    weaponServerHits = tonumber(hits) or 0
    UpdateLicenseTestHud({
        licenseType = 'weapon',
        state = 'weapon',
        title = 'LSSI Firearms Range',
        targetsHit = weaponServerHits,
        targetsRequired = tonumber(required) or 5,
        message = ('Target %d/%d verified.'):format(weaponServerHits, tonumber(required) or 5),
        progress = math.floor((weaponServerHits / math.max(tonumber(required) or 5, 1)) * 100),
    })
end)

local function runCheckpointTest(licenseType, cfg, facility)
    local cpIndex = 1
    addCheckpointBlips(cfg.checkpoints, 2)
    notify('Complete all checkpoints, then return to the finish marker.', 'info')

    if licenseType ~= 'driver' then
        local model = (facility and facility.testVehicle) or cfg.vehicle or 'blista'
        local spawn = facility and facility.spawn or cfg.spawn
        if spawn then
            local vehicle, spawnError = spawnTestVehicle(model, spawn, {
                engineOff = cfg.engineOffOnSpawn == true,
            })
            if not vehicle then return failTest(spawnError or 'Could not spawn the test vehicle.') end
        end
    elseif cfg.spawn and cfg.vehicle then
        local vehicle, spawnError = spawnTestVehicle(cfg.vehicle, cfg.spawn, {
            engineOff = cfg.engineOffOnSpawn == true,
        })
        if not vehicle then return failTest(spawnError or 'Could not spawn the training vehicle.') end
    end

    CreateThread(function()
        local started = GetGameTimer()
        local validationCooldown = 0
        while practicalState and practicalState.licenseType == licenseType do
            Wait(0)
            if cfg.maxTimeSec and (GetGameTimer() - started) > cfg.maxTimeSec * 1000 then
                return failTest('Time expired — test failed.')
            end
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local cps = cfg.checkpoints or {}
            if cpIndex <= #cps then
                local cp = asVector3(cps[cpIndex])
                local radius = cfg.checkpointRadius or 8.0
                if #(pos - cp) <= radius and GetGameTimer() >= validationCooldown then
                    validationCooldown = GetGameTimer() + 1000
                    local ok, err = Sunset.AwaitCallback('sunset:license:validateCheckpoint', licenseType, cpIndex)
                    if ok then
                        cpIndex = cpIndex + 1
                        updateRoute(cpIndex)
                        notify(('Checkpoint %d/%d passed.'):format(cpIndex - 1, #cps), 'success')
                    elseif err then
                        notify(err, 'error')
                    end
                end
            else
                local finish = cfg.finish
                if finish then
                    local fr = cfg.finishRadius or 10.0
                    local fp = asVector3(finish)
                    if #(pos - fp) <= fr then
                        local veh = GetVehiclePedIsIn(ped, false)
                        local engineOn = veh ~= 0 and GetIsVehicleEngineRunning(veh)
                        if IsControlJustReleased(0, 38) then
                            return completeTest(licenseType, { engineOn = engineOn })
                        end
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentString('Press ~INPUT_CONTEXT~ to finish (engine off if required)')
                        EndTextCommandDisplayHelp(0, false, true, -1)
                    end
                end
            end
        end
    end)
end

function StartPracticalTest(licenseType, payload)
    CleanupPracticalTest()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    practicalState = { licenseType = licenseType }
    local cfg = resolvePracticalCfg(licenseType, payload)
    local facility = payload and payload.facility
    if not cfg then return failTest('Practical test not configured.') end
    if licenseType == 'weapon' then
        runWeaponTest(cfg)
    elseif licenseType == 'driver' then
        runDriverTest(cfg)
    else
        runCheckpointTest(licenseType, cfg, facility)
    end
end

exports('StartPracticalTest', StartPracticalTest)
exports('CleanupPracticalTest', CleanupPracticalTest)
