local CHAT_COOLDOWN_MS = 1200
local MEGAPHONE_RANGE = 35.0

local function sendFactionChat(source, channel, args, filterFn)
    local char = FactionCore.getChar(source)
    if not char then return end
    if not FactionCore.checkRateLimit(source, 'chat_' .. channel, CHAT_COOLDOWN_MS) then
        return FactionCore.notify(source, 'Slow down — message rate limited', 'error')
    end

    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then
        return FactionCore.notify(source, 'You are not in a faction', 'error')
    end

    local msg = table.concat(args, ' ')
    if msg == '' then return end
    if #msg > 256 then
        return FactionCore.notify(source, 'Message too long', 'error')
    end

    local name = exports.sunset_core:GetPlayerDisplayName(source)
    local faction = Sunset.Factions[factionId]
    local label = faction and faction.label or factionId
    local prefix = channel == 'f' and ('[' .. label .. '] ') or ('[' .. string.upper(channel) .. '|' .. label .. '] ')

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = FactionCore.getChar(src)
        if c and filterFn(src, c, factionId) then
            TriggerClientEvent('sunset:chat:message', src, {
                id = source,
                name = prefix .. name,
                message = msg,
                time = os.date('%H:%M'),
                type = channel,
            })
        end
    end
end

RegisterCommand('f', function(source, args)
    if source == 0 then return end
    sendFactionChat(source, 'f', args, function(_, c, factionId)
        return select(1, FactionCore.getFactionOf(c)) == factionId
    end)
end, false)

RegisterCommand('r', function(source, args)
    if source == 0 then return end
    if not FactionCore.isOnDuty(source) then
        return FactionCore.notify(source, 'You must be on duty for radio', 'error')
    end
    local myFaction = select(1, FactionCore.getFactionOf(FactionCore.getChar(source)))
    sendFactionChat(source, 'r', args, function(src, c, factionId)
        return select(1, FactionCore.getFactionOf(c)) == factionId and FactionCore.isOnDuty(src)
    end)
end, false)

RegisterCommand('d', function(source, args)
    if source == 0 then return end
    if not FactionCore.isLawEnforcement(source) then
        return FactionCore.notify(source, 'Law enforcement radio only', 'error')
    end
    sendFactionChat(source, 'd', args, function(src, c)
        return FactionCore.isLawEnforcement(src)
    end)
end, false)

RegisterCommand('gov', function(source, args)
    if source == 0 then return end
    local char = FactionCore.getChar(source)
    local factionId = char and select(1, FactionCore.getFactionOf(char))
    if not factionId or not Sunset.IsLegalFaction(factionId) or not FactionCore.isOnDuty(source) then
        return FactionCore.notify(source, 'On-duty government factions only', 'error')
    end
    sendFactionChat(source, 'gov', args, function(src, c)
        local fId = select(1, FactionCore.getFactionOf(c))
        return fId and Sunset.IsLegalFaction(fId) and FactionCore.isOnDuty(src)
    end)
end, false)

RegisterCommand('m', function(source, args)
    if source == 0 then return end
    if not FactionCore.hasPerm(source, 'megaphone') then
        return FactionCore.notify(source, 'No megaphone permission', 'error')
    end
    if not FactionCore.checkRateLimit(source, 'megaphone', 2000) then return end

    local msg = table.concat(args, ' ')
    if msg == '' then return end

    local name = exports.sunset_core:GetPlayerDisplayName(source)
    local pos = FactionCore.playerCoords(source)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local tPos = FactionCore.playerCoords(src)
        if FactionCore.distBetween(pos, tPos) <= MEGAPHONE_RANGE then
            TriggerClientEvent('sunset:chat:message', src, {
                id = source,
                name = '[MEGAPHONE] ' .. name,
                message = msg,
                time = os.date('%H:%M'),
                type = 'megaphone',
            })
        end
    end
end, false)
