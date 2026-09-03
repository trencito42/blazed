local MechanicProviders = {}

local function charJob(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return 'unemployed' end
    return select(1, Sunset.GetCharacterJob(char))
end

exports.sunset_core:RegisterCallback('sunset:jobs:mechanic:start', function(source)
    if charJob(source) ~= 'mechanic' then return nil, 'Not employed as mechanic' end

    local session, err = SunsetJobs_StartSession(source, 'mechanic', {
        repairs = 0,
        activeCallId = nil,
        stage = 'on_duty',
    })
    if not session then return nil, err end

    MechanicProviders[source] = true
    SunsetJobs_SetState(source, 'ACTIVE')

    if GetResourceState('sunset_dispatch') == 'started' then
        pcall(function()
            TriggerEvent('sunset:dispatch:registerProvider', source, 'mechanic')
        end)
    end

    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:mechanic:acceptCall', function(source, callId)
    local session, err = SunsetJobs_RequireSession(source, 'mechanic', { 'ACTIVE' })
    if not session then return nil, err end
    if session.data.activeCallId then return nil, 'Already on a call' end

    callId = tonumber(callId)
    if GetResourceState('sunset_dispatch') == 'started' then
        local ok, result = pcall(function()
            return exports.sunset_dispatch:AcceptCall(source, callId)
        end)
        if ok and result then
            session.data.activeCallId = callId
            session.data.stage = 'en_route'
            return { callId = callId }
        end
    end

    return nil, 'Could not accept call'
end)

exports.sunset_core:RegisterCallback('sunset:jobs:mechanic:repair', function(source, targetSource)
    local session, err = SunsetJobs_RequireSession(source, 'mechanic', { 'ACTIVE' })
    if not session then return nil, err end

    targetSource = tonumber(targetSource)
    if not targetSource or not GetPlayerName(targetSource) then
        return nil, 'Customer not found'
    end

    local cfg = Sunset.GetJobConfig('mechanic')
    local mePos = GetEntityCoords(GetPlayerPed(source))
    local themPos = GetEntityCoords(GetPlayerPed(targetSource))
    if #(mePos - themPos) > (cfg.repairRadius or 6.0) then
        return nil, 'Too far from the vehicle'
    end

    local level = 1
    local char = exports.sunset_core:GetCharacter(source)
    if char then
        local row = MySQL.single.await(
            'SELECT level FROM job_progress WHERE character_id = ? AND job_id = ?',
            { char.id, 'mechanic' }
        )
        level = row and row.level or 1
    end

    local minH = cfg.healthRestoreMin or 400
    local maxH = cfg.healthRestoreMax or 1000
    local restore = math.min(1000, minH + math.floor((maxH - minH) * (level / 10)))

    TriggerClientEvent('sunset:jobs:mechanic:applyRepair', targetSource, restore)

    local pay = cfg.payPerRepair or 200
    SunsetJobs_PayReward(source, 'mechanic', pay, 'mechanic_repair', true)
    SunsetJobs_AddJobXP(source, 'mechanic', cfg.xpPerRepair or 20)

    session.data.repairs = (session.data.repairs or 0) + 1

    local callId = session.data.activeCallId
    session.data.activeCallId = nil
    session.data.stage = 'on_duty'

    if callId and GetResourceState('sunset_dispatch') == 'started' then
        pcall(function()
            exports.sunset_dispatch:CompleteCall(callId)
        end)
    end

    return { pay = pay, restore = restore }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:mechanic:endShift', function(source)
    local session = SunsetJobs_GetSession(source)
    if not session or session.jobId ~= 'mechanic' then return nil, 'Not on duty' end

    MechanicProviders[source] = nil
    if GetResourceState('sunset_dispatch') == 'started' then
        pcall(function()
            TriggerEvent('sunset:dispatch:unregisterProvider', source, 'mechanic')
        end)
    end

    SunsetJobs_ClearSession(source, 'COMPLETED', 'Off duty')
    return true
end)

RegisterNetEvent('sunset:jobs:mechanic:dispatchOffer', function(callData)
    local src = source
    if src and src > 0 and MechanicProviders[src] then
        TriggerClientEvent('sunset:jobs:mechanic:newCall', src, callData)
    end
end)

AddEventHandler('sunset:jobs:notifyMechanicCall', function(callData)
    for src, _ in pairs(MechanicProviders) do
        TriggerClientEvent('sunset:jobs:mechanic:newCall', src, callData)
    end
end)

exports('GetMechanicProviders', function()
    return MechanicProviders
end)

AddEventHandler('playerDropped', function()
    MechanicProviders[source] = nil
end)
