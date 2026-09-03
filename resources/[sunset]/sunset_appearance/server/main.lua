local function loadCharacterForPlayer(source, playerId, charId)
    local char = MySQL.single.await('SELECT * FROM characters WHERE id = ? AND player_id = ?', { charId, playerId })
    if not char then return nil end
    return Sunset.DecodeCharacter(char)
end

exports.sunset_core:RegisterCallback('sunset:saveAppearance', function(source, appearance, gender, charId)
    local player = exports.sunset_core:GetPlayer(source)
    if not player then return nil, 'Not logged in' end

    local char = exports.sunset_core:GetCharacter(source)
    charId = tonumber(charId) or (char and char.id)
    if not char and charId then
        char = loadCharacterForPlayer(source, player.id, charId)
    end
    if not char then return nil, 'No character loaded' end

    gender = tonumber(gender)
    if gender == 0 or gender == 1 then
        char.gender = gender
    end

    local encoded = json.encode(appearance or {})
    if not encoded then return nil, 'Invalid appearance data' end

    MySQL.update.await('UPDATE characters SET appearance = ?, gender = ? WHERE id = ? AND player_id = ?', {
        encoded, char.gender, char.id, player.id
    })

    char.appearance = appearance
    TriggerEvent('sunset:server:setActiveCharacter', source, char)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end)
