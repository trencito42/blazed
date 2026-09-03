exports.sunset_core:RegisterCallback('sunset:hireJob', function(source, jobId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end
    if not Sunset.CivilianJobs[jobId] then return nil, 'Invalid job — factions join at HQ (LSPD, EMS, etc.)' end

    local currentJob = select(1, Sunset.GetCharacterJob(char))
    if currentJob ~= 'unemployed' and currentJob ~= jobId then
        local current = Sunset.CivilianJobs[currentJob]
        return nil, ('You already work as %s.'):format(current and current.label or currentJob)
    end
    if currentJob == jobId then
        return nil, 'You already have this job'
    end

    if not exports.sunset_core:SetJob(source, jobId, 0) then
        return nil, 'Could not set job'
    end

    TriggerClientEvent('sunset:client:notify', source,
        'Job set: ' .. (Sunset.CivilianJobs[jobId].label or jobId), 'success')
    return true
end)

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

RegisterCommand('setjob', function(source, args)
    if source ~= 0 and not exports.sunset_admin:IsAdmin(source, 3) then
        TriggerClientEvent('sunset:client:notify', source, 'No permission', 'error')
        return
    end

    local targetArg = args[1]
    local jobId = args[2]
    local grade = tonumber(args[3]) or 0
    if not targetArg or not jobId then
        local msg = 'Usage: /setjob [id|username] [job] [grade]'
        if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'error') end
        return
    end

    local target = resolvePlayer(source, targetArg)
    if not target then
        local msg = 'Player not found or offline'
        if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'error') end
        return
    end

    if not Sunset.Jobs[jobId] and not Sunset.CivilianJobs[jobId] then
        local msg = 'Invalid job: ' .. jobId
        if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'error') end
        return
    end

    if Sunset.Factions[jobId] then
        exports.sunset_core:SetFaction(target, jobId, grade)
    else
        exports.sunset_core:SetJob(target, jobId, grade)
    end
    local label = Sunset.Jobs[jobId].label
    TriggerClientEvent('sunset:client:notify', target, 'Job set to ' .. label, 'success')
    if source ~= 0 then
        TriggerClientEvent('sunset:client:notify', source, 'Set job for ' .. GetPlayerName(target), 'success')
    end
end, false)
