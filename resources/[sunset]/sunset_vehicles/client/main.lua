local seatbelt = false
local locked = false
local lightMode = 0 -- 0 off, 1 low, 2 high
local currentVeh = 0
local fuel = 100.0
local spawnedOwnedVehicle = nil
local protectedVehicles = {}
local lastBodyHealth = 1000.0
local lastVehSpeed = 0.0
local spawnGraceUntil = 0
local engineEnabled = {}
local lastEjectAt = 0
local odometerKm = 0.0
local odometerPlate = nil
local lastOdoCoords = nil
local vehicleProps = {}
local lastFuelTickAt = nil

-- GTA fuel natives use liters (0..fPetrolTankVolume), not 0–100%. We track percent for HUD/DB.
local function getNativeTankVolume(veh)
    if not veh or veh == 0 then return 60.0 end
    local vol = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume')
    if vol and vol > 0.01 then return vol end
    return Sunset.GetVehicleTankCapacityLiters(GetVehicleClass(veh))
end

local function readFuelPercent(veh)
    if not veh or veh == 0 then return fuel end
    local cap = getNativeTankVolume(veh)
    if cap <= 0 then return 0 end
    return math.max(0, math.min(100, GetVehicleFuelLevel(veh) / cap * 100.0))
end

local function writeFuelPercent(veh, percent)
    if not veh or veh == 0 then return end
    local cap = getNativeTankVolume(veh)
    local liters = math.max(0, math.min(cap, (tonumber(percent) or 0) / 100.0 * cap))
    SetVehicleFuelLevel(veh, liters)
end

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

local function buildStoreProps(veh)
    local props = {}
    for key, value in pairs(vehicleProps or {}) do props[key] = value end
    props.odometer = math.floor(odometerKm * 10) / 10
    if veh and veh ~= 0 then props.model = GetEntityModel(veh) end
    return props
end

local function decodeVehicleProps(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, props = pcall(json.decode, raw)
    if ok and type(props) == 'table' then return props end
    return nil
end

local function notify(msg, type)
    exports.sunset_ui:Notify(msg, type or 'info')
end

local function showVehicleHint(id)
    local engineOn = false
    local veh = getVeh()
    if veh ~= 0 then
        if engineEnabled[veh] ~= nil then
            engineOn = engineEnabled[veh] == true
        else
            engineOn = GetIsVehicleEngineRunning(veh)
        end
    end
    local lights = { 'LIGHTS OFF', 'LIGHTS LOW', 'LIGHTS HIGH' }
    local lightTones = { 'off', 'low', 'high' }
    local mode = lightMode or 0
    local rows = {
        engine = { label = engineOn and 'ENGINE ON' or 'ENGINE OFF', key = '2', ok = engineOn, tone = engineOn and 'on' or 'off' },
        lock = { label = locked and 'LOCKED' or 'UNLOCKED', key = 'N', ok = not locked, tone = locked and 'off' or 'on' },
        seatbelt = { label = seatbelt and 'SEATBELT ON' or 'SEATBELT OFF', key = 'K', ok = seatbelt, tone = seatbelt and 'on' or 'off' },
        lights = { label = lights[mode + 1] or 'LIGHTS OFF', key = 'H', ok = mode > 0, tone = lightTones[mode + 1] or 'off' },
    }
    exports.sunset_ui:Send('vehicleHint', { id = id, rows = rows })
end

local function normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

local function resetOdometerTracking(plate, km, props)
    odometerPlate = plate and normalizePlate(plate) or nil
    odometerKm = math.max(0, tonumber(km) or 0)
    vehicleProps = type(props) == 'table' and props or {}
    lastOdoCoords = nil
end

local function tickOdometer(veh)
    if not veh or veh == 0 then return end
    local coords = GetEntityCoords(veh)
    if lastOdoCoords then
        local delta = #(coords - lastOdoCoords)
        if delta > 0.02 and delta < 120.0 then
            odometerKm = odometerKm + (delta / 1000.0)
        end
    end
    lastOdoCoords = coords
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
local function plateOf(veh)
    return (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', ''):upper()
end

local function hasKeysFor(veh)
    if veh == 0 then return false end
    if spawnedOwnedVehicle == veh then return true end
    local ok = Sunset.AwaitCallback('sunset:hasVehicleKeys', plateOf(veh))
    return ok == true
end

RegisterCommand('sunset_lock', function()
    if blocked() then return end
    local ped = PlayerPedId()
    local veh = getVeh()
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 0)
    end
    if veh == 0 then return notify('No vehicle nearby', 'error') end
    CreateThread(function()
        if not hasKeysFor(veh) then
            return notify('You do not have keys for this vehicle', 'error')
        end
        locked = not locked
        SetVehicleDoorsLocked(veh, locked and 2 or 1)
        SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)
        showVehicleHint('lock')
    end)
end, false)
RegisterKeyMapping('sunset_lock', 'Lock vehicle', 'keyboard', 'N')

