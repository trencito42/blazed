local seatbelt = false
local locked = false
local lightMode = 0 -- 0 off, 1 low, 2 high
local currentVeh = 0
local fuel = 100.0
local spawnedOwnedVehicle = nil
local protectedVehicles = {}
local lastBodyHealth = 1000.0
local lastVehSpeed = 0.0

-- RP-friendly ejection: hard crashes only (not every bump)
local EJECT_PARAMS = { 48.0, 52.0, 17.0, 1200.0 }
local NO_EJECT_PARAMS = { 10000.0, 10000.0, 17.0, 0.0 }

local function getVeh()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return 0
end

local function isDriver()
    local veh = getVeh()
    return veh ~= 0 and GetPedInVehicleSeat(veh, -1) == PlayerPedId()
end

local function isPassenger()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end
    return GetPedInVehicleSeat(GetVehiclePedIsIn(ped, false), -1) ~= ped
end

local function notify(msg, type)
    exports.sunset_ui:Notify(msg, type or 'info')
end

local function blocked()
    if IsNuiFocused() or IsPauseMenuActive() then return true end
    local ok, open = pcall(function()
        return exports.sunset_chat:IsChatOpen()
    end)
    return ok and open == true
end

local function driverOnly()
    if isPassenger() then
        notify('Only the driver can do that', 'error')
        return false
    end
    return true
end

local function syncLockState(veh)
    if veh == 0 then return end
    local state = GetVehicleDoorLockStatus(veh)
    locked = state == 2 or state == 3 or state == 4
end

-- ═══ LOCK (N) ═══
RegisterCommand('sunset_lock', function()
    if blocked() then return end
    if isPassenger() then return notify('Only the driver can do that', 'error') end

    local ped = PlayerPedId()
    local veh = getVeh()
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end
    if veh == 0 then return notify('No vehicle nearby', 'error') end

    locked = not locked
    SetVehicleDoorsLocked(veh, locked and 2 or 1)
    notify(locked and 'Locked' or 'Unlocked', locked and 'success' or 'info')
end, false)
RegisterKeyMapping('sunset_lock', 'Lock vehicle', 'keyboard', 'N')

-- ═══ SEATBELT (K) ═══
RegisterCommand('sunset_seatbelt', function()
    if blocked() then return end
    if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    seatbelt = not seatbelt
    notify(seatbelt and 'Seatbelt ON' or 'Seatbelt OFF', seatbelt and 'success' or 'warning')
end, false)
RegisterKeyMapping('sunset_seatbelt', 'Seatbelt', 'keyboard', 'K')

-- ═══ ENGINE (2) ═══
RegisterCommand('sunset_engine', function()
    if blocked() then return end
    if not driverOnly() then return end
    local veh = getVeh()
    if veh == 0 then return end
    local on = not GetIsVehicleEngineRunning(veh)
    SetVehicleEngineOn(veh, on, false, true)
    notify(on and 'Engine on' or 'Engine off', 'info')
end, false)
RegisterKeyMapping('sunset_engine', 'Motor on/off', 'keyboard', '2')

-- ═══ LIGHTS (H) — off → low → high ═══
RegisterCommand('sunset_lights', function()
    if blocked() then return end
    if not driverOnly() then return end
    local veh = getVeh()
    if veh == 0 then return end

    lightMode = (lightMode + 1) % 3

    if lightMode == 0 then
        SetVehicleLights(veh, 1)
        SetVehicleFullbeam(veh, false)
    elseif lightMode == 1 then
        SetVehicleLights(veh, 2)
        SetVehicleFullbeam(veh, false)
    else
        SetVehicleLights(veh, 2)
        SetVehicleFullbeam(veh, true)
    end
end, false)
RegisterKeyMapping('sunset_lights', 'Vehicle lights', 'keyboard', 'H')

local function applySeatbeltPhysics(ped)
    if seatbelt then
        SetPedConfigFlag(ped, 32, false)
        SetFlyThroughWindscreenParams(NO_EJECT_PARAMS[1], NO_EJECT_PARAMS[2], NO_EJECT_PARAMS[3], NO_EJECT_PARAMS[4])
    else
        SetPedConfigFlag(ped, 32, true)
        SetFlyThroughWindscreenParams(EJECT_PARAMS[1], EJECT_PARAMS[2], EJECT_PARAMS[3], EJECT_PARAMS[4])
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            syncLockState(veh)
            applySeatbeltPhysics(ped)
            Wait(0)
        else
            seatbelt = false
            lightMode = 0
            lastBodyHealth = 1000.0
            lastVehSpeed = 0.0
            Wait(500)
        end
    end
end)

