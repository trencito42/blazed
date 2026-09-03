exports.sunset_core:RegisterCallback('sunset:getProperties', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    return MySQL.query.await(
        'SELECT id, label, price, owner_character_id, entry, interior_pos, exit_pos FROM properties ORDER BY price'
    ) or {}
end)

exports.sunset_core:RegisterCallback('sunset:buyProperty', function(source, propertyId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local prop = MySQL.single.await('SELECT * FROM properties WHERE id = ?', { propertyId })
    if not prop then return nil, 'Property not found' end
    if prop.owner_character_id then return nil, 'Already owned' end

    if not exports.sunset_core:RemoveMoney(source, 'bank', prop.price, 'property') then
        if not exports.sunset_core:RemoveMoney(source, 'cash', prop.price, 'property') then
            return nil, 'Not enough money'
        end
    end

    MySQL.update.await('UPDATE properties SET owner_character_id = ? WHERE id = ?', { char.id, propertyId })
    char.home_property_id = propertyId
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:setHome', function(source, propertyId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local prop = MySQL.single.await(
        'SELECT id FROM properties WHERE id = ? AND owner_character_id = ?',
        { propertyId, char.id }
    )
    if not prop then return nil, 'You do not own this property' end

    MySQL.update.await('UPDATE characters SET home_property_id = ? WHERE id = ?', { propertyId, char.id })
    char.home_property_id = propertyId
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end)

local function decodePos(raw)
    if not raw then return nil end
    if type(raw) == 'table' then return raw end
    local ok, data = pcall(json.decode, raw)
    if ok then return data end
    return nil
end

exports.sunset_core:RegisterCallback('sunset:enterProperty', function(source, propertyId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local prop = MySQL.single.await('SELECT * FROM properties WHERE id = ? AND owner_character_id = ?', {
        propertyId, char.id
    })
    if not prop then return nil, 'You do not own this property' end

    local interior = decodePos(prop.interior_pos)
    local entry = decodePos(prop.entry)
    if not interior then return nil, 'No interior configured' end

    TriggerClientEvent('sunset:client:propertyInterior', source, {
        id = prop.id,
        label = prop.label,
        interior = interior,
        entry = entry,
    })
    return true
end)

RegisterNetEvent('sunset:server:exitProperty', function(propertyId)
    local source = source
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end

    local prop = MySQL.single.await('SELECT * FROM properties WHERE id = ? AND owner_character_id = ?', {
        propertyId, char.id
    })
    if not prop then return end

    local entry = decodePos(prop.exit_pos) or decodePos(prop.entry)
    TriggerClientEvent('sunset:client:propertyExited', source, {
        id = prop.id,
        entry = entry,
    })
end)
