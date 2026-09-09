local CHAT_RANGE = 22.0
local CHAT_COOLDOWN_MS = 350
local ChatRateLimits = {}

local function checkChatRateLimit(source, key, cooldownMs)
    local now = GetGameTimer()
    local bucket = ChatRateLimits[source] or {}
    local last = bucket[key] or 0
    if now - last < (cooldownMs or CHAT_COOLDOWN_MS) then return false end
    bucket[key] = now
    ChatRateLimits[source] = bucket
    return true
end

AddEventHandler('playerDropped', function()
    ChatRateLimits[source] = nil
end)

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

        local okChar, char = pcall(function()
            return exports.sunset_core:GetCharacter(source)
        end)
        if okChar and type(char) == 'table' then
            local md = char.metadata or {}
            local factionId = md.faction
            if not factionId and char.job then
                factionId = char.job
            end
            if factionId and type(factionId) == 'string' and factionId ~= '' and factionId ~= 'unemployed' then
                payload.factionId = factionId
            end
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

local function sendBroadcast(payload, eventName)
    eventName = eventName or 'sunset:chat:message'
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent(eventName, tonumber(id), payload)
    end
end

RegisterNetEvent('sunset:chat:send', function(message, channel)
    local src = source
    channel = tostring(channel or 'all'):lower()
    local isOoc = channel == 'ooc'
    local rateKey = isOoc and 'ooc' or 'say'
    if not checkChatRateLimit(src, rateKey, CHAT_COOLDOWN_MS) then
        TriggerClientEvent('sunset:chat:system', src, 'Slow down — message rate limited.', 'warning')
        return
    end
    message = cleanChatText(message, 256)
    if not message then return end

    local identity = chatIdentity(src)
    local payload = {
        id = src,
        name = identity.name,
        factionId = identity.factionId,
        clanTag = identity.clanTag,
        clanTagColor = identity.clanTagColor,
        clanTagStyle = identity.clanTagStyle,
        message = message,
        time = os.date('%H:%M:%S'),
        type = isOoc and 'ooc' or 'say',
    }
    if isOoc then
        sendBroadcast(payload)
    else
        sendNearby(src, payload)
    end
end)

local function runMeCommand(source, args)
    local msg = cleanChatText(table.concat(args, ' '), 256)
    if not msg then return end
    local identity = chatIdentity(source)
    sendNearby(source, {
        id = source,
        name = identity.name,
        factionId = identity.factionId,
        clanTag = identity.clanTag,
        clanTagColor = identity.clanTagColor,
        clanTagStyle = identity.clanTagStyle,
        message = msg,
        time = os.date('%H:%M:%S'),
        type = 'me',
    })
end

local function runDoCommand(source, args)
    local msg = cleanChatText(table.concat(args, ' '), 256)
    if not msg then return end
    local identity = chatIdentity(source)
    sendNearby(source, {
        id = source,
        name = identity.name,
        factionId = identity.factionId,
        clanTag = identity.clanTag,
        clanTagColor = identity.clanTagColor,
        clanTagStyle = identity.clanTagStyle,
        message = msg,
        time = os.date('%H:%M:%S'),
        type = 'do',
    })
end

RegisterCommand('me', function(source, args)
    runMeCommand(source, args)
end, false)

RegisterCommand('do', function(source, args)
    runDoCommand(source, args)
end, false)

function RunServerCommand(source, name, args)
    if source == 0 then return false end
    name = string.lower(tostring(name or ''))
    args = args or {}
    if name == 'me' then runMeCommand(source, args) return true end
    if name == 'do' then runDoCommand(source, args) return true end
    return false
end
exports('RunServerCommand', RunServerCommand)