-- ═══ SEATBELT (K) ═══
RegisterCommand('sunset_seatbelt', function()
    if blocked() then return end
    if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    seatbelt = not seatbelt
    showVehicleHint('seatbelt')
end, false)
RegisterKeyMapping('sunset_seatbelt', 'Seatbelt', 'keyboard', 'K')

-- ═══ ENGINE (2) ═══
RegisterCommand('sunset_engine', function()
    if blocked() then return end
    if not driverOnly() then return end
    local veh = getVeh()
    if veh == 0 then return end
    local on = engineEnabled[veh] ~= true
    engineEnabled[veh] = on
    SetVehicleEngineOn(veh, on, true, true)
    SetVehicleKeepEngineOnWhenAbandoned(veh, on)
    showVehicleHint('engine')
end, false)
RegisterKeyMapping('sunset_engine', 'Motor on/off', 'keyboard', '2')

AddEventHandler('sunset:vehicles:setEngineState', function(veh, enabled)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    engineEnabled[veh] = enabled == true
    SetVehicleEngineOn(veh, enabled == true, true, true)
    SetVehicleKeepEngineOnWhenAbandoned(veh, enabled == true)
end)

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
    showVehicleHint('lights')
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
    local previousVehicle = 0
    local previousSpeed = 0.0
    local previousBody = 1000.0

    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            local driver = GetPedInVehicleSeat(veh, -1) == ped
            SetPedConfigFlag(ped, 184, true)
            if driver and engineEnabled[veh] == nil then
                engineEnabled[veh] = GetIsVehicleEngineRunning(veh) == true
                SetVehicleKeepEngineOnWhenAbandoned(veh, engineEnabled[veh] == true)
            elseif driver and engineEnabled[veh] == false then
                SetVehicleEngineOn(veh, false, true, true)
                SetVehicleKeepEngineOnWhenAbandoned(veh, false)
            elseif driver and engineEnabled[veh] == true then
                SetVehicleEngineOn(veh, true, true, true)
                SetVehicleKeepEngineOnWhenAbandoned(veh, true)
            end

            syncLockState(veh)
            applySeatbeltPhysics(ped)

            local speed = GetEntitySpeed(veh)
            local body = GetVehicleBodyHealth(veh)
            if previousVehicle == veh and not seatbelt and GetGameTimer() - lastEjectAt > 3000 then
                local class = GetVehicleClass(veh)
                local canEject = class ~= 8 and class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16
                local hardStop = previousSpeed >= 18.0 and (previousSpeed - speed) >= 10.0
                local collisionDamage = previousBody - body >= 8.0
                if canEject and hardStop and collisionDamage then
                    lastEjectAt = GetGameTimer()
                    local forward = GetEntityForwardVector(veh)
                    local pos = GetEntityCoords(ped)
                    SetEntityCoordsNoOffset(ped, pos.x + forward.x * 1.8, pos.y + forward.y * 1.8,
                        pos.z + 0.35, true, true, true)
                    SetEntityVelocity(ped, forward.x * previousSpeed * 0.75,
                        forward.y * previousSpeed * 0.75, 2.5)
                    SetPedToRagdoll(ped, 1500, 3500, 0, true, true, false)
                    notify('You were thrown from the vehicle because you were not wearing a seatbelt', 'error')
                end
            end
            previousVehicle = veh
            previousSpeed = speed
            previousBody = body
            Wait(0)
        else
            seatbelt = false
            lightMode = 0
            lastBodyHealth = 1000.0
            lastVehSpeed = 0.0
            previousVehicle = 0
            previousSpeed = 0.0
            previousBody = 1000.0
            Wait(500)
        end
    end
