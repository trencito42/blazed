local function hasPerm(source, cmd)
    local need = SunsetAdmin.Commands[cmd] or 99
    return IsAdmin(source, need)
end

local function notify(source, msg, type)
    TriggerClientEvent('sunset:client:notify', source, msg, type or 'info')
end

local function getTarget(source, id)
    local target = tonumber(id)
    if not target or not GetPlayerName(target) then
        if source ~= 0 then notify(source, 'Jucător invalid (ID: ' .. tostring(id) .. ')', 'error') end
        return nil
    end
    return target
end

local function resolveTarget(source, idArg)
    if idArg then
        return getTarget(source, idArg)
    end
    if source == 0 then
        print('[Sunset] Trebuie specificat un ID jucător')
        return nil
    end
    return source
end

-- /kick [id] [motiv]
RegisterCommand('kick', function(source, args)
    if source ~= 0 and not hasPerm(source, 'kick') then return notify(source, 'Fără permisiune', 'error') end
    local target = getTarget(source, args[1])
    if not target then return end
    local reason = table.concat(args, ' ', 2)
    if reason == '' then reason = 'Fără motiv' end
    DropPlayer(target, 'Ai fost dat afară: ' .. reason)
    if source ~= 0 then notify(source, 'Kick reușit', 'success') end
end, false)

-- /ban [id] [motiv]
RegisterCommand('ban', function(source, args)
    if source ~= 0 and not hasPerm(source, 'ban') then return notify(source, 'Fără permisiune', 'error') end
    local target = getTarget(source, args[1])
    if not target then return end
    local reason = table.concat(args, ' ', 2)
    if reason == '' then reason = 'Ban permanent' end

    local license = Sunset.GetIdentifier(target, 'license')
    local bannedBy = source == 0 and 'console' or GetPlayerName(source)

    MySQL.insert.await('INSERT INTO bans (license, reason, banned_by) VALUES (?, ?, ?)', { license, reason, bannedBy })
    DropPlayer(target, 'Banat: ' .. reason)
    if source ~= 0 then notify(source, 'Ban reușit', 'success') end
end, false)

-- /tp [id] sau /tp x y z
RegisterCommand('tp', function(source, args)
    if source == 0 then return end
    if not hasPerm(source, 'tp') then return notify(source, 'Fără permisiune', 'error') end

    if args[1] and not args[2] then
        local target = getTarget(source, args[1])
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
    if not hasPerm(source, 'bring') then return notify(source, 'Fără permisiune', 'error') end
    local target = getTarget(source, args[1])
    if not target then return end
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('sunset:admin:teleport', target, coords.x, coords.y, coords.z)
    notify(source, 'Jucător adus', 'success')
end, false)

-- /car [model]
RegisterCommand('car', function(source, args)
    if source == 0 then return end
    if not hasPerm(source, 'car') then return notify(source, 'Fără permisiune', 'error') end
    local model = args[1] or 'sultan'
    TriggerClientEvent('sunset:admin:spawnVehicle', source, model)
end, false)

-- /dv
RegisterCommand('dv', function(source)
    if source == 0 then return end
    if not hasPerm(source, 'dv') then return notify(source, 'Fără permisiune', 'error') end
    TriggerClientEvent('sunset:admin:deleteVehicle', source)
end, false)

-- /heal [id]
RegisterCommand('heal', function(source, args)
    if source == 0 then return end
    if not hasPerm(source, 'heal') then return notify(source, 'Fără permisiune', 'error') end
    local target = resolveTarget(source, args[1])
    if not target then return end
    TriggerClientEvent('sunset:admin:heal', target)
    notify(source, 'Heal aplicat pe ' .. GetPlayerName(target) .. ' (ID ' .. target .. ')', 'success')
end, false)

-- /revive [id]
RegisterCommand('revive', function(source, args)
    if source == 0 then return end
    if not hasPerm(source, 'revive') then return notify(source, 'Fără permisiune', 'error') end
    local target = resolveTarget(source, args[1])
    if not target then return end
    TriggerClientEvent('sunset:admin:revive', target)
    notify(source, 'Revive aplicat pe ' .. GetPlayerName(target) .. ' (ID ' .. target .. ')', 'success')
end, false)

-- /noclip
RegisterCommand('noclip', function(source)
    if source == 0 then return end
    if not hasPerm(source, 'noclip') then return notify(source, 'Fără permisiune', 'error') end
    TriggerClientEvent('sunset:admin:toggleNoclip', source)
end, false)

-- /god
RegisterCommand('god', function(source)
    if source == 0 then return end
    if not hasPerm(source, 'god') then return notify(source, 'Fără permisiune', 'error') end
    TriggerClientEvent('sunset:admin:toggleGod', source)
end, false)

-- /announce [mesaj]
RegisterCommand('announce', function(source, args)
    if source ~= 0 and not hasPerm(source, 'announce') then return notify(source, 'Fără permisiune', 'error') end
    local msg = table.concat(args, ' ')
    if msg == '' then return end
    TriggerClientEvent('sunset:client:notify', -1, msg, 'warning')
end, false)

-- /setadmin [id|username] [level]
RegisterCommand('setadmin', function(source, args)
    if source ~= 0 and not hasPerm(source, 'setadmin') then return notify(source, 'Fără permisiune', 'error') end

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
        notify(source ~= 0 and source or target, 'Admin setat level ' .. level, 'success')
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