local function computeFuelDrain(veh)
    local profiles = Sunset.VehicleProfiles or {}
    local base = profiles.fuelBase or 0.0035
    local class = GetVehicleClass(veh)
    local model = GetEntityModel(veh)
    local classMult = Sunset.GetVehicleFuelMultiplier(model, class)

    if classMult <= 0 then return 0 end

    local rpm = GetVehicleCurrentRpm(veh)
    local speedKmh = GetEntitySpeed(veh) * 3.6
    if speedKmh <= 1.0 and rpm < 0.15 then
        return base * classMult * 0.15 * rpm
    end

    local rpmFactor = 0.25 + (rpm * 0.75)
    local speedFactor = math.min(speedKmh / 160.0, 1.0)
    return base * classMult * (rpmFactor + speedFactor * 0.35)
end

local function applyCollisionDamage(veh)
    local body = GetVehicleBodyHealth(veh)
    local speed = GetEntitySpeed(veh)
    local bodyLoss = lastBodyHealth - body
    local speedDrop = lastVehSpeed - speed

    if bodyLoss > 8.0 and (lastVehSpeed > 8.0 or speedDrop > 4.0) then
        local profile = Sunset.GetVehicleDamageProfile(GetEntityModel(veh), GetVehicleClass(veh))
        local engineScale = profile.engine or 1.0
        local bodyScale = profile.body or 1.0
        local scaledLoss = bodyLoss * engineScale * bodyScale * 0.45
        if scaledLoss > 0.5 then
            local eng = GetVehicleEngineHealth(veh)
            SetVehicleEngineHealth(veh, math.max(150.0, eng - scaledLoss))
        end
    end

    lastBodyHealth = body
    lastVehSpeed = speed
end

CreateThread(function()
    while true do
        local veh = getVeh()
        if veh ~= 0 and isDriver() then
            if veh ~= currentVeh then
                currentVeh = veh
                fuel = GetVehicleFuelLevel(veh)
                if fuel < 0 or fuel > 100 then
                    fuel = math.max(0, math.min(100, fuel))
                end
                SetVehicleFuelLevel(veh, fuel)
                lastBodyHealth = GetVehicleBodyHealth(veh)
                lastVehSpeed = GetEntitySpeed(veh)
                local _, lightsOn, highbeams = GetVehicleLightsState(veh)
                if highbeams == 1 then lightMode = 2
                elseif lightsOn == 1 then lightMode = 1
                else lightMode = 0 end
            end

            applyCollisionDamage(veh)

            local drain = computeFuelDrain(veh)
            if drain > 0 then
                fuel = math.max(0, fuel - drain)
                SetVehicleFuelLevel(veh, fuel)
            end
            if fuel <= 0 then SetVehicleEngineOn(veh, false, true, true) end
            Wait(1000)
        else
            currentVeh = 0
            Wait(500)
        end
    end
end)

function GetVehicleState()
    local veh = getVeh()
    if veh == 0 or not isDriver() then return nil end

    local speed = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)
    local gear = GetVehicleCurrentGear(veh)
    local rpm = GetVehicleCurrentRpm(veh)

    return {
        inVehicle = true,
        speed = speed,
        gear = gear,
        rpm = rpm,
        fuel = fuel,
        engine = GetVehicleEngineHealth(veh),
        locked = locked,
        seatbelt = seatbelt,
        lightMode = lightMode,
        engineOn = GetIsVehicleEngineRunning(veh),
    }
