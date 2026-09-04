local function resolvePlayer(source, arg)
    local target = tonumber(arg)
    if target and GetPlayerName(target) then return target end
    local account = MySQL.single.await('SELECT id, username FROM accounts WHERE LOWER(username) = LOWER(?)', { arg })
    if not account then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local player = exports.sunset_core:GetPlayer(src)
        if player and player.account_id == account.id then return src end
    end
    return nil
end

local function requireLeaderPerm(source, perm)
    local char = FactionCore.getChar(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and select it again.' end
    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then return nil, 'No faction' end
    if FactionCore.isFactionLeader(char.id, factionId) then return char, factionId end
    if not FactionCore.hasPerm(source, perm) then
        return nil, FactionCore.accessError(source, perm, 'manage faction members')
    end
    return char, factionId
end

local function highestFactionGrade(factionId)
    local highest = 0
    for grade in pairs((Sunset.Factions[factionId] and Sunset.Factions[factionId].grades) or {}) do
        if type(grade) == 'number' and grade > highest then highest = grade end
    end
    return highest
end

RegisterCommand('setleader', function(source, args)
    if source ~= 0 and not exports.sunset_admin:IsAdmin(source, 3) then
        return FactionCore.notify(source, 'No permission', 'error')
    end
    local target = resolvePlayer(source, args[1])
    local factionId = args[2]
    if not target or not factionId or not Sunset.Factions[factionId] then
        local msg = 'Usage: /setleader [id|username] [faction]'
        if source == 0 then print(msg) else FactionCore.notify(source, msg, 'error') end
        return
    end
    local char = FactionCore.getChar(target)
    if not char then return end
    local current = select(1, FactionCore.getFactionOf(char))
    if current ~= factionId then
        if not exports.sunset_core:SetFaction(target, factionId, highestFactionGrade(factionId)) then
            return FactionCore.notify(source, 'Could not assign faction rank', 'error')
        end
    end
    MySQL.insert.await(
        'INSERT INTO faction_leaders (character_id, faction_id, assigned_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE assigned_by = VALUES(assigned_by)',
        { char.id, factionId, source == 0 and 'console' or GetPlayerName(source) }
    )
    FactionCore.auditLog(factionId, char.id, 'setleader', char.id, { by = source })
    FactionCore.notify(target, 'You are now a faction leader', 'success')
    if source ~= 0 then FactionCore.notify(source, 'Leader assigned', 'success') end
end, false)

RegisterCommand('removeleader', function(source, args)
    if source ~= 0 and not exports.sunset_admin:IsAdmin(source, 3) then
        return FactionCore.notify(source, 'No permission', 'error')
    end
    local target = resolvePlayer(source, args[1])
    local factionId = args[2]
    if not target or not factionId then
        local msg = 'Usage: /removeleader [id|username] [faction]'
        if source == 0 then print(msg) else FactionCore.notify(source, msg, 'error') end
        return
    end
    local char = FactionCore.getChar(target)
    if not char then return end
    MySQL.update.await('DELETE FROM faction_leaders WHERE character_id = ? AND faction_id = ?', { char.id, factionId })
    FactionCore.auditLog(factionId, char.id, 'removeleader', char.id, { by = source })
    FactionCore.notify(target, 'Faction leader role removed', 'info')
    if source ~= 0 then FactionCore.notify(source, 'Leader removed', 'success') end
end, false)

exports.sunset_core:RegisterCallback('sunset:factionUninvite', function(source, targetId)
    local char, factionId = requireLeaderPerm(source, 'uninvite')
    if not char then return nil, factionId end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    local target = FactionCore.getChar(targetId)
    if not target or select(1, FactionCore.getFactionOf(target)) ~= factionId then
        return nil, 'Target is not in your faction'
    end

    exports.sunset_core:SetFaction(targetId, nil, 0)
    FactionCore.auditLog(factionId, char.id, 'uninvite', target.id, {})
    FactionCore.notify(targetId, 'You were removed from the faction', 'warning')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionGiveRank', function(source, targetId, newGrade)
    local char, factionId = requireLeaderPerm(source, 'giverank')
    if not char then return nil, factionId end
    local _, myGrade = FactionCore.getFactionOf(char)

    targetId = tonumber(targetId)
    newGrade = tonumber(newGrade)
    if not targetId or newGrade == nil then return nil, 'Usage: /fgiverank [id] [grade]' end
    if not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end

    local target = FactionCore.getChar(targetId)
    if not target or select(1, FactionCore.getFactionOf(target)) ~= factionId then
        return nil, 'Target is not in your faction'
    end

    local faction = Sunset.Factions[factionId]
    if not faction or not faction.grades[newGrade] then return nil, 'Invalid grade' end
    if newGrade >= (myGrade or 0) and source ~= targetId and not FactionCore.isFactionLeader(char.id, factionId) then
        return nil, 'You cannot set rank to your level or higher'
    end

    exports.sunset_core:SetFaction(targetId, factionId, newGrade)
    local gradeLabel = faction.grades[newGrade].label
    FactionCore.auditLog(factionId, char.id, 'giverank', target.id, { grade = newGrade })
    FactionCore.notify(targetId, ('Rank set to %s'):format(gradeLabel), 'success')
    FactionCore.notify(source, ('Set rank to %s'):format(gradeLabel), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionWarn', function(source, targetId, reason)
    local char, factionId = requireLeaderPerm(source, 'fwarn')
    if not char then return nil, factionId end

    targetId = tonumber(targetId)
    reason = reason or 'No reason given'
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    local target = FactionCore.getChar(targetId)
    if not target or select(1, FactionCore.getFactionOf(target)) ~= factionId then
        return nil, 'Target is not in your faction'
    end

    pcall(function()
        MySQL.insert.await(
            'INSERT INTO faction_warnings (faction_id, character_id, issued_by, reason) VALUES (?, ?, ?, ?)',
            { factionId, target.id, char.id, reason }
        )
    end)
    FactionCore.auditLog(factionId, char.id, 'fwarn', target.id, { reason = reason })
    FactionCore.notify(targetId, ('Faction warning: %s'):format(reason), 'warning', 8000)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionSetMotd', function(source, message)
    local char, factionId = requireLeaderPerm(source, 'fmotd')
    if not char then return nil, factionId end
    message = tostring(message or ''):sub(1, 512)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO faction_motd (faction_id, message, updated_by) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE message = VALUES(message), updated_by = VALUES(updated_by)
        ]], { factionId, message, char.id })
    end)
    FactionCore.auditLog(factionId, char.id, 'fmotd', nil, { message = message })
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionMembers', function(source)
    local char = FactionCore.getChar(source)
    if not char then return nil end
    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then return nil, 'No faction' end

    local motd = ''
    pcall(function()
        local row = MySQL.single.await('SELECT message FROM faction_motd WHERE faction_id = ?', { factionId })
        motd = row and row.message or ''
    end)

    local members = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = FactionCore.getChar(src)
        if c and select(1, FactionCore.getFactionOf(c)) == factionId then
            local _, grade = FactionCore.getFactionOf(c)
            local gradeRow = Sunset.GetFactionGrade(factionId, grade)
            members[#members + 1] = {
                id = src,
                name = exports.sunset_core:GetPlayerDisplayName(src),
                grade = grade,
                gradeLabel = gradeRow and gradeRow.label or '—',
                onDuty = FactionCore.isOnDuty(src),
                leader = FactionCore.isFactionLeader(c.id, factionId),
            }
        end
    end
    table.sort(members, function(a, b) return (a.grade or 0) > (b.grade or 0) end)
    return { motd = motd, members = members }
end)
