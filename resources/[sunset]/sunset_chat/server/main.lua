RegisterNetEvent('sunset:chat:send', function(message)
    local src = source
    if not message or #message > 256 then return end

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
    local msg = table.concat(args, ' ')
    if msg == '' then return end
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
    local msg = table.concat(args, ' ')
    if msg == '' then return end
    TriggerClientEvent('sunset:chat:message', -1, {
        id = source,
        name = '**',
        message = msg .. ' (( ' .. GetPlayerName(source) .. ' ))',
        time = os.date('%H:%M'),
        type = 'do',
    })
end, false)
