local practicalState = nil
local testVehicle = 0
local testBlips = {}
local targetProps = {}
local weaponServerHits = 0

local function notify(msg, kind)
    exports.sunset_ui:Notify(msg, kind or 'info', 7000)
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
        local blip = AddBlipForCoord(cp.x, cp.y, cp.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, color or 2)
        SetBlipRoute(blip, i == 1)
        SetBlipRouteColour(blip, color or 2)
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
    if req == 'engine_on' then return state and state.engineOn == true end
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

local function trackVehicleDamage(veh, cfg, collisions)
    collisions = collisions or { count = 0, lastBody = 0.0 }
    if veh == 0 or not DoesEntityExist(veh) then return collisions end
    if collisions.lastBody <= 0.0 then
        collisions.lastBody = GetVehicleBodyHealth(veh)
    end
    if HasEntityCollidedWithAnything(veh) then
        local body = GetVehicleBodyHealth(veh)
        if body < collisions.lastBody - 18.0 then
            collisions.count = collisions.count + 1
            collisions.lastBody = body
            local maxHits = cfg.maxCollisions or 3
            UpdateLicenseTestHud({
                licenseType = 'driver',
                state = collisions.count >= maxHits and 'warning' or 'driver',
                title = 'Driving School',
                collisions = collisions.count,
                maxCollisions = maxHits,
                message = ('Vehicle contact recorded (%d/%d). Drive carefully.'):format(collisions.count, maxHits),
                progress = nil,
            })
            if collisions.count >= maxHits then
                failTest(('Too many collisions (%d/%d) — test failed.'):format(collisions.count, maxHits))
            end
        end
        ClearEntityLastDamageEntity(veh)
    end
    return collisions
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

local function trackDriverSpeed(veh, cfg, cpIndex, finishing, state)
    state = state or { strikes = 0, overLimitSince = 0, hardSince = 0 }
    if veh == 0 or not DoesEntityExist(veh) then return state, 0, driverSpeedLimit(cpIndex, cfg, finishing), nil end

    local speed = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)
    local limit = driverSpeedLimit(cpIndex, cfg, finishing)
    local hard = cfg.speedLimitHard or 115
    local maxStrikes = cfg.maxSpeedStrikes or 4
    local now = GetGameTimer()
    local message

    if speed > hard then
        if state.hardSince == 0 then state.hardSince = now end
        message = ('Slow down now! %d km/h is reckless — max %d on this exam.'):format(speed, hard)
        if now - state.hardSince >= 1800 then
            state.strikes = state.strikes + 1
            state.hardSince = now
            message = ('Speed violation %d/%d — ease off the throttle immediately.'):format(state.strikes, maxStrikes)
        end
    else
        state.hardSince = 0
        if speed > limit + 8 then
            if state.overLimitSince == 0 then state.overLimitSince = now end
            message = ('Slow down — %d km/h. Limit here is %d km/h.'):format(speed, limit)
            if now - state.overLimitSince >= 2800 then
                state.strikes = state.strikes + 1
                state.overLimitSince = now
                message = ('Speed warning %d/%d — drive like an exam, not a race.'):format(state.strikes, maxStrikes)
            end
        else
            state.overLimitSince = 0
            message = checkpointHint(cfg, cpIndex, finishing)
        end
    end

    if state.strikes >= maxStrikes then
        failTest(('Too many speed violations (%d/%d) — test failed.'):format(state.strikes, maxStrikes))
    end

    return state, speed, limit, message
end

