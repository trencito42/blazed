function IsCreatorJob(jobId)
    return SunsetJobCreator.IsCreatorJobId(jobId) and JCStorage_Get(jobId) ~= nil
end

function GetJobDefinition(jobId)
    local row = JCStorage_Get(jobId)
    return row and row.definition
end

function GetPublishedJobs()
    return JCStorage_GetPublished()
end

function StartJob(source, jobId, testMode)
    local row = JCStorage_Get(jobId)
    if not row then return nil, SunsetJobCreator.L('job_not_found') end
    return JCEngine_Start(source, row, testMode == true)
end

function CancelJob(source)
    JCSessions_Clear(source, SunsetJobCreator.L('shift_cancelled'), false)
    return true
end

function GetActiveJob(source)
    return JCSessions_Get(source)
end

function GetMigrationTarget(legacyJobId)
    return SunsetJobCreator.GetMigrationTarget(legacyJobId)
end

exports('IsCreatorJob', IsCreatorJob)
exports('GetJobDefinition', GetJobDefinition)
exports('GetPublishedJobs', GetPublishedJobs)
exports('GetMigrationTarget', GetMigrationTarget)
exports('StartJob', StartJob)
exports('CancelJob', CancelJob)
exports('GetActiveJob', GetActiveJob)

function JCSyncClients()
    local ids = {}
    for jobId in pairs(JCStorage_GetPublished()) do
        ids[jobId] = true
    end
    TriggerClientEvent('sunset:jobcreator:syncJobs', -1, ids)
end

RegisterNetEvent('sunset:jobcreator:requestSync', function()
    JCSyncClients()
end)

CreateThread(function()
    Wait(500)
    JCStorage_LoadAll()
    JCTemplates_Seed()
    JCStorage_RegisterCivilianJobs()
    JCSyncClients()
    print(('[sunset_jobcreator] Loaded %d job definition(s).'):format(#JCStorage_List()))
end)

RegisterCommand('jobcreator', function(source)
    if source == 0 then return end
    runJobCreator(source)
end, false)

RegisterCommand('jcdebug', function(source)
    if source == 0 then return end
    runJcDebug(source)
end, false)

function runJobCreator(source)
    if not exports.sunset_admin:IsAdmin(source, 3) then
        exports.sunset_core:CommandDenyAdmin(source, 'jobcreator')
        return
    end
    TriggerClientEvent('sunset:jobcreator:openPanel', source)
end

function runJcDebug(source)
    if not exports.sunset_admin:IsAdmin(source, 3) then return end
    local session = JCSessions_Get(source)
    if not session then
        exports.sunset_core:CommandReply(source, 'No active creator session.', 'error')
        return
    end
    local payload, err = JCEngine_DebugSkip(source)
    exports.sunset_core:CommandReply(source, err or ('Skipped to stage: %s'):format(payload and payload.stageId or '?'), 'info')
end

function ExecutePlayerCommand(source, name, args)
    name = string.lower(tostring(name or ''))
    if name == 'jobcreator' then
        runJobCreator(source)
        return true
    end
    if name == 'jcdebug' then
        runJcDebug(source)
        return true
    end
    return false
end

exports('ExecutePlayerCommand', ExecutePlayerCommand)

TriggerEvent('chat:addSuggestion', '/jobcreator', 'Open the civilian Job Creator (admin)')
TriggerEvent('chat:addSuggestion', '/jcdebug', 'Skip current creator job stage (admin)')
