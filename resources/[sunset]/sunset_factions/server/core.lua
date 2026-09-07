-- Fresh table each resource start so stale globals never miss newly added helpers.
FactionCore = {}

local OnDuty = OnDuty or {}
local RateLimits = {}

function FactionCore.getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

function FactionCore.getFactionOf(char)
    return Sunset.GetCharacterFaction(char)
end

function FactionCore.isOnDuty(source)
    return OnDuty[source] == true
end

function FactionCore.setOnDuty(source, state)
    OnDuty[source] = state and true or false
end

function FactionCore.getOnDutyTable()
    return OnDuty
end

function FactionCore.hasPerm(source, perm)
    local char = FactionCore.getChar(source)
    if not char or not OnDuty[source] then return false end
    local factionId, grade = FactionCore.getFactionOf(char)
    if not factionId then return false end
    if not Sunset.CapabilityAllowedForFaction(factionId, perm) and perm ~= 'invite' and perm ~= 'promote' then
        return false
    end
    return Sunset.HasFactionPerm(factionId, grade, perm)
end

function FactionCore.isFactionLeader(characterId, factionId)
    local row = MySQL.single.await(
        'SELECT id FROM faction_leaders WHERE character_id = ? AND faction_id = ? LIMIT 1',
        { characterId, factionId }
    )
    return row ~= nil
end

function FactionCore.highestFactionGrade(factionId)
    local highest = 0
    for grade in pairs((Sunset.Factions[factionId] and Sunset.Factions[factionId].grades) or {}) do
        if type(grade) == 'number' and grade > highest then highest = grade end
    end
    return highest
end

function FactionCore.getEffectiveGrade(char, factionId)
    local _, grade = FactionCore.getFactionOf(char)
    grade = tonumber(grade) or 0
    if not char or not factionId then return grade end
    if FactionCore.isFactionLeader(char.id, factionId) then
        return math.max(grade, FactionCore.highestFactionGrade(factionId))
    end
    return grade
end

local MANAGEMENT_PERMS = {
    invite = true,
    giverank = true,
    uninvite = true,
    fwarn = true,
    fmotd = true,
    promote = true,
}

function FactionCore.hasManagePerm(source, perm)
    local char = FactionCore.getChar(source)
    if not char then return false end
    local factionId, grade = FactionCore.getFactionOf(char)
    if not factionId then return false end
    if FactionCore.isFactionLeader(char.id, factionId) then return true end
    if not MANAGEMENT_PERMS[perm] then
        return FactionCore.hasPerm(source, perm)
    end
    if not Sunset.CapabilityAllowedForFaction(factionId, perm) and perm ~= 'invite' and perm ~= 'promote' then
        return false
    end
    return Sunset.HasFactionPerm(factionId, grade, perm)
end

function FactionCore.manageAccessError(source, perm, action)
    action = action or 'use this action'
    local char = FactionCore.getChar(source)
    if not char then
        return ('Cannot %s: your character is not loaded. Reconnect and select it again.'):format(action)
    end
    local factionId, grade = FactionCore.getFactionOf(char)
    if not factionId then
        return ('Cannot %s: you are not in a faction.'):format(action)
    end
    if perm and not Sunset.HasFactionPerm(factionId, grade, perm) then
        local faction = Sunset.Factions and Sunset.Factions[factionId]
        local currentGrade = Sunset.GetFactionGrade(factionId, grade)
        local requiredGrade, requiredLabel
        for gradeId, row in pairs((faction and faction.grades) or {}) do
            local numericGrade = tonumber(gradeId)
            if numericGrade and row.perms and row.perms[perm]
                and (not requiredGrade or numericGrade < requiredGrade) then
                requiredGrade = numericGrade
                requiredLabel = row.label
            end
        end
        if requiredGrade then
            return ('Cannot %s: requires %s (rank %d); your rank is %s (rank %d).'):format(
                action, requiredLabel or 'a higher rank', requiredGrade,
                currentGrade and currentGrade.label or 'Unknown', tonumber(grade) or 0)
        end
    end
    return ('Cannot %s: your rank does not allow this.'):format(action)
end

function FactionCore.accessError(source, perm, action, requiredType)
    action = action or 'use this action'
    local char = FactionCore.getChar(source)
    if not char then
        return ('Cannot %s: your character is not loaded. Reconnect and select it again.'):format(action)
    end

    local factionId, grade = FactionCore.getFactionOf(char)
    if not factionId then
        return ('Cannot %s: you are not a member of a faction that provides this ability.'):format(action)
    end

    local faction = Sunset.Factions and Sunset.Factions[factionId]
    local factionLabel = faction and faction.label or factionId
    if not FactionCore.isOnDuty(source) then
        return ('Cannot %s: you are off duty. Go to %s HQ and press E or use /duty.'):format(
            action, factionLabel)
    end

    local factionType = Sunset.GetFactionType(factionId)
    if requiredType and factionType ~= requiredType then
        return ('Cannot %s: %s is not the required department for this action.'):format(action, factionLabel)
    end
    if perm and perm ~= 'invite' and perm ~= 'promote'
        and not Sunset.CapabilityAllowedForFaction(factionId, perm) then
        return ('Cannot %s: %s does not have this department capability.'):format(action, factionLabel)
    end
    if perm and not Sunset.HasFactionPerm(factionId, grade, perm) then
        local currentGrade = Sunset.GetFactionGrade(factionId, grade)
        local requiredGrade, requiredLabel
        for gradeId, row in pairs((faction and faction.grades) or {}) do
            local numericGrade = tonumber(gradeId)
            if numericGrade and row.perms and row.perms[perm]
                and (not requiredGrade or numericGrade < requiredGrade) then
                requiredGrade = numericGrade
                requiredLabel = row.label
            end
        end
        if requiredGrade then
            return ('Cannot %s: requires %s (rank %d); your rank is %s (rank %d).'):format(
                action, requiredLabel or 'a higher rank', requiredGrade,
                currentGrade and currentGrade.label or 'Unknown', tonumber(grade) or 0)
        end
    end
    return ('Cannot %s: the current faction state does not allow it. Toggle duty and try again.'):format(action)
