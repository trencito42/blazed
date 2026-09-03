local function generatePlate()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local idx = math.random(1, #chars)
        plate = plate .. chars:sub(idx, idx)
    end
    return plate
end

local StoreRate = {}

local function normalizePlate(plate)
    return type(plate) == 'string' and plate:gsub('%s+', ''):upper() or ''
end

local function findDrivenVehicle(source, plate)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local playerCoords = GetEntityCoords(ped)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if normalizePlate(GetVehicleNumberPlateText(vehicle)) == plate then
            local coords = GetEntityCoords(vehicle)
            if #(playerCoords - coords) <= 12.0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                return vehicle
            end
        end
    end
    return nil
end

local function hasParkedPosition(veh)
    return veh
        and veh.parked_x ~= nil
        and veh.parked_y ~= nil
        and veh.parked_z ~= nil
        and tonumber(veh.parked_x) ~= nil
        and tonumber(veh.parked_y) ~= nil
        and tonumber(veh.parked_z) ~= nil
end

local function buildSpawnOpts(veh)
    local garage = Sunset.Garages[veh.garage or 'legion'] or Sunset.Garages.legion
    if not garage or not garage.spawn then return nil end

    if hasParkedPosition(veh) then
        return {
            x = tonumber(veh.parked_x),
            y = tonumber(veh.parked_y),
            z = tonumber(veh.parked_z),
            w = tonumber(veh.parked_h) or 0.0,
        }
    end

    local spawn = garage.spawn
    return {
        x = spawn.x,
        y = spawn.y,
        z = spawn.z,
        w = spawn.w or 0.0,
    }
end

exports.sunset_core:RegisterCallback('sunset:getVehicles', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    return MySQL.query.await(
        'SELECT id, plate, model, fuel, engine, body, stored, garage, parked_x, parked_y, parked_z, parked_h FROM vehicles WHERE character_id = ?',
        { char.id }
    ) or {}
end)

local function normalizeStored(val)
    if val == true or val == 1 or val == '1' then return 1 end
    if val == false or val == 0 or val == '0' then return 0 end
    local n = tonumber(val)
    if n == 1 then return 1 end
    if n == 0 then return 0 end
    return 1
end

exports.sunset_core:RegisterCallback('sunset:spawnVehicle', function(source, vehicleId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return nil, 'Invalid vehicle' end

    local veh = MySQL.single.await(
        'SELECT * FROM vehicles WHERE id = ? AND character_id = ?',
        { vehicleId, char.id }
    )
    if not veh then return nil, 'Vehicle not found' end

    local stored = normalizeStored(veh.stored)
    local outPlates = {}

    if stored == 1 then
        outPlates = MySQL.query.await(
            'SELECT plate FROM vehicles WHERE character_id = ? AND stored = 0',
            { char.id }
        ) or {}
        MySQL.update.await('UPDATE vehicles SET stored = 1 WHERE character_id = ? AND stored = 0', { char.id })
        MySQL.update.await('UPDATE vehicles SET stored = 0 WHERE id = ?', { veh.id })
    elseif stored == 0 then
        outPlates = { { plate = veh.plate } }
    else
        return nil, 'Vehicle not available'
    end

    local spawnOpts = buildSpawnOpts(veh)
    if not spawnOpts then
        return nil, 'Garage spawn not configured'
    end

    TriggerClientEvent('sunset:client:cleanupOwnedVehicles', source, outPlates)
    TriggerClientEvent('sunset:client:spawnOwnedVehicle', source, veh, spawnOpts)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:getVehicleById', function(source, vehicleId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil end
    return MySQL.single.await(
        'SELECT id, plate, model, fuel, engine, body, stored, garage, parked_x, parked_y, parked_z, parked_h FROM vehicles WHERE id = ? AND character_id = ?',
        { vehicleId, char.id }
    )
end)

exports.sunset_core:RegisterCallback('sunset:storeVehicle', function(source, garageId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    TriggerClientEvent('sunset:client:storeVehicleRequest', source, garageId or 'legion')
    return true
end)

local function storeOwnedVehicle(source, netId, plate, props, fuelLevel, garageId, parked)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local now = GetGameTimer()
    if now - (StoreRate[source] or 0) < 1500 then return nil, 'Please wait before storing again' end
    StoreRate[source] = now

    plate = normalizePlate(plate)
    if plate == '' or #plate > 8 or type(props) ~= 'table' then return nil, 'Invalid vehicle data' end
    local encodedProps = json.encode(props)
    if #encodedProps > 32768 then return nil, 'Vehicle data is too large' end

    local owned = MySQL.single.await(
        'SELECT id FROM vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND character_id = ?',
        { plate, char.id }
    )
    if not owned then return nil, 'This vehicle is not owned by your character' end

    local vehicle = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle)
        or normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate
        or GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(source) then
        vehicle = findDrivenVehicle(source, plate)
    end
    if not vehicle then return nil, 'You must be driving this owned vehicle' end

    fuelLevel = math.max(0, math.min(100, tonumber(fuelLevel) or 0))
    local engine = math.max(-4000, math.min(1000, GetVehicleEngineHealth(vehicle)))
    local body = math.max(0, math.min(1000, GetVehicleBodyHealth(vehicle)))

    local px, py, pz, ph = nil, nil, nil, nil
    if type(parked) == 'table' then
        px = tonumber(parked.x)
        py = tonumber(parked.y)
        pz = tonumber(parked.z)
        ph = tonumber(parked.h) or tonumber(parked.w)
    end

    local changed = MySQL.update.await([[
        UPDATE vehicles SET stored = 1, garage = ?, props = ?, fuel = ?, engine = ?, body = ?,
            parked_x = ?, parked_y = ?, parked_z = ?, parked_h = ?
        WHERE plate = ? AND character_id = ?
    ]], {
        garageId or 'legion',
        encodedProps,
        fuelLevel,
        engine,
        body,
        px, py, pz, ph,
        plate,
        char.id,
    })
    if not changed or changed < 1 then return nil, 'Vehicle could not be stored' end
    return true
end

exports.sunset_core:RegisterCallback('sunset:storeOwnedVehicle', function(source, netId, plate, props, fuelLevel, garageId, parked)
    return storeOwnedVehicle(source, netId, plate, props, fuelLevel, garageId, parked)
end)

AddEventHandler('playerDropped', function()
    StoreRate[source] = nil
end)

exports.sunset_core:RegisterCallback('sunset:refuelVehiclePartial', function(source, fromFuel, toFuel, plate)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    fromFuel = tonumber(fromFuel) or 0
    toFuel = tonumber(toFuel) or 0
    if toFuel <= fromFuel + 0.05 then return nil, 'Nothing to pay for' end
    if toFuel > 100 then toFuel = 100 end

    local added = toFuel - fromFuel
    local pricePer = Sunset.Config.FuelPricePerPercent or 1.75
    local cost = math.ceil(added * pricePer)
    if cost < 1 then return nil, 'Amount too small' end

    if not exports.sunset_core:RemoveMoney(source, 'cash', cost, 'fuel') then
        if not exports.sunset_core:RemoveMoney(source, 'bank', cost, 'fuel') then
            return nil, ('Not enough money ($%s needed)'):format(cost)
        end
    end

    plate = (plate or ''):gsub('%s+', ''):upper()
    if plate ~= '' then
        pcall(function()
            MySQL.update.await(
                'UPDATE vehicles SET fuel = ? WHERE plate = ? AND character_id = ?',
                { toFuel, plate, char.id }
            )
        end)
    end

    return { newFuel = toFuel, cost = cost, liters = added }
end)

exports.sunset_core:RegisterCallback('sunset:fillGasCan', function(source, targetFuel)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end
    if not exports.sunset_inventory:HasItem(source, 'gas_can', 1) then
        return nil, 'You need a gas can'
    end

    local current = exports.sunset_inventory:GetGasCanFuel(source) or 0
    targetFuel = math.max(current, math.min(100, tonumber(targetFuel) or 100))
    local added = targetFuel - current
    if added <= 0.05 then return nil, 'Gas can is already full' end

    local pricePer = Sunset.Config.FuelPricePerPercent or 1.75
    local cost = math.ceil(added * pricePer)
    if not exports.sunset_core:RemoveMoney(source, 'cash', cost, 'gas_can_fill') then
        if not exports.sunset_core:RemoveMoney(source, 'bank', cost, 'gas_can_fill') then
            return nil, ('Not enough money ($%s needed)'):format(cost)
        end
    end

    if not exports.sunset_inventory:SetItemMetadata(source, 'gas_can', { fuel = targetFuel }) then
        exports.sunset_core:AddMoney(source, 'cash', cost, 'gas_can_refund')
        return nil, 'Could not fill gas can'
    end

    return { fuel = targetFuel, cost = cost, added = added }
end)

exports.sunset_core:RegisterCallback('sunset:useGasCanOnVehicle', function(source, plate, vehFuel)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end
    if not exports.sunset_inventory:HasItem(source, 'gas_can', 1) then
        return nil, 'You need a gas can'
    end

    local canFuel = exports.sunset_inventory:GetGasCanFuel(source) or 0
    if canFuel <= 0 then return nil, 'Gas can is empty — fill it at a pump' end

    vehFuel = tonumber(vehFuel) or 0
    if vehFuel >= 99.5 then return nil, 'Vehicle tank is already full' end

    local transfer = math.min(canFuel, 100.0 - vehFuel)
    if transfer <= 0 then return nil, 'Nothing to transfer' end

    local newVehFuel = vehFuel + transfer
    local newCanFuel = canFuel - transfer

    plate = (plate or ''):gsub('%s+', ''):upper()
    if plate ~= '' then
        pcall(function()
            MySQL.update.await(
                'UPDATE vehicles SET fuel = ? WHERE plate = ? AND character_id = ?',
                { newVehFuel, plate, char.id }
            )
        end)
    end

    if newCanFuel <= 0.5 then
        exports.sunset_inventory:RemoveItem(source, 'gas_can', 1)
    else
        exports.sunset_inventory:SetItemMetadata(source, 'gas_can', { fuel = newCanFuel })
    end

    return { vehicleFuel = newVehFuel, canFuel = newCanFuel, transferred = transfer }
end)

RegisterCommand('givecar', function(source, args)
    if source ~= 0 and not exports.sunset_admin:IsAdmin(source, 3) then return end
    local target = tonumber(args[1])
    local model = args[2] or 'sultan'
    if not target then return end
    local char = exports.sunset_core:GetCharacter(target)
    if not char then return end

    local plate = generatePlate()
    MySQL.insert.await(
        'INSERT INTO vehicles (character_id, plate, model, stored, garage) VALUES (?, ?, ?, 1, ?)',
        { char.id, plate, model, 'legion' }
    )
    TriggerClientEvent('sunset:client:notify', target, 'You received a vehicle: ' .. model, 'success')
end, true)
