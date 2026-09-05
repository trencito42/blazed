local function cleanChatText(value, maxLength)
    if type(value) ~= 'string' then return nil end
    local text = value:gsub('[%z\1-\8\11\12\14-\31\127]', '')
    text = text:match('^%s*(.-)%s*$') or ''
    if text == '' then return nil end
    return text:sub(1, maxLength or 256)
end

RegisterNetEvent('sunset:chat:send', function(message)
    local src = source
    message = cleanChatText(message, 256)
    if not message then return end

    local char = exports.sunset_core:GetCharacter(src)
    local name = exports.sunset_core:GetPlayerDisplayName(src)
    local id = src

    TriggerClientEvent('sunset:chat:message', -1, {
        id = id,
        name = name,
        message = message,
        time = os.date('%H:%M'),
    })
end)

-- Comenzi chat utile
RegisterCommand('me', function(source, args)
    local msg = cleanChatText(table.concat(args, ' '), 256)
    if not msg then return end
    local char = exports.sunset_core:GetCharacter(source)
    local name = exports.sunset_core:GetPlayerDisplayName(source)
    TriggerClientEvent('sunset:chat:message', -1, {
        id = source,
        name = '* ' .. name,
        message = msg,
        time = os.date('%H:%M'),
        type = 'me',
    })
end, false)

RegisterCommand('do', function(source, args)
    local msg = cleanChatText(table.concat(args, ' '), 256)
    if not msg then return end
    TriggerClientEvent('sunset:chat:message', -1, {
        id = source,
        name = '**',
        message = msg .. ' (( ' .. GetPlayerName(source) .. ' ))',
        time = os.date('%H:%M'),
        type = 'do',
    })
end, false)