end
RegisterNetEvent('sunset:client:notify', function(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end)

exports('GetVehicleState', GetVehicleState)

-- ═══ OWNED VEHICLES / GARAGE ═══

local function markProtected(veh)
    if veh and veh ~= 0 then
        protectedVehicles[veh] = true
    end
end

local function unmarkProtected(veh)
    if veh then protectedVehicles[veh] = nil end
end

local function normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

local function deleteVehicleEntity(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    unmarkProtected(veh)
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    if DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
end

local function plateTextMatches(vehPlate, target)
    local a = normalizePlate(vehPlate)
    local b = normalizePlate(target)
    if a == '' or b == '' then return false end
    if a == b then return true end
    return a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

local function findVehicleByPlate(plate)
    local target = normalizePlate(plate)
    if target == '' then return nil end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local current = GetVehiclePedIsIn(ped, false)
        if plateTextMatches(GetVehicleNumberPlateText(current), target) then
            return current
        end
    end

    if spawnedOwnedVehicle and DoesEntityExist(spawnedOwnedVehicle) then
        if plateTextMatches(GetVehicleNumberPlateText(spawnedOwnedVehicle), target) then
            return spawnedOwnedVehicle
        end
    end

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if plateTextMatches(GetVehicleNumberPlateText(veh), target) then
            return veh
        end
    end

    return nil
end

exports('IsPlateInWorld', function(plate)
    return findVehicleByPlate(plate) ~= nil
end)

exports('IsProtectedVehicle', function(veh)
    if not veh or veh == 0 then return false end
    if protectedVehicles[veh] then return true end
    if spawnedOwnedVehicle and spawnedOwnedVehicle == veh then return true end
    return false
end)

local function deleteVehicleByPlate(plate)
    local veh = findVehicleByPlate(plate)
    if not veh then return end
    deleteVehicleEntity(veh)
    if spawnedOwnedVehicle == veh then
        spawnedOwnedVehicle = nil
    end
end

RegisterNetEvent('sunset:client:cleanupOwnedVehicles', function(plates)
    if spawnedOwnedVehicle then
        deleteVehicleEntity(spawnedOwnedVehicle)
        spawnedOwnedVehicle = nil
    end
    for _, row in ipairs(plates or {}) do
        deleteVehicleByPlate(row.plate or row)
    end
end)

local function normalizeVehicleStats(vehData)
    local fuel = tonumber(vehData.fuel)
    local engine = tonumber(vehData.engine)
    local body = tonumber(vehData.body)

    if not fuel or fuel < 0 or fuel > 100 then fuel = 100.0 end
    if not engine or engine < 150 or engine > 1000 then engine = 1000.0 end
    if not body or body < 150 or body > 1000 then body = 1000.0 end

    return fuel, engine, body
end

local function hasParkedPosition(vehData)
    return vehData
        and tonumber(vehData.parked_x) ~= nil
        and tonumber(vehData.parked_y) ~= nil
        and tonumber(vehData.parked_z) ~= nil
end

local function getSpawnPoint(opts)
    if opts and opts.x and opts.y and opts.z then
        return opts.x, opts.y, opts.z, opts.w or opts.h or 0.0
    end

    local spawn = opts or {}
    return spawn.x, spawn.y, spawn.z, spawn.w or spawn.h or 0.0
end

local function getParkedCoords(vehData)
    if not hasParkedPosition(vehData) then return nil end
    return {
        x = tonumber(vehData.parked_x),
        y = tonumber(vehData.parked_y),
        z = tonumber(vehData.parked_z),
    }
end

local function captureParkedPosition(entity)
    if not entity or entity == 0 then return nil end
    local coords = GetEntityCoords(entity)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = GetEntityHeading(entity),
    }
end

RegisterNetEvent('sunset:client:spawnOwnedVehicle', function(vehData, spawnOpts)
    deleteVehicleByPlate(vehData.plate)
    Wait(200)

    local model = joaat(vehData.model)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        notify('Invalid vehicle model: ' .. tostring(vehData.model), 'error')
        return
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then
            notify('Failed to load vehicle model', 'error')
            return
        end
        Wait(10)
    end

    local vehFuel, vehEngine, vehBody = normalizeVehicleStats(vehData)
    local sx, sy, sz, heading = getSpawnPoint(spawnOpts)
    RequestCollisionAtCoord(sx, sy, sz)

    local vehicle = 0
    for i = 0, 4 do
        local ox = (i % 2 == 0) and (i * 2.2) or (-i * 2.2)
        local oy = math.floor(i / 2) * 2.2
        vehicle = CreateVehicle(model, sx + ox, sy + oy, sz, heading, true, false)
        if vehicle ~= 0 then break end
        Wait(50)
    end

    if vehicle == 0 then
        SetModelAsNoLongerNeeded(model)
        notify('Could not spawn vehicle — move to open space', 'error')
        return
    end

    SetVehicleNumberPlateText(vehicle, vehData.plate)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, 'OFF')
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleFuelLevel(vehicle, vehFuel)
    SetVehicleEngineHealth(vehicle, vehEngine)
    SetVehicleBodyHealth(vehicle, vehBody)
    local engineOn = vehFuel > 0 and vehEngine > 250.0
    SetVehicleEngineOn(vehicle, engineOn, true, false)
    SetModelAsNoLongerNeeded(model)

    spawnedOwnedVehicle = vehicle
    markProtected(vehicle)
    fuel = vehFuel
    currentVeh = 0
    notify(('Vehicle spawned: %s (fuel %d%%)'):format(vehData.plate, math.floor(vehFuel)), 'success')
end)

local function showGaragePanel(vehicles)
    for _, v in ipairs(vehicles or {}) do
        v.inWorld = findVehicleByPlate(v.plate) ~= nil
    end
    exports.sunset_ui:Send('garageShow', { vehicles = vehicles })
    exports.sunset_ui:SetFocus(true, true, false)
end

RegisterNetEvent('sunset:client:garageMenu', function(vehicles)
    showGaragePanel(vehicles)
end)

