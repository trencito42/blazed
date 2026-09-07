local CHAT_COOLDOWN_MS = 1200
local MEGAPHONE_RANGE = 35.0

local function attachSpeakerIdentity(payload, source, opts)
    opts = opts or {}
    if opts.setName then
        payload.name = exports.sunset_core:GetPlayerBaseName(source)
    end
    if GetResourceState('sunset_clans') == 'started' then
        local ok, meta = pcall(function()
            return exports.sunset_clans:GetClanChatMeta(source)
        end)
        if ok and type(meta) == 'table' then
            payload.clanTag = meta.clanTag
            payload.clanTagColor = meta.clanTagColor
            payload.clanTagStyle = meta.clanTagStyle
        end
    end
    return payload
end

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
    local rank = FactionLabels.get(factionId, grade)

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = FactionCore.getChar(src)
        if c and filterFn(src, c, factionId) then
            local payload = attachSpeakerIdentity({
                id = source,
                message = msg,
                time = os.date('%H:%M:%S'),
                type = channel,
                factionId = factionId,
                factionLabel = label,
                rank = rank,
            }, source, { setName = true })
            TriggerClientEvent('sunset:chat:message', src, payload)
        end
    end
end

local function isEmergencyDepartment(factionId)
    return Sunset.FactionTypeMatches(factionId, 'law_enforcement')
        or Sunset.FactionTypeMatches(factionId, 'ems')
        or Sunset.FactionTypeMatches(factionId, 'fire_rescue')
end

local function runFactionChat(source, args)
    if source == 0 then return end
    local char = FactionCore.getChar(source)
    local factionId = char and select(1, FactionCore.getFactionOf(char))
    if factionId and isEmergencyDepartment(factionId) then
        return FactionCore.notify(source,
            'Emergency services use /r (faction radio) and /d (department radio), not /f.', 'error')
    end
    sendFactionChat(source, 'f', args, function(_, c, factionId)
        return select(1, FactionCore.getFactionOf(c)) == factionId
    end)
end

local function runRadioChat(source, args)
    if source == 0 then return end
    sendFactionChat(source, 'r', args, function(_, c, factionId)
        return select(1, FactionCore.getFactionOf(c)) == factionId
    end)
end

RegisterCommand('f', runFactionChat, false)
RegisterCommand('r', runRadioChat, false)

local function runDepartmentChat(source, args)
    if source == 0 then return end
    local char = FactionCore.getChar(source)
    local factionId = char and select(1, FactionCore.getFactionOf(char))
    if not factionId or not isEmergencyDepartment(factionId) then
        return FactionCore.notify(source, 'Department radio is for LSPD, Sheriff, FIB, EMS, and LSFD', 'error')
    end
    sendFactionChat(source, 'd', args, function(_, c)
        local id = select(1, FactionCore.getFactionOf(c))
        return id and isEmergencyDepartment(id)
    end)
end

RegisterCommand('d', runDepartmentChat, false)

local function runGovAnnouncement(source, args)
    if source == 0 then return end
    local char = FactionCore.getChar(source)
    if not char then return end
    if not isGovEligible(source, char) then
        return FactionCore.notify(source,
            'Only on-duty LSPD, Sheriff, FIB, EMS, or LSFD can send government announcements.', 'error')
    end
    if not FactionCore.checkRateLimit(source, 'chat_gov', 5000) then
        return FactionCore.notify(source, 'Government announcements are rate limited — wait a few seconds.', 'error')
    end

    local msg = table.concat(args, ' ')
    if msg == '' then
        return FactionCore.notify(source, 'Usage: /gov [announcement]', 'error')
    end
    if #msg > 512 then
        return FactionCore.notify(source, 'Government announcement too long (max 512 characters)', 'error')
    end

    local factionId = select(1, FactionCore.getFactionOf(char))
    local faction = Sunset.Factions[factionId]
    local label = faction and faction.label or factionId or 'Government'
    local _, grade = FactionCore.getFactionOf(char)
    local rank = FactionLabels.get(factionId, grade)
    local issuer = exports.sunset_core:GetPlayerBaseName(source)

    local payload = attachSpeakerIdentity({
        id = source,
        name = label,
        issuerName = issuer,
        issuerRank = rank,
        message = msg,
        time = os.date('%H:%M:%S'),
        type = 'gov',
        factionId = factionId,
        factionLabel = label,
        rank = rank,
    }, source, { setName = false })

    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('sunset:chat:message', tonumber(id), payload)
    end
end

RegisterCommand('gov', runGovAnnouncement, false)

local function runMegaphone(source, args)
    if source == 0 then return end
    if not FactionCore.hasPerm(source, 'megaphone') then
        return FactionCore.notify(source, 'No megaphone permission', 'error')
    end
    if not FactionCore.checkRateLimit(source, 'megaphone', 2000) then return end

    local msg = table.concat(args, ' ')
    if msg == '' then return FactionCore.notify(source, 'Usage: /m [message]', 'error') end
    if #msg > 256 then return FactionCore.notify(source, 'Megaphone message is too long (maximum 256 characters)', 'error') end

    local pos = FactionCore.playerCoords(source)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local tPos = FactionCore.playerCoords(src)
        if FactionCore.distBetween(pos, tPos) <= MEGAPHONE_RANGE then
            local payload = attachSpeakerIdentity({
                id = source,
                message = msg,
                time = os.date('%H:%M:%S'),
                type = 'megaphone',
            }, source, { setName = true })
            TriggerClientEvent('sunset:chat:message', src, payload)
        end
    end
end

RegisterCommand('m', runMegaphone, false)

function RunChatCommand(source, name, args)
    if source == 0 then return false end
    name = string.lower(tostring(name or ''))
    args = args or {}

    if name == 'f' then runFactionChat(source, args) return true end
    if name == 'r' then runRadioChat(source, args) return true end
    if name == 'd' then runDepartmentChat(source, args) return true end
    if name == 'gov' then runGovAnnouncement(source, args) return true end
    if name == 'm' then runMegaphone(source, args) return true end
    if name == 'startradar' or name == 'setradar' or name == 'radar' then
        TriggerClientEvent('sunset:police:tryStartRadar', source, args[1])
        return true
    end
    if name == 'stopradar' then
        TriggerClientEvent('sunset:police:tryStopRadar', source)
        return true
    end
    return false
end
exports('RunChatCommand', RunChatCommand)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if GetResourceState('sunset_chat') == 'started' then
        pcall(function() exports.sunset_chat:RefreshCommandList() end)
    end
end)
