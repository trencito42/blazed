local function hasPerm(source, cmd)
    local need = SunsetAdmin.Commands[cmd] or 99
    return IsAdmin(source, need)
end

local function notify(source, msg, type)
    TriggerClientEvent('sunset:client:notify', source, msg, type or 'info')
end

local function onlineIds()
    local ids = {}
    for _, id in ipairs(GetPlayers()) do
        ids[#ids + 1] = tonumber(id)
    end
    table.sort(ids)
    return ids
end

local function isOnline(target)
    target = tonumber(target)
    if not target then return false end
    for _, id in ipairs(GetPlayers()) do
        if tonumber(id) == target then return true end
    end
    return false
end

local function resolvePlayer(source, idArg)
    if not idArg or idArg == '' then
        return nil
    end

    local asNum = tonumber(idArg)
    if asNum and isOnline(asNum) then
        return asNum
    end

    local account = MySQL.single.await('SELECT id, username FROM accounts WHERE LOWER(username) = LOWER(?)', { idArg })
    if account then
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local player = exports.sunset_core:GetPlayer(src)
            if player and player.account_id == account.id then
                return src
            end
        end
    end

    local needle = string.lower(tostring(idArg))
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local name = string.lower(exports.sunset_core:GetPlayerDisplayName(src) or '')
        if name == needle or name:find(needle, 1, true) then
            return src
        end
    end

    return nil
end

local function getTarget(source, id, usage)
    if not id or id == '' then
        if source ~= 0 then
            notify(source, usage or 'You must specify a player ID.', 'error')
        else
            print('[Sunset] You must specify a player ID')
        end
        return nil
    end

    local target = resolvePlayer(source, id)
    if not target then
        if source ~= 0 then
            local ids = onlineIds()
            local hint = #ids > 0 and (' Online: ' .. table.concat(ids, ', ')) or ' No one online.'
            notify(source, 'Invalid player (ID: ' .. tostring(id) .. ').' .. hint, 'error')
        end
        return nil
    end
    return target
end

local function guardSelfTarget(source, target, idArg, action)
    if source == 0 or not target or target ~= source then return true end
    if idArg == '--self' or string.lower(tostring(idArg)) == 'self' then return true end
    notify(source, ('Cannot %s yourself. Specify another player ID.'):format(action), 'error')
    return false
end

local function resolveTarget(source, idArg)
    if idArg then
        return getTarget(source, idArg)
    end
    if source == 0 then
        print('[Sunset] You must specify a player ID')
        return nil
    end
    return source
end

local function canHeal(source)
    if hasPerm(source, 'heal') then return true end
    local ok, allowed = pcall(function()
        return exports.sunset_factions:HasFactionPerm(source, 'heal')
    end)
    return ok and allowed == true
end

local function canRevive(source)
    if hasPerm(source, 'revive') then return true end
    local ok, allowed = pcall(function()
        return exports.sunset_factions:HasFactionPerm(source, 'revive')
    end)
    return ok and allowed == true
end

local StatDefinitions = {
    cash = { scope = 'character', field = 'cash', min = 0, max = 2000000000, label = 'cash' },
    bank = { scope = 'character', field = 'bank', min = 0, max = 2000000000, label = 'bank balance' },
    level = { scope = 'character', field = 'level', min = 1, max = 1000, label = 'level' },
    rp = { scope = 'character', field = 'respect_points', min = 0, max = 1000000, label = 'Respect Points' },
    respect = { alias = 'rp' },
    paydays = { scope = 'character', field = 'paydays_received', min = 0, max = 1000000, label = 'paydays received' },
    hunger = { scope = 'character', field = 'hunger', min = 0, max = 100, label = 'hunger' },
    thirst = { scope = 'character', field = 'thirst', min = 0, max = 100, label = 'thirst' },
    stress = { scope = 'character', field = 'stress', min = 0, max = 100, label = 'stress' },
    playtime = { scope = 'player', field = 'playtime', min = 0, max = 10000000, label = 'playtime minutes' },
    premium = { scope = 'account', field = 'premium_points', min = 0, max = 2000000000, label = 'Sunset Coins' },
    sunsetcoins = { alias = 'premium' },
}

local function commandOutput(source, message, kind)
    if source == 0 then
        print(('[SunsetAdmin] %s'):format(message))
    else
        notify(source, message, kind)
    end
end

local function auditStatChange(source, targetPlayer, targetChar, stat, oldValue, newValue)
    local admin = source ~= 0 and exports.sunset_core:GetPlayer(source) or nil
    local adminName = source == 0 and 'console' or (exports.sunset_core:GetPlayerDisplayName(source) or GetPlayerName(source) or ('ID ' .. source))
    local targetName = exports.sunset_core:GetPlayerDisplayName(targetPlayer.source) or GetPlayerName(targetPlayer.source) or ('ID ' .. targetPlayer.source)
    MySQL.insert.await([[
        INSERT INTO admin_stat_audit
            (admin_account_id, admin_name, target_character_id, target_name, stat_name, old_value, new_value)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { admin and admin.account_id or nil, adminName, targetChar.id, targetName, stat, oldValue, newValue })
    print(('^3[SunsetAdmin]^7 %s set %s (%d) %s: %s -> %s'):format(
        adminName, targetName, targetPlayer.source, stat, oldValue, newValue))
end

local function setPlayerStat(source, args, forcedStat)
    if source ~= 0 and not hasPerm(source, 'setstat') then
        return commandOutput(source, 'Admin level 3 is required to change player statistics.', 'error')
    end

    local target = getTarget(source, args[1], 'Usage: /setstat [player id] [stat] [value]')
    if not target then return end
    local statArgIndex = forcedStat and nil or 2
    local valueArgIndex = forcedStat and 2 or 3
    local stat = string.lower(tostring(forcedStat or args[statArgIndex] or ''))
    local definition = StatDefinitions[stat]
    if definition and definition.alias then
        stat = definition.alias
        definition = StatDefinitions[stat]
    end
    if not definition then
        return commandOutput(source,
            'Unknown stat. Available: cash, bank, level, rp, paydays, playtime, premium, hunger, thirst, stress.', 'error')
    end

    local rawValue = tonumber(args[valueArgIndex])
    if not rawValue or rawValue ~= math.floor(rawValue) then
        return commandOutput(source, ('%s must be a whole number between %d and %d.'):format(
            definition.label, definition.min, definition.max), 'error')
    end
    local value = math.floor(rawValue)
    if value < definition.min or value > definition.max then
        return commandOutput(source, ('%s must be between %d and %d.'):format(
            definition.label, definition.min, definition.max), 'error')
    end

    local player = exports.sunset_core:GetPlayer(target)
    local char = exports.sunset_core:GetCharacter(target)
    if not player or not char then
        return commandOutput(source, 'That player is online but has not selected a character yet.', 'error')
    end

    local oldValue
    if definition.scope == 'character' then
        oldValue = math.floor(tonumber(char[definition.field]) or 0)
        char[definition.field] = value
        MySQL.update.await(('UPDATE characters SET %s = ? WHERE id = ?'):format(definition.field), { value, char.id })
        TriggerClientEvent('sunset:client:updateCharacter', target, char)
        if stat == 'cash' or stat == 'bank' then
            TriggerClientEvent('sunset:client:updateMoney', target, char.cash or 0, char.bank or 0)
        end
    elseif definition.scope == 'player' then
        oldValue = math.floor(tonumber(player[definition.field]) or 0)
        player[definition.field] = value
        -- Make the value entered by the admin the exact new playtime baseline;
        -- otherwise the unflushed part of the current session is added on top.
        if stat == 'playtime' then player.sessionStart = os.time() end
        MySQL.update.await(('UPDATE players SET %s = ? WHERE id = ?'):format(definition.field), { value, player.id })
    else
        oldValue = math.floor(tonumber(player[definition.field]) or 0)
        player[definition.field] = value
        MySQL.update.await(('UPDATE accounts SET %s = ? WHERE id = ?'):format(definition.field), { value, player.account_id })
    end

    auditStatChange(source, player, char, stat, oldValue, value)
    local targetName = exports.sunset_core:GetPlayerDisplayName(target)
    commandOutput(source, ('Set %s for %s (ID %d): %d -> %d. Saved immediately.'):format(
        definition.label, targetName, target, oldValue, value), 'success')
    if source ~= target then
        notify(target, ('An administrator changed your %s from %d to %d.'):format(definition.label, oldValue, value), 'info')
    end
end

RegisterCommand('setstat', function(source, args) setPlayerStat(source, args) end, false)

local statAliases = {
    setcash = 'cash', setmoney = 'cash', setbank = 'bank', setlevel = 'level',
    setrp = 'rp', setrespect = 'rp', setpaydays = 'paydays', setplaytime = 'playtime',
    setpremium = 'premium', setsunsetcoins = 'premium', sethunger = 'hunger',
    setthirst = 'thirst', setstress = 'stress',
}
for command, stat in pairs(statAliases) do
    RegisterCommand(command, function(source, args) setPlayerStat(source, args, stat) end, false)
end

RegisterCommand('astats', function(source, args)
    if source ~= 0 and not hasPerm(source, 'astats') then
        return commandOutput(source, 'Admin level 2 is required to inspect another player\'s statistics.', 'error')
    end
    local target = getTarget(source, args[1], 'Usage: /astats [player id]')
    if not target then return end
    local player = exports.sunset_core:GetPlayer(target)
    local char = exports.sunset_core:GetCharacter(target)
    if not player or not char then
        return commandOutput(source, 'That player has not selected a character yet.', 'error')
    end
    local name = exports.sunset_core:GetPlayerDisplayName(target)
    local line = ('%s [ID %d/CID %d] | Level %d | RP %d | Paydays %d | Cash $%d | Bank $%d | SC %d | Playtime %dh %dm'):format(
        name, target, char.id, char.level or 1, char.respect_points or 0, char.paydays_received or 0,
        char.cash or 0, char.bank or 0, player.premium_points or 0,
        math.floor((player.playtime or 0) / 60), (player.playtime or 0) % 60)
    commandOutput(source, line, 'info')
end, false)

local JobStatFields = {
    xp = { field = 'xp', min = 0, max = 1000000 },
    level = { field = 'level', min = 1, max = 255 },
    tasks = { field = 'completed_tasks', min = 0, max = 100000000 },
    earned = { field = 'total_earned', min = 0, max = 2000000000 },
}

RegisterCommand('setjobstat', function(source, args)
    if source ~= 0 and not hasPerm(source, 'setjobstat') then
        return commandOutput(source, 'Admin level 3 is required to change job progression.', 'error')
    end
    local target = getTarget(source, args[1], 'Usage: /setjobstat [id] [job] [xp|level|tasks|earned] [value]')
    if not target then return end
    local jobId = string.lower(tostring(args[2] or ''))
    local stat = string.lower(tostring(args[3] or ''))
    local definition = JobStatFields[stat]
    if not Sunset.CivilianJobs or not Sunset.CivilianJobs[jobId] then
        return commandOutput(source, 'Unknown civilian job. Use: trucker, garbage, courier, fisherman or mechanic.', 'error')
    end
    if not definition then
        return commandOutput(source, 'Unknown job stat. Use: xp, level, tasks or earned.', 'error')
    end
    local rawValue = tonumber(args[4])
    if not rawValue or rawValue ~= math.floor(rawValue) or rawValue < definition.min or rawValue > definition.max then
        return commandOutput(source, ('Value must be a whole number between %d and %d.'):format(definition.min, definition.max), 'error')
    end
    local value = math.floor(rawValue)
    local player = exports.sunset_core:GetPlayer(target)
    local char = exports.sunset_core:GetCharacter(target)
    if not player or not char then return commandOutput(source, 'That player has not selected a character yet.', 'error') end

    local row = MySQL.single.await('SELECT xp, level, completed_tasks, total_earned FROM job_progress WHERE character_id = ? AND job_id = ?', { char.id, jobId })
    local oldValue = row and math.floor(tonumber(row[definition.field]) or 0) or (stat == 'level' and 1 or 0)
    local values = {
        xp = row and row.xp or 0,
        level = row and row.level or 1,
        completed_tasks = row and row.completed_tasks or 0,
        total_earned = row and row.total_earned or 0,
    }
    values[definition.field] = value
    MySQL.insert.await([[
        INSERT INTO job_progress (character_id, job_id, xp, level, completed_tasks, total_earned)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE xp = VALUES(xp), level = VALUES(level),
            completed_tasks = VALUES(completed_tasks), total_earned = VALUES(total_earned)
    ]], { char.id, jobId, values.xp, values.level, values.completed_tasks, values.total_earned })
    auditStatChange(source, player, char, ('job:%s:%s'):format(jobId, stat), oldValue, value)
    commandOutput(source, ('Set %s %s for %s (ID %d): %d -> %d.'):format(
        Sunset.CivilianJobs[jobId].label, stat, exports.sunset_core:GetPlayerDisplayName(target), target, oldValue, value), 'success')
    if source ~= target then notify(target, ('An administrator changed your %s %s to %d.'):format(Sunset.CivilianJobs[jobId].label, stat, value), 'info') end
end, false)

-- /kick [id] [motiv]
RegisterCommand('kick', function(source, args)
    if source ~= 0 and not hasPerm(source, 'kick') then return notify(source, 'No permission', 'error') end
    local target = getTarget(source, args[1], 'Usage: /kick [player id] [reason]')
    if not target or not guardSelfTarget(source, target, args[1], 'kick') then return end
    local reason = table.concat(args, ' ', 2)
    if reason == '' then reason = 'No reason given' end
    DropPlayer(target, 'You were kicked: ' .. reason)
    if source ~= 0 then notify(source, 'Player kicked', 'success') end
end, false)

-- /ban [id] [motiv]
RegisterCommand('ban', function(source, args)
    if source ~= 0 and not hasPerm(source, 'ban') then return notify(source, 'No permission', 'error') end
    local target = getTarget(source, args[1], 'Usage: /ban [player id] [reason]')
    if not target or not guardSelfTarget(source, target, args[1], 'ban') then return end
    local reason = table.concat(args, ' ', 2)
    if reason == '' then reason = 'Ban permanent' end

    local license = Sunset.GetIdentifier(target, 'license')
    local bannedBy = source == 0 and 'console' or GetPlayerName(source)

    MySQL.insert.await('INSERT INTO bans (license, reason, banned_by) VALUES (?, ?, ?)', { license, reason, bannedBy })
    DropPlayer(target, 'Banned: ' .. reason)
    if source ~= 0 then notify(source, 'Player banned', 'success') end
end, false)

local function resolveUnbanLicense(source, arg)
    if not arg or arg == '' then
        if source ~= 0 then
            notify(source, 'Usage: /unban [player id or license:xxx]', 'error')
        else
            print('[Sunset] Usage: /unban [player id or license:xxx]')
        end
        return nil
    end

    if string.sub(arg, 1, 8) == 'license:' then
        return arg
    end

    local target = resolvePlayer(source, arg)
    if target then
        return Sunset.GetIdentifier(target, 'license')
    end

    if source ~= 0 then
        local ids = onlineIds()
        local hint = #ids > 0 and (' Online: ' .. table.concat(ids, ', ')) or ' No one online. Use license:xxx for offline players.'
        notify(source, 'Invalid player (ID: ' .. tostring(arg) .. ').' .. hint, 'error')
    else
        print('[Sunset] Invalid player or use license:xxx')
    end
    return nil
end

-- /unban [id|license:xxx]
RegisterCommand('unban', function(source, args)
    if source ~= 0 and not hasPerm(source, 'unban') then return notify(source, 'No permission', 'error') end
    local license = resolveUnbanLicense(source, args[1])
    if not license then return end

    local removed = MySQL.update.await('DELETE FROM bans WHERE license = ?', { license })
    local adminName = source == 0 and 'console' or GetPlayerName(source)

    if removed and removed > 0 then
        print(('^2[SunsetAdmin]^7 %s unbanned %s (%d row(s))'):format(adminName, license, removed))
        if source ~= 0 then notify(source, 'Player unbanned', 'success') end
    else
        if source ~= 0 then
            notify(source, 'No ban found for that license', 'error')
        else
            print('[Sunset] No ban found for ' .. license)
        end
    end
end, false)

-- /tp [id] sau /tp x y z
RegisterCommand('tp', function(source, args)
    if source == 0 then return end
    if not hasPerm(source, 'tp') then return notify(source, 'No permission', 'error') end

    if args[1] and not args[2] then
        local target = getTarget(source, args[1], 'Usage: /tp [player id]')
        if not target then return end
        local ped = GetPlayerPed(target)
        local coords = GetEntityCoords(ped)
        TriggerClientEvent('sunset:admin:teleport', source, coords.x, coords.y, coords.z)
    elseif args[1] and args[2] and args[3] then
        TriggerClientEvent('sunset:admin:teleport', source, tonumber(args[1]), tonumber(args[2]), tonumber(args[3]))
    end
end, false)

-- /bring [id]
RegisterCommand('bring', function(source, args)
    if source == 0 then return end
    if not hasPerm(source, 'bring') then return notify(source, 'No permission', 'error') end
    local target = getTarget(source, args[1], 'Usage: /bring [player id]')
    if not target then return end
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('sunset:admin:teleport', target, coords.x, coords.y, coords.z)
    notify(source, 'Player brought to you', 'success')
end, false)

-- /car [model]
RegisterCommand('car', function(source, args)
    if source == 0 then return end
    if not hasPerm(source, 'car') then return notify(source, 'No permission', 'error') end
    local model = args[1] or 'sultan'
    TriggerClientEvent('sunset:admin:spawnVehicle', source, model)
end, false)

-- /dv
RegisterCommand('dv', function(source)
    if source == 0 then return end
    if not hasPerm(source, 'dv') then return notify(source, 'No permission', 'error') end
    TriggerClientEvent('sunset:admin:deleteVehicle', source)
end, false)

-- /heal [id] — admin sau EMS/fire on duty
RegisterCommand('heal', function(source, args)
    if source == 0 then return end
    if not canHeal(source) then return notify(source, 'No permission (admin or on-duty EMS/LSFD)', 'error') end
    local target = resolveTarget(source, args[1])
    if not target then return end
    TriggerClientEvent('sunset:admin:heal', target)
    notify(source, 'Healed ' .. (GetPlayerName(target) or '?') .. ' (ID ' .. target .. ')', 'success')
    if target ~= source then
        TriggerClientEvent('sunset:client:notify', target, 'You were healed by medical staff.', 'success')
    end
end, false)

-- /revive [id] — admin sau EMS on duty
RegisterCommand('revive', function(source, args)
    if source == 0 then return end
    if not canRevive(source) then return notify(source, 'No permission (admin or on-duty EMS/LSFD)', 'error') end
    local target = resolveTarget(source, args[1])
    if not target then
        notify(source, 'Usage: /revive [player id]', 'error')
        return
    end
    local ok, err = exports.sunset_death:RevivePlayer(target)
    if not ok then
        notify(source, err or 'Revive failed', 'error')
        return
    end
    notify(source, 'Revived ' .. (GetPlayerName(target) or '?') .. ' (ID ' .. target .. ')', 'success')
end, false)

-- /noclip
RegisterCommand('noclip', function(source)
    if source == 0 then return end
    if not hasPerm(source, 'noclip') then return notify(source, 'No permission', 'error') end
    TriggerClientEvent('sunset:admin:toggleNoclip', source)
end, false)

-- /god
RegisterCommand('god', function(source)
    if source == 0 then return end
    if not hasPerm(source, 'god') then return notify(source, 'No permission', 'error') end
    TriggerClientEvent('sunset:admin:toggleGod', source)
end, false)

-- /announce [mesaj]
RegisterCommand('announce', function(source, args)
    if source ~= 0 and not hasPerm(source, 'announce') then return notify(source, 'No permission', 'error') end
    local msg = table.concat(args, ' ')
    if msg == '' then return end
    TriggerClientEvent('sunset:client:notify', -1, msg, 'warning')
end, false)

-- /setadmin [id|username] [level]
RegisterCommand('setadmin', function(source, args)
    if source ~= 0 and not hasPerm(source, 'setadmin') then return notify(source, 'No permission', 'error') end

    local arg1 = args[1]
    local level = tonumber(args[2]) or 1
    if not arg1 then
        notify(source ~= 0 and source or 0, 'Usage: /setadmin [id|username] [level]', 'error')
        return
    end

    local target = tonumber(arg1)
    if target and GetPlayerName(target) then
        local license = Sunset.GetIdentifier(target, 'license')
        SetAdmin(license, level, GetPlayerName(target), source == 0 and 'console' or GetPlayerName(source))
        notify(source ~= 0 and source or target, 'Admin level set to ' .. level, 'success')
        return
    end

    local account = MySQL.single.await('SELECT id, username FROM accounts WHERE LOWER(username) = LOWER(?)', { arg1 })
    if not account then return notify(source ~= 0 and source or 0, 'Account not found', 'error') end

    MySQL.update.await('UPDATE accounts SET admin_level = ? WHERE id = ?', { level, account.id })
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local player = exports.sunset_core:GetPlayer(src)
        if player and player.account_id == account.id then
            player.admin_level = level
            loadAdmin(src)
            notify(src, 'Your admin level is now ' .. level, 'success')
        end
    end
    if source ~= 0 then notify(source, 'Admin set for account ' .. account.username, 'success') end
end, false)

-- /coords [v4] — client also registers /getpos and /pos for NUI chat
RegisterCommand('coords', function(source, args)
    if source == 0 then return end
    if not hasPerm(source, 'coords') then return notify(source, 'No permission', 'error') end
    TriggerClientEvent('sunset:admin:copyCoords', source, args)
end, false)

local function sendPlacedCheckpointList(source)
    local chat = function(line)
        TriggerClientEvent('sunset:chat:message', source, { id = 0, name = 'ADMIN', message = line, time = '' })
    end
    local list = SunsetAdmin.GetCheckpoints()
    chat('=== Placed checkpoints (use /gotocp [name]) ===')
    if #list == 0 then
        chat('No checkpoints saved yet. Stand somewhere and use /setcp [name].')
        return
    end
    for _, cp in ipairs(list) do
        chat(('%s — %s'):format(cp.id, cp.label or cp.id))
    end
end

local function sendLocationList(source)
    local chat = function(line)
        TriggerClientEvent('sunset:chat:message', source, { id = 0, name = 'ADMIN', message = line, time = '' })
    end
    chat('=== World locations (use /gotoloc [id or name]) ===')
    local lastCategory
    for _, loc in ipairs(SunsetAdmin.BuildLocations()) do
        if loc.category ~= lastCategory then
            chat(('— %s —'):format(loc.category))
            lastCategory = loc.category
        end
        chat(('%s — %s'):format(loc.id, loc.label))
    end
end

RegisterNetEvent('sunset:admin:setcp', function(name, x, y, z, heading)
    local source = source
    if source == 0 then return end
    if not hasPerm(source, 'setcp') then return notify(source, 'No permission', 'error') end

    name = name and tostring(name):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if name == '' then
        return notify(source, 'Usage: /setcp [name]', 'error')
    end

    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading)
    if not x or not y or not z then
        return notify(source, 'Could not read your position.', 'error')
    end

    local createdBy = GetPlayerName(source) or ('player_' .. source)
    local ok, result = SunsetAdmin.SaveCheckpoint(name, name, x, y, z, heading, createdBy)
    if not ok then
        return notify(source, result, 'error')
    end

    notify(source, ('Checkpoint saved as "%s". Use /gotocp %s to teleport here.'):format(result, result), 'success')
end)

RegisterNetEvent('sunset:admin:delcp', function(name)
    local source = source
    if source == 0 then return end
    if not hasPerm(source, 'delcp') then return notify(source, 'No permission', 'error') end

    name = name and tostring(name):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if name == '' then
        return notify(source, 'Usage: /delcp [name]', 'error')
    end

    local ok, result = SunsetAdmin.DeleteCheckpoint(name)
    if not ok then
        return notify(source, result, 'error')
    end

    notify(source, ('Deleted checkpoint "%s".'):format(result), 'success')
end)

RegisterNetEvent('sunset:admin:gotocp', function(query)
    local source = source
    if source == 0 then return end
    if not hasPerm(source, 'gotocp') then return notify(source, 'No permission', 'error') end

    query = query and tostring(query):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if query == '' or string.lower(query) == 'list' then
        sendPlacedCheckpointList(source)
        return
    end

    local cp = SunsetAdmin.FindPlacedCheckpoint(query)
    if not cp then
        return notify(source, ('Unknown checkpoint "%s". Use /gotocp or /gotocp list to see saved names.'):format(query), 'error')
    end

    TriggerClientEvent('sunset:admin:teleport', source, cp.x, cp.y, cp.z)
    notify(source, ('Teleported to checkpoint %s (%s)'):format(cp.label or cp.id, cp.id), 'success')
end)

RegisterNetEvent('sunset:admin:gotoloc', function(query)
    local source = source
    if source == 0 then return end
    if not hasPerm(source, 'gotoloc') then return notify(source, 'No permission', 'error') end

    query = query and tostring(query):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if query == '' or string.lower(query) == 'list' then
        sendLocationList(source)
        return
    end

    local loc = SunsetAdmin.FindLocation(query)
    if not loc then
        return notify(source, ('Unknown location "%s". Use /gotoloc or /gotoloc list to see IDs.'):format(query), 'error')
    end

    local c = loc.coords
    TriggerClientEvent('sunset:admin:teleport', source, c.x, c.y, c.z)
    notify(source, ('Teleported to %s (%s)'):format(loc.label, loc.id), 'success')
end)

RegisterNetEvent('sunset:admin:requestSpeed', function(arg)
    local source = source
    if source == 0 then return end
    if not hasPerm(source, 'speed') then return notify(source, 'No permission', 'error') end

    local mult = 1.0
    if arg and arg ~= '' then
        local lowered = string.lower(tostring(arg))
        if lowered == 'off' or lowered == 'reset' then
            mult = 1.0
        else
            mult = tonumber(arg) or 1.0
        end
    end

    mult = math.max(0.5, math.min(mult, 10.0))
    TriggerClientEvent('sunset:admin:setSpeed', source, mult)
end)
