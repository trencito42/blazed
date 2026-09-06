local CHAT_RANGE = 22.0

local function cleanChatText(value, maxLength)
    if type(value) ~= 'string' then return nil end
    local text = value:gsub('[%z\1-\8\11\12\14-\31\127]', '')
    text = text:match('^%s*(.-)%s*$') or ''
    if text == '' then return nil end
    return text:sub(1, maxLength or 256)
end

local function playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function sendNearby(source, payload, range, eventName)
    local origin = playerCoords(source)
    if not origin then return end
    range = range or CHAT_RANGE
    eventName = eventName or 'sunset:chat:message'
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local dest = playerCoords(src)
        if dest and #(origin - dest) <= range then
            TriggerClientEvent(eventName, src, payload)
        end
    end
end

RegisterNetEvent('sunset:chat:typing', function(message)
    local src = source
    local text = cleanChatText(message, 80) or ''
    if text:sub(1, 1) == '/' then text = '' end
    sendNearby(src, {
        id = src,
        message = text,
    }, CHAT_RANGE, 'sunset:chat:typing')
end)

RegisterNetEvent('sunset:chat:send', function(message)
    local src = source
    message = cleanChatText(message, 256)
    if not message then return end

    local name = exports.sunset_core:GetPlayerDisplayName(src)
    sendNearby(src, {
        id = src,
        name = name,
        message = message,
        time = os.date('%H:%M:%S'),
        type = 'say',
    })
end)

-- Comenzi chat utile
RegisterCommand('me', function(source, args)
    local msg = cleanChatText(table.concat(args, ' '), 256)
    if not msg then return end
    local name = exports.sunset_core:GetPlayerDisplayName(source)
    sendNearby(source, {
        id = source,
        name = name,
        message = msg,
        time = os.date('%H:%M:%S'),
        type = 'me',
    })
end, false)

RegisterCommand('do', function(source, args)
    local msg = cleanChatText(table.concat(args, ' '), 256)
    if not msg then return end
    sendNearby(source, {
        id = source,
        name = GetPlayerName(source),
        message = msg,
        time = os.date('%H:%M:%S'),
        type = 'do',
    })
end, false)
