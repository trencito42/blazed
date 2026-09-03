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

-- /coords
RegisterCommand('coords', function(source)
    if source == 0 then return end
    if not hasPerm(source, 'coords') then return end
    TriggerClientEvent('sunset:admin:copyCoords', source)
end, false)
