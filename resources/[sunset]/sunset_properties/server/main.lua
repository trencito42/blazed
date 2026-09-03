exports.sunset_core:RegisterCallback('sunset:getProperties', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    return MySQL.query.await('SELECT id, label, price, owner_character_id, entry FROM properties ORDER BY price') or {}
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

    char.home_property_id = propertyId
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end)