local function openGaragePanel()
    if blocked() then return end
    CreateThread(function()
        local vehicles = Sunset.AwaitCallback('sunset:getVehicles') or {}
        showGaragePanel(vehicles)
    end)
end

RegisterCommand('v', openGaragePanel, false)
RegisterCommand('garage', openGaragePanel, false)

TriggerEvent('chat:addSuggestion', '/v', 'Personal vehicle garage')
TriggerEvent('chat:addSuggestion', '/garage', 'Personal vehicle garage')

AddEventHandler('sunset:nui:garageSpawn', function(data)
    CreateThread(function()
        local ok, err = Sunset.AwaitCallback('sunset:spawnVehicle', data.vehicleId)
        if not ok then
            notify(err or 'Could not spawn vehicle', 'error')
        end
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Send('garageHide', {})
    end)
end)

AddEventHandler('sunset:nui:garageStore', function(data)
    CreateThread(function()
        local vehData = Sunset.AwaitCallback('sunset:getVehicleById', data.vehicleId)
        if not vehData then
            notify('Vehicle not found', 'error')
            return
        end
        if vehData.stored == 1 then
            notify('Already in garage', 'info')
            return
        end

        local entity = findVehicleByPlate(vehData.plate)
        local props = { model = joaat(vehData.model) }
        local vehFuel = vehData.fuel or 100.0
        local vehEngine = vehData.engine or 1000.0
        local vehBody = vehData.body or 1000.0

        if entity then
            props.model = GetEntityModel(entity)
            vehFuel = GetVehicleFuelLevel(entity)
            vehEngine = GetVehicleEngineHealth(entity)
            vehBody = GetVehicleBodyHealth(entity)
            deleteVehicleEntity(entity)
            if spawnedOwnedVehicle == entity then spawnedOwnedVehicle = nil end
        end

        local plate = normalizePlate(vehData.plate)
        local parked = captureParkedPosition(entity)
        TriggerServerEvent('sunset:server:vehicleStored', plate, props, vehFuel, vehEngine, vehBody, vehData.garage or 'legion', parked)
        notify('Vehicle stored in garage', 'success')
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Send('garageHide', {})
    end)
end)

AddEventHandler('sunset:nui:garageLocate', function(data)
    local entity = findVehicleByPlate(data.plate)
    if entity then
        local coords = GetEntityCoords(entity)
        SetNewWaypoint(coords.x, coords.y)
        notify('GPS set to ' .. normalizePlate(data.plate), 'success')
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Send('garageHide', {})
        return
    end

    local vehData = nil
    if data.vehicleId then
        vehData = Sunset.AwaitCallback('sunset:getVehicleById', tonumber(data.vehicleId))
    end

    local parked = vehData and getParkedCoords(vehData) or nil
    if parked then
        SetNewWaypoint(parked.x, parked.y)
        notify('GPS set to parked location: ' .. normalizePlate(data.plate or vehData.plate), 'success')
    else
        notify('Vehicle not found — no parked location saved', 'error')
    end
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('garageHide', {})
end)

AddEventHandler('sunset:nui:garageClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('garageHide', {})
end)

RegisterNetEvent('sunset:client:storeVehicleRequest', function(garageId)
    local veh = getVeh()
    if veh == 0 or not isDriver() then return notify('You must be driving your vehicle', 'error') end
    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    local props = { model = GetEntityModel(veh) }
    local parked = captureParkedPosition(veh)
    TriggerServerEvent('sunset:server:vehicleStored', plate, props, fuel, GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh), garageId, parked)
    deleteVehicleEntity(veh)
    if spawnedOwnedVehicle == veh then spawnedOwnedVehicle = nil end
    notify('Vehicle stored', 'success')
end)

AddEventHandler('sunset:world:garageStore', function(garageId)
    local veh = getVeh()
    if veh == 0 or not isDriver() then
        notify('You must be driving your vehicle to store it', 'error')
        return
    end
    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    local parked = captureParkedPosition(veh)
    TriggerServerEvent('sunset:server:vehicleStored', plate, { model = GetEntityModel(veh) }, fuel,
        GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh), garageId, parked)
    deleteVehicleEntity(veh)
    if spawnedOwnedVehicle == veh then spawnedOwnedVehicle = nil end
    notify('Vehicle stored', 'success')
end)

local function setFuelLevel(veh, level)
    level = math.max(0.0, math.min(100.0, tonumber(level) or 0))
    fuel = level
    if veh and veh ~= 0 then
        SetVehicleFuelLevel(veh, level)
    end
end

exports('SetFuelLevel', setFuelLevel)

exports('GetFuelLevel', function()
    return fuel
end)