end)

-- Persist fuel/damage while an owned vehicle is being driven, not only when it
-- is manually stored. This limits rollback after disconnects or crashes.
CreateThread(function()
    while true do
        Wait(30000)
        local veh = getVeh()
        if veh ~= 0 and isDriver() and spawnedOwnedVehicle == veh and DoesEntityExist(veh) then
            local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', ''):upper()
            Sunset.AwaitCallback('sunset:syncOwnedVehicleState', VehToNet(veh),
                plate, fuel, odometerKm)
        end
    end
end)

local function computeFuelDrainPerSecond(veh)
    local profiles = Sunset.VehicleProfiles or {}
    local class = GetVehicleClass(veh)
    local model = GetEntityModel(veh)
    local litersPerHour = Sunset.GetVehicleFuelLitersPerHour(model, class)

    if litersPerHour <= 0 or not GetIsVehicleEngineRunning(veh) then return 0 end

    local tuning = profiles.consumption or {}
    local rpm = math.max(0.0, math.min(1.0, GetVehicleCurrentRpm(veh)))
    local speedKmh = GetEntitySpeed(veh) * 3.6
    local tankLiters = getNativeTankVolume(veh)
    if tankLiters <= 0 then return 0 end

    local load
    if speedKmh <= 1.0 and rpm < 0.30 then
        load = tuning.idleLoad or 0.07
    else
        local speedReference = tuning.speedReferenceKmh or 160.0
        local speedFactor = math.min(speedKmh / speedReference, 1.0)
        local throttle = math.max(0.0, math.min(1.0, GetControlNormal(0, 71)))
        local redlineStart = tuning.redlineStart or 0.72
        local redlineRange = math.max(0.01, 1.0 - redlineStart)
        local redline = math.max(0.0, (rpm - redlineStart) / redlineRange)

        load = (tuning.baseLoad or 0.45)
            + (rpm ^ 1.7) * (tuning.rpmLoad or 0.75)
            + speedFactor * (tuning.speedLoad or 0.25)
            + throttle * (tuning.throttleLoad or 0.35)
            + (redline ^ 2) * (tuning.redlineLoad or 1.25)
    end

    local litersPerSecond = (litersPerHour / 3600.0) * load
    return (litersPerSecond / tankLiters) * 100.0
end

local function applyCollisionDamage(veh)
    if GetGameTimer() < spawnGraceUntil then
        lastBodyHealth = GetVehicleBodyHealth(veh)
        lastVehSpeed = GetEntitySpeed(veh)
        return
    end
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
                lastFuelTickAt = GetGameTimer()
                fuel = readFuelPercent(veh)
                writeFuelPercent(veh, fuel)
                lastBodyHealth = GetVehicleBodyHealth(veh)
                lastVehSpeed = GetEntitySpeed(veh)
                local plate = normalizePlate(GetVehicleNumberPlateText(veh))
                if plate ~= odometerPlate then
                    local ownedState = Sunset.AwaitCallback('sunset:getDrivenOwnedVehicleState', VehToNet(veh), plate)
                    local props = ownedState and decodeVehicleProps(ownedState.props) or nil
                    resetOdometerTracking(plate, props and props.odometer or 0, props)
                    if ownedState then spawnedOwnedVehicle = veh end
                end
                lastOdoCoords = GetEntityCoords(veh)
                local _, lightsOn, highbeams = GetVehicleLightsState(veh)
                if highbeams == 1 then lightMode = 2
                elseif lightsOn == 1 then lightMode = 1
                else lightMode = 0 end
            end

            applyCollisionDamage(veh)
            if spawnedOwnedVehicle == veh then
                tickOdometer(veh)
            end

            local now = GetGameTimer()
            local elapsedSeconds = lastFuelTickAt and math.min(2.0, math.max(0.0, (now - lastFuelTickAt) / 1000.0)) or 0.0
            lastFuelTickAt = now
            local class = GetVehicleClass(veh)
            local fuelExempt = class == 14 or class == 15 or class == 16
            if not fuelExempt then
                local drain = computeFuelDrainPerSecond(veh) * elapsedSeconds
                if drain > 0 then
                    fuel = math.max(0, fuel - drain)
                    writeFuelPercent(veh, fuel)
                end
                if fuel <= 0.05 then SetVehicleEngineOn(veh, false, false, true) end
            end
            Wait(1000)
        else
            currentVeh = 0
            lastFuelTickAt = nil
            lastOdoCoords = nil
            Wait(500)
        end
    end
