local function findSourceByCharacterId(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = exports.sunset_core:GetCharacter(src)
        if c and tonumber(c.id) == characterId then
            return src
        end
    end
    return nil
end

exports.sunset_core:RegisterCallback('sunset:getPhoneData', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character loaded' end

    local myCharId = tonumber(char.id)
    local messages = {}
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT m.id, m.message, m.created_at, m.sender_character_id, m.receiver_character_id,
                   sc.firstname AS sender_name, rc.firstname AS receiver_name
            FROM phone_messages m
            LEFT JOIN characters sc ON sc.id = m.sender_character_id
            LEFT JOIN characters rc ON rc.id = m.receiver_character_id
            WHERE m.sender_character_id = ? OR m.receiver_character_id = ?
            ORDER BY m.id DESC LIMIT 50
        ]], { myCharId, myCharId })
    end)
    if ok and rows then
        messages = rows
    end

    local onlineByChar = {}
    local players = {}
    local seen = {}

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and src ~= source then
            local c = exports.sunset_core:GetCharacter(src)
            local charId = c and tonumber(c.id)
            if charId and charId ~= myCharId and not seen[charId] then
                seen[charId] = true
                onlineByChar[charId] = src
                players[#players + 1] = {
                    serverId = src,
                    characterId = charId,
                    name = exports.sunset_core:GetPlayerDisplayName(src),
                    online = true,
                }
            end
        end
    end

    table.sort(players, function(a, b)
        return (a.name or ''):lower() < (b.name or ''):lower()
    end)

    return {
        myId = source,
        myCharacterId = myCharId,
        myName = exports.sunset_core:GetPlayerDisplayName(source),
        cash = char.cash or 0,
        bank = char.bank or 0,
        messages = messages,
        contacts = players,
        onlineByChar = onlineByChar,
    }
end)

exports.sunset_core:RegisterCallback('sunset:phoneSend', function(source, targetCharacterId, message)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    targetCharacterId = tonumber(targetCharacterId)
    message = tostring(message or ''):sub(1, 256)
    if not targetCharacterId or message == '' then return nil, 'Invalid message' end
    if targetCharacterId == tonumber(char.id) then return nil, 'Invalid recipient' end

    local exists = MySQL.scalar.await('SELECT id FROM characters WHERE id = ?', { targetCharacterId })
    if not exists then return nil, 'Player not found' end

    MySQL.insert.await(
        'INSERT INTO phone_messages (sender_character_id, receiver_character_id, message) VALUES (?, ?, ?)',
        { tonumber(char.id), targetCharacterId, message }
    )

    local targetSource = findSourceByCharacterId(targetCharacterId)
    if targetSource then
        TriggerClientEvent('sunset:client:notify', targetSource,
            'New message from ' .. exports.sunset_core:GetPlayerDisplayName(source), 'info')
        TriggerClientEvent('sunset:client:phoneMessage', targetSource)
    end

    return true
end)
