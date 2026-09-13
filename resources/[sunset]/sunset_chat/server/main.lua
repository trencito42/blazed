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

local BASE_CHAT_CHANNELS = {
    { id = 'all', label = 'LOCAL', placeholder = 'Local message — nearby players hear you' },
    { id = 'ooc', label = 'OOC', placeholder = 'Out of Character — global (( message ))' },
    { id = 'me', label = 'ME', placeholder = 'RP action (/me searches the trunk...)' },
    { id = 'do', label = 'DO', placeholder = 'RP action (/do the trunk opens)' },
}

local function buildChatChannels(source)
    local channels = {}
    for _, row in ipairs(BASE_CHAT_CHANNELS) do
        channels[#channels + 1] = row
    end

    local char = exports.sunset_core:GetCharacter(source)
    local factionId = select(1, Sunset.GetCharacterFaction(char))
    if factionId and Sunset.Factions[factionId] then
        local faction = Sunset.Factions[factionId]
        local label = faction.label or factionId
        if Sunset.IsEmergencyDepartment(factionId) then
            channels[#channels + 1] = {
                id = 'radio',
                label = 'RADIO',
                placeholder = ('%s radio — your department only'):format(label),
            }
            channels[#channels + 1] = {
                id = 'dept',
                label = 'DEPT',
                placeholder = 'Inter-agency radio (LSPD, Sheriff, FIB, EMS, LSFD)',
            }
        else
            channels[#channels + 1] = {
                id = 'faction',
                label = string.upper(label),
                placeholder = ('%s faction chat'):format(label),
            }
        end
    end

    if GetResourceState('sunset_clans') == 'started' then
        local ok, meta = pcall(function()
            return exports.sunset_clans:GetClanChatMeta(source)
        end)
        if ok and type(meta) == 'table' and meta.clanTag and meta.clanTag ~= '' then
            channels[#channels + 1] = {
                id = 'clan',
                label = string.upper(meta.clanTag),
                placeholder = ('%s clan chat'):format(meta.clanTag),
            }
        end
    end

    return channels
end

exports.sunset_core:RegisterCallback('sunset:getChatChannels', function(source)
    return buildChatChannels(source)
end)

-- /cc — staff chat wipe (level 2+). Clears every player's chat window.
RegisterCommand('cc', function(source, args)
    if source ~= 0 then
        local allowed = false
        if GetResourceState('sunset_admin') == 'started' then
            local ok, res = pcall(function() return exports.sunset_admin:IsAdmin(source, 2) end)
            allowed = ok and res == true
        end
        if not allowed then
            exports.sunset_core:CommandDenyAdmin(source, 'cc')
            return
        end
    end
    TriggerClientEvent('sunset:chat:clear', -1)
end, false)
