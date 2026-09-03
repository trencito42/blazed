local seatbelt = false
local locked = false
local lightMode = 0 -- 0 off, 1 low, 2 high
local currentVeh = 0
local fuel = 100.0

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
RegisterKeyMapping('sunset_lock', 'Încuie mașina', 'keyboard', 'N')

-- ═══ SEATBELT (K) ═══
RegisterCommand('sunset_seatbelt', function()
    if blocked() then return end
    if not isDriver() then return end
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
    notify(on and 'Motor pornit' or 'Motor oprit', 'info')
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
RegisterKeyMapping('sunset_lights', 'Faruri', 'keyboard', 'H')

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            syncLockState(veh)

            -- Fără ejectare prin geam (centura rămâne RP/visual)
            SetPedConfigFlag(ped, 32, false)
            SetFlyThroughWindscreenParams(10000.0, 10000.0, 17.0, 0.0)

            Wait(0)
        else
            seatbelt = false
            lightMode = 0
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        local veh = getVeh()
        if veh ~= 0 and isDriver() then
            if veh ~= currentVeh then
                currentVeh = veh
                fuel = GetVehicleFuelLevel(veh)
                if fuel <= 0 then fuel = 100.0 end
                local _, lightsOn, highbeams = GetVehicleLightsState(veh)
                if highbeams == 1 then lightMode = 2
                elseif lightsOn == 1 then lightMode = 1
                else lightMode = 0 end
            end

            if GetEntitySpeed(veh) * 3.6 > 1 then
                fuel = math.max(0, fuel - 0.008)
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

RegisterNetEvent('sunset:client:spawnOwnedVehicle', function(vehData, spawn)
    local model = joaat(vehData.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local vehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleNumberPlateText(vehicle, vehData.plate)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleFuelLevel(vehicle, vehData.fuel or 100.0)
    SetVehicleEngineHealth(vehicle, vehData.engine or 1000.0)
    SetVehicleBodyHealth(vehicle, vehData.body or 1000.0)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetModelAsNoLongerNeeded(model)
    notify('Vehicle spawned: ' .. vehData.plate, 'success')
end)

RegisterNetEvent('sunset:client:garageMenu', function(vehicles)
    exports.sunset_ui:Send('garageShow', { vehicles = vehicles })
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:nui:garageSpawn', function(data)
    Sunset.AwaitCallback('sunset:spawnVehicle', data.vehicleId)
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
    TriggerServerEvent('sunset:server:vehicleStored', plate, props, fuel, GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh), garageId)
    DeleteVehicle(veh)
    notify('Vehicle stored', 'success')
end)

AddEventHandler('sunset:world:garageStore', function(garageId)
    local veh = getVeh()
    if veh == 0 or not isDriver() then
        notify('You must be driving your vehicle to store it', 'error')
        return
    end
    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    TriggerServerEvent('sunset:server:vehicleStored', plate, { model = GetEntityModel(veh) }, fuel,
        GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh), garageId)
    DeleteVehicle(veh)
    notify('Vehicle stored', 'success')
end)

