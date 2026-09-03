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

    local players = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = exports.sunset_core:GetCharacter(src)
        if c and c.id ~= char.id then
            players[#players + 1] = {
                serverId = src,
                characterId = c.id,
                name = exports.sunset_core:GetPlayerDisplayName(src),
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
    }
end)

exports.sunset_core:RegisterCallback('sunset:phoneSend', function(source, targetId, message)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end
    targetId = tonumber(targetId)
    message = tostring(message or ''):sub(1, 256)
    if not targetId or message == '' then return nil, 'Invalid message' end

    local targetChar = exports.sunset_core:GetCharacter(targetId)
    if not targetChar then return nil, 'Player not online' end

    MySQL.insert.await(
        'INSERT INTO phone_messages (sender_character_id, receiver_character_id, message) VALUES (?, ?, ?)',
        { char.id, targetChar.id, message }
    )

    TriggerClientEvent('sunset:client:notify', targetId, 'New message from ' .. exports.sunset_core:GetPlayerDisplayName(source), 'info')
    TriggerClientEvent('sunset:client:phoneMessage', targetId)
    return true
end)