end)

function GetVehicleState()
    local veh = getVeh()
    if veh == 0 or not isDriver() then return nil end

    local speed = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)
    local gear = GetVehicleCurrentGear(veh)
    local rawRpm = GetVehicleCurrentRpm(veh)
    local rpm = 0.0
    local engineOn = engineEnabled[veh] == true
    local throttle = GetControlNormal(0, 71)
    local brake = GetControlNormal(0, 72)
    if engineOn and not (throttle > 0.4 and brake > 0.4 and speed < 3) then
        rpm = (rawRpm - 0.2) / 0.8
        if rpm < 0.0 then rpm = 0.0 end
        if rpm > 1.0 then rpm = 1.0 end
    end
    local class = GetVehicleClass(veh)
    local fuelExempt = class == 14 or class == 15 or class == 16

    return {
        inVehicle = true,
        speed = speed,
        gear = gear,
        rpm = rpm,
        fuel = fuelExempt and 100 or fuel,
        showFuel = not fuelExempt,
        engine = GetVehicleEngineHealth(veh),
        locked = locked,
        seatbelt = seatbelt,
        lightMode = lightMode,
        engineOn = engineOn,
        odometer = spawnedOwnedVehicle == veh and (math.floor(odometerKm * 10) / 10) or nil,
        showOdometer = spawnedOwnedVehicle == veh,
        vehicleClass = class,
    }
end

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

    -- Missing values only (new purchase). Never heal a stored damaged car.
    if fuel == nil then fuel = 100.0 end
    if engine == nil then engine = 1000.0 end
    if body == nil then body = 1000.0 end
    fuel = math.max(0.0, math.min(100.0, fuel))
    engine = math.max(0.0, math.min(1000.0, engine))
    body = math.max(0.0, math.min(1000.0, body))

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
    writeFuelPercent(vehicle, vehFuel)
    SetVehicleOnGroundProperly(vehicle)
    Wait(150)
    -- Only fully repair brand-new / full-health records. Damaged cars keep saved HP.
    if vehEngine >= 999.0 and vehBody >= 999.0 then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
    end
    SetVehicleEngineHealth(vehicle, vehEngine)
    SetVehicleBodyHealth(vehicle, vehBody)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    writeFuelPercent(vehicle, vehFuel)
    local spawnProps = decodeVehicleProps(vehData.props)
    if spawnProps and (spawnProps.color1 or spawnProps.color2) then
        SetVehicleColours(vehicle, tonumber(spawnProps.color1) or 0, tonumber(spawnProps.color2) or 0)
    end
    Wait(50)
    SetVehicleEngineHealth(vehicle, vehEngine)
    SetVehicleBodyHealth(vehicle, vehBody)
    writeFuelPercent(vehicle, vehFuel)
    spawnGraceUntil = GetGameTimer() + 4000
    lastBodyHealth = vehBody
    lastVehSpeed = 0.0
    engineEnabled[vehicle] = false
    SetVehicleEngineOn(vehicle, false, true, true)
    SetModelAsNoLongerNeeded(model)

    local props = decodeVehicleProps(vehData.props)
    resetOdometerTracking(vehData.plate, props and props.odometer or 0, props)

    spawnedOwnedVehicle = vehicle
    markProtected(vehicle)
    fuel = vehFuel
    currentVeh = 0
    notify(('Vehicle spawned: %s (fuel %d%%)'):format(vehData.plate, math.floor(vehFuel)), 'success')
end)

local function showGaragePanel(_vehicles)
    TriggerEvent('sunset:menu:openVehicle')
end

RegisterNetEvent('sunset:client:garageMenu', function(_vehicles)
    showGaragePanel(_vehicles)
end)

local function openGaragePanel()
    if blocked() then return end
    TriggerEvent('sunset:menu:openVehicle')
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

