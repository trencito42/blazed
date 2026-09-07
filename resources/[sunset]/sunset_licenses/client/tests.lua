local practicalState = nil
local testVehicle = 0
local testBlips = {}
local targetProps = {}

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

local function spawnTestVehicle(model, spawn)
    if testVehicle ~= 0 and DoesEntityExist(testVehicle) then
        DeleteEntity(testVehicle)
    end
    if not loadModel(model) then return nil end
    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(model)
    testVehicle = veh
    TriggerServerEvent('sunset:licenses:registerTestVehicle', VehToNet(veh))
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
    if testVehicle ~= 0 and DoesEntityExist(testVehicle) then
        DeleteEntity(testVehicle)
    end
    testVehicle = 0
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
    CleanupPracticalTest()
end

local function runWeaponTest(cfg)
    local ped = PlayerPedId()
    GiveWeaponToPed(ped, joaat(cfg.weapon or 'WEAPON_PISTOL'), cfg.ammo or 48, false, true)
    for i, t in ipairs(cfg.targets or {}) do
        local model = joaat('prop_range_target_01')
        if loadModel(model) then
            local obj = CreateObject(model, t.x, t.y, t.z - 1.0, false, false, false)
            SetEntityHeading(obj, t.w or 0.0)
            FreezeEntityPosition(obj, true)
            targetProps[#targetProps + 1] = obj
        end
    end
    notify('Hit all range targets, then press E at the booth to finish.', 'info')
    CreateThread(function()
        local hits = {}
        while practicalState and practicalState.licenseType == 'weapon' do
            Wait(0)
            if IsPedShooting(ped) then
                for i, obj in ipairs(targetProps) do
                    if DoesEntityExist(obj) and HasEntityBeenDamagedByEntity(obj, ped, true) then
                        if not hits[i] then
                            hits[i] = true
                            local ok, data = Sunset.AwaitCallback('sunset:license:weaponTargetHit', 'weapon', i)
                            if ok and data then
                                notify(('Target %d/%d hit.'):format(data.hits, data.required), 'success')
                            end
                            ClearEntityLastDamageEntity(obj)
                        end
                    end
                end
            end
            local count = 0
            for _ in pairs(hits) do count = count + 1 end
            if count >= (cfg.targetsRequired or 5) and IsControlJustReleased(0, 38) then
                return completeTest('weapon', { hits = count })
            end
        end
    end)
end

local function runCheckpointTest(licenseType, cfg, facility)
    local cpIndex = 1
    addCheckpointBlips(cfg.checkpoints, 2)
    notify('Complete all checkpoints, then return to the finish marker.', 'info')

    if licenseType ~= 'driver' then
        local model = (facility and facility.testVehicle) or cfg.vehicle or 'blista'
        local spawn = facility and facility.spawn or cfg.spawn
        if spawn and not spawnTestVehicle(model, spawn) then
            return failTest('Could not spawn the test vehicle.')
        end
    elseif cfg.spawn and cfg.vehicle then
        if not spawnTestVehicle(cfg.vehicle, cfg.spawn) then
            return failTest('Could not spawn the training vehicle.')
        end
    end

    CreateThread(function()
        local started = GetGameTimer()
        while practicalState and practicalState.licenseType == licenseType do
            Wait(250)
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
                if #(pos - cp) <= radius then
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
    else
        runCheckpointTest(licenseType, cfg, facility)
    end
end

exports('StartPracticalTest', StartPracticalTest)
exports('CleanupPracticalTest', CleanupPracticalTest)
