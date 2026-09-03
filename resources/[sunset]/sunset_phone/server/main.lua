local function findSourceByCharacterId(characterId)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = exports.sunset_core:GetCharacter(src)
        if c and c.id == characterId then
            return src
        end
    end
    return nil
end

exports.sunset_core:RegisterCallback('sunset:getPhoneData', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil end

    local messages = MySQL.query.await([[
        SELECT m.id, m.message, m.created_at, m.sender_character_id, m.receiver_character_id,
               sc.firstname AS sender_name, rc.firstname AS receiver_name
        FROM phone_messages m
        LEFT JOIN characters sc ON sc.id = m.sender_character_id
        LEFT JOIN characters rc ON rc.id = m.receiver_character_id
        WHERE m.sender_character_id = ? OR m.receiver_character_id = ?
        ORDER BY m.id DESC LIMIT 50
    ]], { char.id, char.id }) or {}

    local onlineByChar = {}
    local players = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = exports.sunset_core:GetCharacter(src)
        if c and c.id ~= char.id then
            onlineByChar[c.id] = src
            players[#players + 1] = {
                serverId = src,
                characterId = c.id,
                name = exports.sunset_core:GetPlayerDisplayName(src),
                online = true,
            }
        end
    end

    return {
        myId = source,
        myCharacterId = char.id,
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
    if targetCharacterId == char.id then return nil, 'Invalid recipient' end

    local exists = MySQL.scalar.await('SELECT id FROM characters WHERE id = ?', { targetCharacterId })
    if not exists then return nil, 'Player not found' end

    MySQL.insert.await(
        'INSERT INTO phone_messages (sender_character_id, receiver_character_id, message) VALUES (?, ?, ?)',
        { char.id, targetCharacterId, message }
    )

    local targetSource = findSourceByCharacterId(targetCharacterId)
    if targetSource then
        TriggerClientEvent('sunset:client:notify', targetSource,
            'New message from ' .. exports.sunset_core:GetPlayerDisplayName(source), 'info')
        TriggerClientEvent('sunset:client:phoneMessage', targetSource)
    end

    return true
end)
