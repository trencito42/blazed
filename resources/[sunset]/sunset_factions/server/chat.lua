local CHAT_COOLDOWN_MS = 1200
local MEGAPHONE_RANGE = 35.0
local SPY_ADMIN_LEVEL = 2
local SpyEnabled = {}

local function canSpyFactionChat(source)
    if source == 0 then return false end
    if GetResourceState('sunset_admin') ~= 'started' then return false end
    if not exports.sunset_admin:IsAdmin(source, SPY_ADMIN_LEVEL) then return false end
    if SpyEnabled[source] == false then return false end
    return true
end

local function spyChannelLabel(channel)
    if channel == 'f' then return 'FACTION' end
    if channel == 'r' then return 'RADIO' end
    if channel == 'd' then return 'DEPT' end
    return string.upper(tostring(channel or 'CHAT'))
end

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

local function resolveFactionMember(source)
    local char = FactionCore.getChar(source)
    if not char then
        FactionCore.notify(source, 'Your character is not loaded. Reconnect and try again.', 'error')
        return nil
    end
    local factionId, grade = FactionCore.ensureFactionMembership(source, char)
    if not factionId then
        FactionCore.notify(source, 'You are not in a faction. Use /factions to browse or ask staff if you should be a member.', 'error')
        return nil
    end
    return char, factionId, grade
end

local function sendFactionChat(source, channel, args, filterFn)
    local char, factionId = resolveFactionMember(source)
    if not char then return end
    if not FactionCore.checkRateLimit(source, 'chat_' .. channel, CHAT_COOLDOWN_MS) then
        return FactionCore.notify(source, 'Slow down — message rate limited', 'error')
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
    local grade = FactionCore.getEffectiveGrade(char, factionId)
    local rank = FactionLabels.get(factionId, grade)

    local recipients = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = FactionCore.getChar(src)
        if c and filterFn(src, c, factionId) then
            recipients[src] = true
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

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src == source or recipients[src] or not canSpyFactionChat(src) then goto continue_spy end
        local spyPayload = attachSpeakerIdentity({
            id = source,
            message = msg,
            time = os.date('%H:%M:%S'),
            type = channel,
            factionId = factionId,
            factionLabel = label,
            rank = rank,
            spy = true,
            spyChannel = spyChannelLabel(channel),
        }, source, { setName = true })
        TriggerClientEvent('sunset:chat:message', src, spyPayload)
        ::continue_spy::
    end
end

local function isEmergencyDepartment(factionId)
    return Sunset.IsEmergencyDepartment(factionId)
end

local function factionChatDeniedMessage(factionId)
    local faction = Sunset.Factions[factionId]
    local label = faction and faction.label or 'your faction'
    if isEmergencyDepartment(factionId) then
        return ('%s uses department radio — /r for your team, /d for all emergency services.'):format(label)
    end
    return 'You are not in a faction. Use /factions to browse or ask staff if you should be a member.'
end

local function memberInFaction(src, c, factionId)
    if not c or not factionId then return false end
    local memberFaction = select(1, FactionCore.getFactionOf(c))
    if memberFaction == factionId then return true end
    return select(1, FactionCore.ensureFactionMembership(src, c)) == factionId
end

local function runFactionChat(source, args)
    if source == 0 then return end
    local char, factionId = resolveFactionMember(source)
    if not char then return end
    if isEmergencyDepartment(factionId) then
        return FactionCore.notify(source, factionChatDeniedMessage(factionId), 'error')
    end
    sendFactionChat(source, 'f', args, function(src, c, senderFactionId)
        return memberInFaction(src, c, senderFactionId)
    end)
end

local function runRadioChat(source, args)
    if source == 0 then return end
    sendFactionChat(source, 'r', args, function(src, c, senderFactionId)
        return memberInFaction(src, c, senderFactionId)
    end)
end

RegisterCommand('f', runFactionChat, false)
RegisterCommand('r', runRadioChat, false)

local function runDepartmentChat(source, args)
    if source == 0 then return end
    local char, factionId = resolveFactionMember(source)
    if not char then return end
    if not isEmergencyDepartment(factionId) then
        return FactionCore.notify(source, 'Department radio is for LSPD, Sheriff, FIB, EMS, and LSFD', 'error')
    end
    sendFactionChat(source, 'd', args, function(src, c)
        local id = select(1, FactionCore.getFactionOf(c))
        if not id then
            id = select(1, FactionCore.ensureFactionMembership(src, c))
        end
        return id and isEmergencyDepartment(id)
    end)
end

RegisterCommand('d', runDepartmentChat, false)

local function runSpyToggle(source)
    if source == 0 then return end
    if GetResourceState('sunset_admin') ~= 'started' or not exports.sunset_admin:IsAdmin(source, SPY_ADMIN_LEVEL) then
        return FactionCore.notify(source, 'No permission', 'error')
    end
    if SpyEnabled[source] == false then
        SpyEnabled[source] = true
        FactionCore.notify(source, 'Faction chat spy ON — you will see /f, /r, and /d traffic.', 'success')
    else
        SpyEnabled[source] = false
        FactionCore.notify(source, 'Faction chat spy OFF.', 'info')
    end
end

RegisterCommand('spy', runSpyToggle, false)

AddEventHandler('playerDropped', function()
    SpyEnabled[source] = nil
end)

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

    if name == 'startradar' or name == 'setradar' or name == 'radar' then
        TriggerClientEvent('sunset:police:tryStartRadar', source, args[1])
        return true
    end
    if name == 'stopradar' then
        TriggerClientEvent('sunset:police:tryStopRadar', source)
        return true
    end

    local handler
    if name == 'f' then handler = runFactionChat
    elseif name == 'r' then handler = runRadioChat
    elseif name == 'd' then handler = runDepartmentChat
    elseif name == 'gov' then handler = runGovAnnouncement
    elseif name == 'm' then handler = runMegaphone
    end
    if not handler then return false end

    local ok, err = pcall(handler, source, args)
    if not ok then
        print(('[sunset_factions] chat command /%s failed for #%s: %s'):format(name, tostring(source), tostring(err)))
        FactionCore.notify(source, ('Faction chat failed: %s'):format(tostring(err)), 'error')
    end
    return true
end
exports('RunChatCommand', RunChatCommand)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if GetResourceState('sunset_chat') == 'started' then
        pcall(function() exports.sunset_chat:RefreshCommandList() end)
    end
end)
