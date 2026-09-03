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

exports.sunset_core:RegisterCallback('sunset:spawnVehicle', function(source, vehicleId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local veh = MySQL.single.await(
        'SELECT * FROM vehicles WHERE id = ? AND character_id = ? AND stored = 1',
        { vehicleId, char.id }
    )
    if not veh then return nil, 'Vehicle not available' end

    local garage = Sunset.Garages[veh.garage or 'legion'] or Sunset.Garages.legion
    local spawn = garage.spawn

    MySQL.update.await('UPDATE vehicles SET stored = 0 WHERE id = ?', { veh.id })
    TriggerClientEvent('sunset:client:spawnOwnedVehicle', source, veh, spawn)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:storeVehicle', function(source, garageId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    TriggerClientEvent('sunset:client:storeVehicleRequest', source, garageId or 'legion')
    return true
end)

RegisterNetEvent('sunset:server:vehicleStored', function(plate, props, fuel, engine, body, garageId)
    local source = source
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end

    MySQL.update.await([[
        UPDATE vehicles SET stored = 1, garage = ?, props = ?, fuel = ?, engine = ?, body = ?
        WHERE plate = ? AND character_id = ?
    ]], {
        garageId or 'legion',
        json.encode(props or {}),
        fuel or 100,
        engine or 1000,
        body or 1000,
        plate,
        char.id,
    })
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

RegisterCommand('garage', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end
    local vehicles = MySQL.query.await(
        'SELECT id, plate, model, stored, garage FROM vehicles WHERE character_id = ?',
        { char.id }
    ) or {}
    TriggerClientEvent('sunset:client:garageMenu', source, vehicles)
end, false)
