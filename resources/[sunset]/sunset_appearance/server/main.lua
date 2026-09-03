exports.sunset_core:RegisterCallback('sunset:saveAppearance', function(source, appearance, gender)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    gender = tonumber(gender)
    if gender == 0 or gender == 1 then
        char.gender = gender
    end

    MySQL.update.await('UPDATE characters SET appearance = ?, gender = ? WHERE id = ?', {
        json.encode(appearance or {}), char.gender, char.id
    })
    char.appearance = appearance
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end)