RegisterCommand('givekeys', function(_, args)
    CreateThread(function()
        local target = tonumber(args[1])
        local veh = getVeh()
        if veh == 0 then
            local coords = GetEntityCoords(PlayerPedId())
            veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 0)
        end
        if not target or veh == 0 then return notify('Usage: /givekeys [id] near your vehicle', 'error') end
        local ok, err = Sunset.AwaitCallback('sunset:giveVehicleKeys', target, plateOf(veh))
        if ok then notify('Keys given', 'success') else notify(err or 'Could not give keys', 'error') end
    end)
end, false)

RegisterCommand('takekeys', function(_, args)
    CreateThread(function()
        local target = tonumber(args[1])
        local veh = getVeh()
        if veh == 0 then
            local coords = GetEntityCoords(PlayerPedId())
            veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 0)
        end
        if not target or veh == 0 then return notify('Usage: /takekeys [id] near your vehicle', 'error') end
        local ok, err = Sunset.AwaitCallback('sunset:takeVehicleKeys', target, plateOf(veh))
        if ok then notify('Keys taken', 'success') else notify(err or 'Could not take keys', 'error') end
    end)
end, false)

RegisterCommand('park', function()
    CreateThread(function()
        local veh = getVeh()
        if veh == 0 or not isDriver() then return notify('Sit in the driver seat of your vehicle to park it', 'error') end
        if spawnedOwnedVehicle ~= veh then return notify('You can only park your personal vehicle', 'error') end
        local ok, err = Sunset.AwaitCallback('sunset:parkOwnedVehicle', plateOf(veh))
        if ok then notify('Vehicle parked here — it will spawn at this spot', 'success')
        else notify(err or 'Could not park', 'error') end
    end)
end, false)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local trying = GetVehiclePedIsTryingToEnter(ped)
        if trying ~= 0 then
            local lockedState = GetVehicleDoorLockStatus(trying)
            local mine = spawnedOwnedVehicle == trying
            if mine then
                SetVehicleDoorsLockedForPlayer(trying, PlayerId(), false)
            elseif lockedState > 1 then
                local keys = Sunset.AwaitCallback('sunset:hasVehicleKeys', plateOf(trying))
                if keys then
                    SetVehicleDoorsLockedForPlayer(trying, PlayerId(), false)
                else
                    ClearPedTasks(ped)
                    notify('This is not your vehicle', 'error')
                end
            elseif spawnedOwnedVehicle ~= trying then
                -- unlocked but not yours: allow enter, just inform once
            end
        end
        Wait(200)
    end
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
        local props = entity and buildStoreProps(entity) or { model = joaat(vehData.model), odometer = math.floor(odometerKm * 10) / 10 }
        local vehFuel = vehData.fuel or 100.0
        local vehEngine = vehData.engine or 1000.0
        local vehBody = vehData.body or 1000.0

        if not entity then
            notify('Vehicle is not currently in the world', 'error')
            return
        end

        local ped = PlayerPedId()
        if GetPedInVehicleSeat(entity, -1) ~= ped then
            notify('You must be driving this vehicle to store it', 'error')
            return
        end

        if entity then
            props = buildStoreProps(entity)
            vehFuel = readFuelPercent(entity)
            vehEngine = GetVehicleEngineHealth(entity)
            vehBody = GetVehicleBodyHealth(entity)
        end

        local plate = normalizePlate(vehData.plate)
        local parked = captureParkedPosition(entity)
        local ok, err = Sunset.AwaitCallback('sunset:storeOwnedVehicle', VehToNet(entity), plate, props,
            vehFuel, vehData.garage or 'legion', parked)
        if not ok then
            notify(err or 'Vehicle could not be stored', 'error')
            return
        end
        deleteVehicleEntity(entity)
        if spawnedOwnedVehicle == entity then spawnedOwnedVehicle = nil end
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
    CreateThread(function()
        local veh = getVeh()
        if veh == 0 or not isDriver() then return notify('You must be driving your vehicle', 'error') end
        local plate = normalizePlate(GetVehicleNumberPlateText(veh))
        local parked = captureParkedPosition(veh)
        local ok, err = Sunset.AwaitCallback('sunset:storeOwnedVehicle', VehToNet(veh), plate,
            buildStoreProps(veh), fuel, garageId, parked)
        if not ok then return notify(err or 'Vehicle could not be stored', 'error') end
        deleteVehicleEntity(veh)
        if spawnedOwnedVehicle == veh then spawnedOwnedVehicle = nil end
        notify('Vehicle stored', 'success')
    end)
