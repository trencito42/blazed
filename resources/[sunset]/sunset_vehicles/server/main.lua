local function generatePlate()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local idx = math.random(1, #chars)
        plate = plate .. chars:sub(idx, idx)
    end
    return plate
end

exports.sunset_core:RegisterCallback('sunset:getVehicles', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    return MySQL.query.await(
        'SELECT id, plate, model, fuel, engine, body, stored, garage FROM vehicles WHERE character_id = ?',
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

    local garage = Sunset.Garages[veh.garage or 'legion'] or Sunset.Garages.legion
    if not garage or not garage.spawn then
        return nil, 'Garage spawn not configured'
    end

    TriggerClientEvent('sunset:client:cleanupOwnedVehicles', source, outPlates)
    TriggerClientEvent('sunset:client:spawnOwnedVehicle', source, veh, {
        nearPlayer = true,
        fresh = stored == 1,
    })
    return true
end)

exports.sunset_core:RegisterCallback('sunset:getVehicleById', function(source, vehicleId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil end
    return MySQL.single.await(
        'SELECT id, plate, model, fuel, engine, body, stored, garage FROM vehicles WHERE id = ? AND character_id = ?',
        { vehicleId, char.id }
    )
end)

exports.sunset_core:RegisterCallback('sunset:storeVehicle', function(source, garageId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    TriggerClientEvent('sunset:client:storeVehicleRequest', source, garageId or 'legion')
    return true
end)

RegisterNetEvent('sunset:server:vehicleStored', function(plate, props, fuelLevel, engine, body, garageId)
    local source = source
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end

    MySQL.update.await([[
        UPDATE vehicles SET stored = 1, garage = ?, props = ?, fuel = ?, engine = ?, body = ?
        WHERE plate = ? AND character_id = ?
    ]], {
        garageId or 'legion',
        json.encode(props or {}),
        fuelLevel or 100,
        engine or 1000,
        body or 1000,
        plate,
        char.id,
    })
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

local function openGarageMenu(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end
    local vehicles = MySQL.query.await(
        'SELECT id, plate, model, stored, garage FROM vehicles WHERE character_id = ?',
        { char.id }
    ) or {}
    TriggerClientEvent('sunset:client:garageMenu', source, vehicles)
end

RegisterCommand('garage', function(source)
    openGarageMenu(source)
end, false)

RegisterCommand('v', function(source)
    openGarageMenu(source)
end, false)
