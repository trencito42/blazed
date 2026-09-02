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

local function notify(msg, type)
    exports.sunset_ui:Notify(msg, type or 'info')
end

local function syncLockState(veh)
    if veh == 0 then return end
  local state = GetVehicleDoorLockStatus(veh)
    locked = state == 2 or state == 3 or state == 4
end

-- ═══ LOCK (N) ═══
RegisterCommand('sunset_lock', function()
    local ped = PlayerPedId()
    local veh = getVeh()
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end
    if veh == 0 then return notify('Nicio mașină în apropiere', 'error') end

    locked = not locked
    SetVehicleDoorsLocked(veh, locked and 2 or 1)
    notify(locked and 'Încuiat' or 'Descuiat', locked and 'success' or 'info')
end, false)
RegisterKeyMapping('sunset_lock', 'Încuie mașina', 'keyboard', 'N')

-- ═══ SEATBELT (K) ═══
RegisterCommand('sunset_seatbelt', function()
    if getVeh() == 0 then return end
    seatbelt = not seatbelt
    notify(seatbelt and 'Centură ON' or 'Centură OFF', seatbelt and 'success' or 'warning')
end, false)
RegisterKeyMapping('sunset_seatbelt', 'Centură', 'keyboard', 'K')

-- ═══ ENGINE (2) ═══
RegisterCommand('sunset_engine', function()
    local veh = getVeh()
    if veh == 0 then return end
    local on = not GetIsVehicleEngineRunning(veh)
    SetVehicleEngineOn(veh, on, false, true)
    notify(on and 'Motor pornit' or 'Motor oprit', 'info')
end, false)
RegisterKeyMapping('sunset_engine', 'Motor on/off', 'keyboard', '2')

-- ═══ LIGHTS (H) — off → low → high ═══
RegisterCommand('sunset_lights', function()
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

            SetPedConfigFlag(ped, 32, seatbelt)
            if seatbelt then
                SetFlyThroughWindscreenParams(10000.0, 10000.0, 17.0, 0.0)
            else
                SetFlyThroughWindscreenParams(35.0, 40.0, 17.0, 2000.0)
            end
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
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == PlayerPedId() then
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
    if veh == 0 then return nil end

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
exports('GetVehicleState', GetVehicleState)