end

function FactionCore.hasCapability(source, capability)
    local char = FactionCore.getChar(source)
    if not char or not OnDuty[source] then return false end
    local factionId, grade = FactionCore.getFactionOf(char)
    if not factionId then return false end
    return Sunset.HasFactionCapability(factionId, grade, capability)
end

function FactionCore.isLawEnforcementMember(source)
    local char = FactionCore.getChar(source)
    if not char then return false end
    local factionId = FactionCore.getFactionOf(char)
    return factionId and Sunset.FactionTypeMatches(factionId, 'law_enforcement')
end

function FactionCore.isLawEnforcement(source)
    return FactionCore.isOnDuty(source) and FactionCore.isLawEnforcementMember(source)
end

function FactionCore.playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function FactionCore.distBetween(a, b)
    if not a or not b then return 9999.0 end
    return #(a - b)
end

function FactionCore.isOnline(target)
    target = tonumber(target)
    if not target then return false end
    for _, id in ipairs(GetPlayers()) do
        if tonumber(id) == target then return true end
    end
    return false
end

function FactionCore.notify(source, msg, typ, duration)
    typ = typ or 'info'
    if typ == 'error' or typ == 'warning' or typ == 'success' then
        exports.sunset_core:CommandReply(source, msg, typ)
        return
    end
    TriggerClientEvent('sunset:client:notify', source, msg, typ, duration)
end

function FactionCore.checkRateLimit(source, key, cooldownMs)
    cooldownMs = cooldownMs or 1500
    local now = os.time() * 1000
    RateLimits[source] = RateLimits[source] or {}
    local last = RateLimits[source][key] or 0
    if now - last < cooldownMs then return false end
    RateLimits[source][key] = now
    return true
end

function FactionCore.memberDisplayName(characterId)
    characterId = tonumber(characterId)
    if not characterId then return 'Unknown' end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local char = src and FactionCore.getChar(src)
        if char and tonumber(char.id) == characterId then
            return exports.sunset_core:GetPlayerDisplayName(src)
        end
    end
    local row = MySQL.single.await(
        'SELECT firstname, lastname FROM characters WHERE id = ? LIMIT 1',
        { characterId }
    )
    if not row then return ('CID %d'):format(characterId) end
    local full = ((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return full ~= '' and full or ('CID %d'):format(characterId)
end

function FactionCore.broadcastManagement(factionId, actorSource, message, opts)
    opts = opts or {}
    factionId = tostring(factionId or '')
    message = tostring(message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if factionId == '' or message == '' then return end

    local faction = Sunset.Factions[factionId]
    local label = faction and faction.label or factionId
    local actorName = opts.actorName
    local actorId = tonumber(opts.actorId) or tonumber(actorSource) or 0
    if not actorName then
        if actorSource then
            actorName = exports.sunset_core:GetPlayerBaseName(actorSource) or 'Unknown'
        else
            actorName = 'System'
        end
    end

    local rank = nil
    if not opts.omitRank then
        rank = opts.rank
        if not rank and actorSource then
            local char = FactionCore.getChar(actorSource)
            if char then
                local _, grade = FactionCore.getFactionOf(char)
                if FactionLabels and FactionLabels.get then
                    rank = FactionLabels.get(factionId, grade)
                else
                    local gradeInfo = Sunset.GetFactionGrade(factionId, grade)
                    rank = gradeInfo and gradeInfo.label or 'Member'
                end
            end
        end
    end

    local payload = {
        id = actorId,
        name = actorName,
        message = message,
        time = os.date('%H:%M:%S'),
        type = 'faction_action',
        factionId = factionId,
        factionLabel = label,
        rank = rank,
    }

    if actorSource and GetResourceState('sunset_clans') == 'started' then
        local ok, meta = pcall(function()
            return exports.sunset_clans:GetClanChatMeta(actorSource)
        end)
        if ok and type(meta) == 'table' then
            payload.clanTag = meta.clanTag
            payload.clanTagColor = meta.clanTagColor
            payload.clanTagStyle = meta.clanTagStyle
        end
    end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local char = src and FactionCore.getChar(src)
        if char and select(1, FactionCore.getFactionOf(char)) == factionId then
            TriggerClientEvent('sunset:chat:message', src, payload)
        end
    end
end

function FactionCore.auditLog(factionId, actorCharId, action, targetCharId, details)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO faction_audit_log (faction_id, actor_character_id, action, target_character_id, details)
            VALUES (?, ?, ?, ?, ?)
        ]], {
            factionId,
            actorCharId,
            action,
            targetCharId,
            details and json.encode(details) or nil,
        })
    end)
end

function FactionCore.canManageMembers(source)
    local char = FactionCore.getChar(source)
    if not char then return false end
    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then return false end
    if FactionCore.isFactionLeader(char.id, factionId) then return true end
    return FactionCore.hasManagePerm(source, 'invite')
        or FactionCore.hasManagePerm(source, 'promote')
        or FactionCore.hasManagePerm(source, 'giverank')
        or FactionCore.hasManagePerm(source, 'uninvite')
        or FactionCore.hasManagePerm(source, 'fwarn')
        or FactionCore.hasManagePerm(source, 'fmotd')
end

AddEventHandler('playerDropped', function()
    RateLimits[source] = nil
end)
