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


local function chatIdentity(source)
    local payload = {}
    if GetResourceState('sunset_core') == 'started' then
        local ok, base = pcall(function()
            return exports.sunset_core:GetPlayerBaseName(source)
        end)
        if ok and type(base) == 'string' and base ~= '' then
            payload.name = base
        end
    end
    if GetResourceState('sunset_clans') == 'started' then
        local okMeta, meta = pcall(function()
            return exports.sunset_clans:GetClanChatMeta(source)
        end)
        if okMeta and type(meta) == 'table' then
            payload.clanTag = meta.clanTag
            payload.clanTagColor = meta.clanTagColor
            payload.clanTagStyle = meta.clanTagStyle
        end
    end
    if not payload.name then
        payload.name = GetPlayerName(source) or 'Player'
    end
    return payload
end

RegisterNetEvent('sunset:chat:send', function(message)
    local src = source
    message = cleanChatText(message, 256)
    if not message then return end

    local identity = chatIdentity(src)
    sendNearby(src, {
        id = src,
        name = identity.name,
        clanTag = identity.clanTag,
        clanTagColor = identity.clanTagColor,
        clanTagStyle = identity.clanTagStyle,
        message = message,
        time = os.date('%H:%M:%S'),
        type = 'say',
    })
end)

-- Comenzi chat utile
RegisterCommand('me', function(source, args)
    local msg = cleanChatText(table.concat(args, ' '), 256)
    if not msg then return end
    local identity = chatIdentity(source)
    sendNearby(source, {
        id = source,
        name = identity.name,
        clanTag = identity.clanTag,
        clanTagColor = identity.clanTagColor,
        clanTagStyle = identity.clanTagStyle,
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
