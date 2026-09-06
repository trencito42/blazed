local CHAT_COOLDOWN_MS = 1200
local MEGAPHONE_RANGE = 35.0

local function isGovEligible(source, char)
    local factionId = char and select(1, FactionCore.getFactionOf(char))
    if not factionId or not Sunset.IsEmergencyDepartment(factionId) then return false end
    return FactionCore.isOnDuty(source)
end

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
    if msg == '' then
        return FactionCore.notify(source, ('Usage: /%s [message]'):format(channel), 'error')
    end
    if #msg > 256 then
        return FactionCore.notify(source, 'Message too long', 'error')
    end

    local name = exports.sunset_core:GetPlayerBaseName(source)
    local faction = Sunset.Factions[factionId]
    local label = faction and faction.label or factionId
    local _, grade = FactionCore.getFactionOf(char)
    local gradeInfo = Sunset.GetFactionGrade and Sunset.GetFactionGrade(factionId, grade)
    local rank = (gradeInfo and gradeInfo.label) or 'Member'

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = FactionCore.getChar(src)
        if c and filterFn(src, c, factionId) then
            TriggerClientEvent('sunset:chat:message', src, {
                id = source,
                name = name,
                message = msg,
                time = os.date('%H:%M:%S'),
                type = channel,
                factionId = factionId,
                factionLabel = label,
                rank = rank,
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
    sendFactionChat(source, 'r', args, function(_, c, factionId)
        return select(1, FactionCore.getFactionOf(c)) == factionId
    end)
end, false)

local function isEmergencyDepartment(factionId)
    return Sunset.FactionTypeMatches(factionId, 'law_enforcement')
        or Sunset.FactionTypeMatches(factionId, 'ems')
        or Sunset.FactionTypeMatches(factionId, 'fire_rescue')
end

RegisterCommand('d', function(source, args)
    if source == 0 then return end
    local char = FactionCore.getChar(source)
    local factionId = char and select(1, FactionCore.getFactionOf(char))
    if not factionId or not isEmergencyDepartment(factionId) then
        return FactionCore.notify(source, 'Department radio is for LSPD, EMS, and LSFD', 'error')
    end
    sendFactionChat(source, 'd', args, function(_, c)
        local id = select(1, FactionCore.getFactionOf(c))
        return id and isEmergencyDepartment(id)
    end)
end, false)

RegisterCommand('gov', function(source, args)
    if source == 0 then return end
    if not isGovEligible(source, FactionCore.getChar(source)) then
        return FactionCore.notify(source, 'On-duty legal factions only', 'error')
    end
    sendFactionChat(source, 'gov', args, function(_, c)
        return c ~= nil
    end)
end, false)

RegisterCommand('m', function(source, args)
    if source == 0 then return end
    if not FactionCore.hasPerm(source, 'megaphone') then
        return FactionCore.notify(source, 'No megaphone permission', 'error')
    end
    if not FactionCore.checkRateLimit(source, 'megaphone', 2000) then return end

    local msg = table.concat(args, ' ')
    if msg == '' then return FactionCore.notify(source, 'Usage: /m [message]', 'error') end
    if #msg > 256 then return FactionCore.notify(source, 'Megaphone message is too long (maximum 256 characters)', 'error') end

    local name = exports.sunset_core:GetPlayerBaseName(source)
    local pos = FactionCore.playerCoords(source)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local tPos = FactionCore.playerCoords(src)
        if FactionCore.distBetween(pos, tPos) <= MEGAPHONE_RANGE then
            TriggerClientEvent('sunset:chat:message', src, {
                id = source,
                name = name,
                message = msg,
                time = os.date('%H:%M:%S'),
                type = 'megaphone',
            })
        end
    end
end, false)