local function pickTestSpawn(cfg)
    local spawns = cfg.spawns
    if type(spawns) == 'table' and #spawns > 0 then
        return spawns[math.random(1, #spawns)]
    end
    return cfg.spawn
end

local function runDriverTest(cfg)
    local spawn = pickTestSpawn(cfg)
    if not spawn then return failTest('Driving test spawn is not configured.') end

    local vehicle, spawnError = spawnTestVehicle(cfg.vehicle or 'blista', spawn, {
        engineOff = cfg.engineOffOnSpawn == true,
    })
    if not vehicle then return failTest(spawnError or 'Could not spawn the training vehicle.') end

    runBriefing('driver', cfg, spawn, function()
        local cpIndex = 1
        local collisions = { count = 0, lastBody = GetVehicleBodyHealth(vehicle) }
        local speedState = { strikes = 0, overLimitSince = 0, hardSince = 0 }
        local hudMessage = checkpointHint(cfg, 1, false)
        addCheckpointBlips(cfg.checkpoints, 2)

        ShowLicenseTestHud({
            licenseType = 'driver',
            state = 'driver',
            title = 'Driving School',
            checkpoint = 0,
            checkpoints = #(cfg.checkpoints or {}),
            collisions = 0,
            maxCollisions = cfg.maxCollisions or 3,
            speed = 0,
            speedLimit = driverSpeedLimit(1, cfg, false),
            speedStrikes = 0,
            maxSpeedStrikes = cfg.maxSpeedStrikes or 4,
            message = hudMessage,
            progress = 0,
        })

        CreateThread(function()
            while practicalState and practicalState.licenseType == 'driver' do
                Wait(450)
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)
                local finishing = cpIndex > #(cfg.checkpoints or {})
                local speed, limit, msg
                speedState, speed, limit, msg = trackDriverSpeed(veh, cfg, cpIndex, finishing, speedState)
                if msg then hudMessage = msg end
                local progress
                if finishing then
                    progress = 95
                else
                    progress = math.floor((math.max(cpIndex - 1, 0) / math.max(#(cfg.checkpoints or {}), 1)) * 100)
                end
                UpdateLicenseTestHud({
                    licenseType = 'driver',
                    state = speedState.strikes >= 2 and 'warning' or 'driver',
                    title = 'Driving School',
                    checkpoint = math.min(cpIndex - 1, #(cfg.checkpoints or {})),
                    checkpoints = #(cfg.checkpoints or {}),
                    collisions = collisions.count,
                    maxCollisions = cfg.maxCollisions or 3,
                    speed = speed,
                    speedLimit = limit,
                    speedStrikes = speedState.strikes,
                    maxSpeedStrikes = cfg.maxSpeedStrikes or 4,
                    message = hudMessage,
                    progress = progress,
                })
            end
        end)

        CreateThread(function()
            local started = GetGameTimer()
            local validationCooldown = 0
            while practicalState and practicalState.licenseType == 'driver' do
                Wait(0)
                if cfg.maxTimeSec and (GetGameTimer() - started) > cfg.maxTimeSec * 1000 then
                    return failTest('Time expired — test failed.')
                end

                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                local veh = GetVehiclePedIsIn(ped, false)
                collisions = trackVehicleDamage(veh, cfg, collisions)

                local cps = cfg.checkpoints or {}
                if cpIndex <= #cps then
                    local cp = cps[cpIndex]
                    local radius = cfg.checkpointRadius or 8.0
                    DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0, 0, 0, 0, 0, 0, radius, radius, 2.0, 80, 200, 80, 100, false, false, 2, false, nil, nil, false)
                    if #(pos - cp) <= radius and GetGameTimer() >= validationCooldown then
                        validationCooldown = GetGameTimer() + 1000
                        local ok, err = Sunset.AwaitCallback('sunset:license:validateCheckpoint', 'driver', cpIndex)
                        if ok then
                            cpIndex = cpIndex + 1
                            updateRoute(cpIndex)
                            hudMessage = checkpointHint(cfg, cpIndex, cpIndex > #cps)
                            UpdateLicenseTestHud({
                                licenseType = 'driver',
                                state = 'driver',
                                title = 'Driving School',
                                checkpoint = cpIndex - 1,
                                checkpoints = #cps,
                                collisions = collisions.count,
                                maxCollisions = cfg.maxCollisions or 3,
                                speedStrikes = speedState.strikes,
                                maxSpeedStrikes = cfg.maxSpeedStrikes or 4,
                                message = ('Checkpoint %d/%d — %s'):format(cpIndex - 1, #cps, hudMessage),
                                progress = math.floor(((cpIndex - 1) / math.max(#cps, 1)) * 100),
                            })
                        elseif err then
                            notify(err, 'error')
                        end
                    end
                else
                    local finish = cfg.finish
                    if finish then
                        local fr = cfg.finishRadius or 10.0
                        local fp = type(finish) == 'vector3' and finish or vector3(finish.x, finish.y, finish.z)
                        DrawMarker(1, fp.x, fp.y, fp.z - 1.0, 0, 0, 0, 0, 0, 0, fr, fr, 2.0, 255, 180, 50, 120, false, false, 2, false, nil, nil, false)
                        if #(pos - fp) <= fr then
                            local engineOn = veh ~= 0 and GetIsVehicleEngineRunning(veh)
                            BeginTextCommandDisplayHelp('STRING')
                            AddTextComponentString('Press ~INPUT_CONTEXT~ to finish (engine off if required)')
                            EndTextCommandDisplayHelp(0, false, true, -1)
                            if IsControlJustReleased(0, 38) then
                                return completeTest('driver', {
                                    engineOn = engineOn,
                                    collisions = collisions.count,
                                    speedStrikes = speedState.strikes,
                                })
                            end
                        end
                    end
                end
            end
        end)
    end)
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
                local cp = cps[cpIndex]
                local radius = cfg.checkpointRadius or 8.0
                DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0, 0, 0, 0, 0, 0, radius, radius, 2.0, 80, 200, 80, 100, false, false, 2, false, nil, nil, false)
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
                    local fp = type(finish) == 'vector3' and finish or vector3(finish.x, finish.y, finish.z)
                    DrawMarker(1, fp.x, fp.y, fp.z - 1.0, 0, 0, 0, 0, 0, 0, fr, fr, 2.0, 255, 180, 50, 120, false, false, 2, false, nil, nil, false)
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
    practicalState = { licenseType = licenseType }
    local cfg = payload and payload.practical or SunsetLicenses.Practical[licenseType]
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
