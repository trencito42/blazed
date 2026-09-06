FactionRoster = FactionRoster or {}

local function rosterLeaderPerm(source, perm)
    local char = FactionCore.getChar(source)
    if not char then return nil, 'Your character is not loaded.' end
    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then return nil, 'No faction' end
    if FactionCore.isFactionLeader(char.id, factionId) then return char, factionId end
    if not FactionCore.hasPerm(source, perm) then
        return nil, FactionCore.accessError(source, perm, 'manage faction members')
    end
    return char, factionId
end

local function getMemberRow(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end
    local row = MySQL.single.await(
        'SELECT id, firstname, lastname, metadata FROM characters WHERE id = ? LIMIT 1',
        { characterId }
    )
    if not row then return nil end
    local metadata = row.metadata
    if type(metadata) == 'string' then
        local ok, decoded = pcall(json.decode, metadata)
        metadata = ok and decoded or {}
    end
    metadata = type(metadata) == 'table' and metadata or {}
    return {
        id = tonumber(row.id),
        name = (('%s %s'):format(row.firstname or '', row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        factionId = metadata.faction,
        grade = tonumber(metadata.faction_grade) or 0,
    }
end

local function onlineSourceForCharacter(characterId)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local char = src and FactionCore.getChar(src)
        if char and tonumber(char.id) == tonumber(characterId) then return src end
    end
    return nil
end

local function canManageMember(actorSource, actorChar, factionId, targetGrade, targetCharacterId)
    local isLeader = FactionCore.isFactionLeader(actorChar.id, factionId)
    if isLeader then return true end
    if not FactionCore.hasPerm(actorSource, 'giverank') and not FactionCore.hasPerm(actorSource, 'promote') then
        return false, FactionCore.accessError(actorSource, 'giverank', 'manage faction ranks')
    end
    local _, myGrade = FactionCore.getFactionOf(actorChar)
    if targetGrade >= (myGrade or 0) and tonumber(targetCharacterId) ~= tonumber(actorChar.id) then
        return false, 'You cannot manage members at your rank or higher'
    end
    return true
end

function FactionRoster.adjustGrade(source, characterId, delta)
    local char, factionId = rosterLeaderPerm(source, 'giverank')
    if not char then
        if FactionCore.hasPerm(source, 'promote') then
            char = FactionCore.getChar(source)
            factionId = char and select(1, FactionCore.getFactionOf(char))
        else
            return nil, factionId
        end
    end
    if not char or not factionId then return nil, 'No faction' end

    characterId = tonumber(characterId)
    delta = tonumber(delta) or 0
    if not characterId or delta == 0 then return nil, 'Invalid roster action' end

    local member = getMemberRow(characterId)
    if not member or member.factionId ~= factionId then return nil, 'That member is not in your faction' end
    if FactionCore.isFactionLeader(characterId, factionId) and delta < 0 then
        return nil, 'You cannot demote a faction leader'
    end

    local allowed, err = canManageMember(source, char, factionId, member.grade, characterId)
    if not allowed then return nil, err end

    local faction = Sunset.Factions[factionId]
    local newGrade = member.grade + delta
    if not faction or not faction.grades[newGrade] then
        if delta > 0 then
            return nil, 'Member is already at the highest rank'
        end
        return nil, 'Member is already at the lowest rank'
    end
    if newGrade >= (select(2, FactionCore.getFactionOf(char)) or 0)
        and tonumber(characterId) ~= tonumber(char.id)
        and not FactionCore.isFactionLeader(char.id, factionId) then
        return nil, 'You cannot set rank to your level or higher'
    end

    local targetSource = onlineSourceForCharacter(characterId)
    if targetSource then
        exports.sunset_core:SetFaction(targetSource, factionId, newGrade)
    else
        exports.sunset_core:SetFactionByCharacterId(characterId, factionId, newGrade)
    end

    local label = FactionLabels.get(factionId, newGrade)
    local auditAction = delta > 0 and 'rank_up' or 'rank_down'
    FactionCore.auditLog(factionId, char.id, auditAction, characterId, { grade = newGrade })
    if targetSource then
        FactionCore.notify(targetSource, ('Your rank is now %s'):format(label), 'info')
    end
    return { grade = newGrade, gradeLabel = label }
end

function FactionRoster.kickMember(source, characterId, options)
    options = type(options) == 'table' and options or {}
    local char, factionId = rosterLeaderPerm(source, 'uninvite')
    if not char then return nil, factionId end

    characterId = tonumber(characterId)
    if not characterId then return nil, 'Invalid member' end

    local member = getMemberRow(characterId)
    if not member or member.factionId ~= factionId then return nil, 'That member is not in your faction' end
    if FactionCore.isFactionLeader(characterId, factionId) then return nil, 'You cannot remove a faction leader' end

    local allowed, err = canManageMember(source, char, factionId, member.grade, characterId)
    if not allowed then return nil, err end

    local targetSource = onlineSourceForCharacter(characterId)
    if options.requireOnline == true and not targetSource then
        return nil, 'That player is offline — use kick without FP for offline removal'
    end
    if not targetSource then
        exports.sunset_core:SetFactionByCharacterId(characterId, nil, 0)
        FactionCore.auditLog(factionId, char.id, 'uninvite_offline', characterId, {})
        return { offline = true }
    end

    if options.withFp == true then
        pcall(function()
            MySQL.insert.await(
                'INSERT INTO faction_warnings (faction_id, character_id, issued_by, reason) VALUES (?, ?, ?, ?)',
                { factionId, characterId, char.id, 'Removed from faction (FP)' }
            )
        end)
    end

    exports.sunset_core:SetFaction(targetSource, nil, 0)
    local auditAction = options.withFp and 'uninvite_fp' or 'uninvite'
    FactionCore.auditLog(factionId, char.id, auditAction, characterId, {})
    FactionCore.notify(targetSource, 'You were removed from the faction', 'warning')
    return { offline = false, serverId = targetSource }
end

exports.sunset_core:RegisterCallback('sunset:factionMemberRankDelta', function(source, characterId, delta)
    return FactionRoster.adjustGrade(source, characterId, delta)
end)

exports.sunset_core:RegisterCallback('sunset:factionMemberKick', function(source, characterId, mode)
    mode = string.lower(tostring(mode or 'online'))
    if mode == 'offline' or mode == 'without_fp' then
        return FactionRoster.kickMember(source, characterId, { requireOnline = false, withFp = false })
    end
    if mode == 'with_fp' or mode == 'fp' then
        return FactionRoster.kickMember(source, characterId, { requireOnline = true, withFp = true })
    end
    return FactionRoster.kickMember(source, characterId, { requireOnline = true, withFp = false })
end)

exports.sunset_core:RegisterCallback('sunset:factionSetGradeLabels', function(source, labels)
    local char = FactionCore.getChar(source)
    if not char then return nil, 'Your character is not loaded.' end
    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then return nil, 'No faction' end
    if not FactionCore.isFactionLeader(char.id, factionId) then
        return nil, 'Only the faction leader can rename ranks'
    end
    local ok, err = FactionLabels.save(factionId, labels, char.id)
    if not ok then return nil, err or 'Could not save rank names' end
    FactionCore.auditLog(factionId, char.id, 'grade_labels', nil, {})
    return { grades = FactionLabels.listForFaction(factionId) }
end)