end)

AddEventHandler('sunset:world:garageStore', function(garageId)
    CreateThread(function()
        local veh = getVeh()
        if veh == 0 or not isDriver() then
            notify('You must be driving your vehicle to store it', 'error')
            return
        end
        local plate = normalizePlate(GetVehicleNumberPlateText(veh))
        local parked = captureParkedPosition(veh)
        local ok, err = Sunset.AwaitCallback('sunset:storeOwnedVehicle', VehToNet(veh), plate,
            buildStoreProps(veh), fuel, garageId, parked)
        if not ok then return notify(err or 'Vehicle could not be stored', 'error') end
        deleteVehicleEntity(veh)
        if spawnedOwnedVehicle == veh then spawnedOwnedVehicle = nil end
        notify('Vehicle stored', 'success')
    end)
end)

local function setFuelLevel(veh, level)
    level = math.max(0.0, math.min(100.0, tonumber(level) or 0))
    fuel = level
    writeFuelPercent(veh, level)
end

exports('SetFuelLevel', setFuelLevel)

exports('GetFuelLevel', function()
    return fuel
end)

local function getGasCanTargetVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return nil, 'Exit the vehicle and stand beside it before using the gas can'
    end

    local coords = GetEntityCoords(ped)
    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, 4.5, 0, 71)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
    return nil, 'Stand next to your vehicle to use the gas can'
end

RegisterNetEvent('sunset:client:useGasCan', function()
    CreateThread(function()
        pcall(function() exports.sunset_inventory:Close() end)
        Wait(100)

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local insideVehicle = GetVehiclePedIsIn(ped, false)
            local insideFuel = readFuelPercent(insideVehicle)
            if insideFuel >= 99.5 then
                notify('This vehicle already has a full tank (100%). The gas can was not used.', 'info')
            else
                notify(('Exit the vehicle and stand beside it to refuel. Current tank: %d%%.'):format(
                    math.floor(insideFuel + 0.5)), 'warning')
            end
            return
        end

        local veh, err = getGasCanTargetVehicle()
        if not veh then
            notify(err or 'No vehicle nearby', 'error')
            return
        end

        local plate = normalizePlate(GetVehicleNumberPlateText(veh))
        local vehicleClass = GetVehicleClass(veh)
        local tankCapacity = Sunset.GetVehicleTankCapacityLiters(vehicleClass)

        local fuelPct
        fuelPct = readFuelPercent(veh)
        if fuelPct >= 99.5 then
            notify('This vehicle already has a full tank (100%). The gas can was not used.', 'info')
            return
        end
        local tankLiters = Sunset.PercentToTankLiters(fuelPct, vehicleClass)

        local result, useErr = Sunset.AwaitCallback('sunset:useGasCanOnVehicle', plate, tankLiters, vehicleClass)
        if not result then
            notify(useErr or 'Could not use gas can', 'error')
            return
        end

        SetVehiclePetrolTankHealth(veh, 1000.0)
        setFuelLevel(veh, result.vehicleFuel or fuelPct)

        local poured = result.transferredLiters or 0
        local fromL = result.fromTankLiters or tankLiters
        local toL = result.tankLiters or (tankLiters + poured)
        local cap = result.tankCapacity or tankCapacity
        local maxCan = result.maxCanLiters or Sunset.GetGasCanMaxLiters()
        local canLeft = result.canLiters

        if canLeft == nil or canLeft <= 0.1 then
            notify(('Added %.0fL to vehicle (%.0fL → %.0fL / %.0fL)'):format(
                poured, fromL, toL, cap), 'success')
        else
            notify(('Added %.0fL to vehicle (%.0fL → %.0fL / %.0fL) — Gas can: %.0f/%.0f L'):format(
                poured, fromL, toL, cap, canLeft, maxCan), 'success')
        end
    end)
end)
