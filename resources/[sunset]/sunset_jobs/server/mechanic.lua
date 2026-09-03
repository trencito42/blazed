local MechanicProviders = {}
local LastRepair = {}

local function charJob(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return 'unemployed' end
    return select(1, Sunset.GetCharacterJob(char))
end

exports.sunset_core:RegisterCallback('sunset:jobs:mechanic:start', function(source)
    if charJob(source) ~= 'mechanic' then return nil, 'Not employed as mechanic' end

    local cfg = Sunset.GetJobConfig('mechanic')
    if not SunsetJobs_ValidateCoords(source, cfg.depot.coords, 12.0) then return nil, 'Go to the mechanic depot to start work' end
    local session, err = SunsetJobs_StartSession(source, 'mechanic', {
        repairs = 0,
        activeCallId = nil,
        stage = 'on_duty',
    })
    if not session then return nil, err end

    MechanicProviders[source] = true
    SunsetJobs_SetState(source, 'ACTIVE')

    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:mechanic:acceptCall', function(source, callId)
    local session, err = SunsetJobs_RequireSession(source, 'mechanic', { 'ACTIVE' })
    if not session then return nil, err end
    if session.data.activeCallId then return nil, 'Already on a call' end

    callId = tonumber(callId)
    if GetResourceState('sunset_dispatch') == 'started' then
        local ok, result = pcall(function()
            return exports.sunset_dispatch:AcceptCall(source, 'mechanic', callId)
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

    if not session.data.activeCallId then return nil, 'Accept a mechanic service call first' end
    local now = GetGameTimer()
    if now - (LastRepair[source] or 0) < 10000 then return nil, 'Wait before repairing again' end
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
    local targetPed = GetPlayerPed(targetSource)
    if not targetPed or targetPed == 0 or GetVehiclePedIsIn(targetPed, false) == 0 then return nil, 'Customer must be in a vehicle' end
    local call = exports.sunset_dispatch:GetCall(session.data.activeCallId)
    if not call or tonumber(call.callerSource) ~= targetSource then return nil, 'Repair the customer assigned to this call' end
    LastRepair[source] = now

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
            exports.sunset_dispatch:CompleteCall(source, 'mechanic', callId)
        end)
    end

    return { pay = pay, restore = restore }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:mechanic:endShift', function(source)
    local session = SunsetJobs_GetSession(source)
    if not session or session.jobId ~= 'mechanic' then return nil, 'Not on duty' end

    MechanicProviders[source] = nil
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

AddEventHandler('sunset:dispatch:callAccepted', function(callId, callType, providerSource, callerSource)
    if callType ~= 'mechanic' or not MechanicProviders[providerSource] then return end
    local session = SunsetJobs_GetSession(providerSource)
    if not session or session.jobId ~= 'mechanic' then return end
    session.data.activeCallId = tonumber(callId)
    session.data.stage = 'en_route'
    TriggerClientEvent('sunset:jobs:stateChanged', providerSource, 'ACTIVE', session.data)
end)

exports('GetMechanicProviders', function()
    return MechanicProviders
end)

AddEventHandler('playerDropped', function()
    MechanicProviders[source] = nil
    LastRepair[source] = nil
end)
