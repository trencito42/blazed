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

function GetJobWorkCoords(jobId)
    local def = GetJobDefinition(jobId)
    if not def or not def.locations then return nil end
    local keys = { 'depot', 'hub', 'quarry', 'site', 'dock', 'mill', 'market', 'truck_spawn', 'sell' }
    for _, key in ipairs(keys) do
        local loc = def.locations[key]
        if loc and loc.x then
            return { x = loc.x, y = loc.y, z = loc.z }
        end
    end
    for _, loc in pairs(def.locations) do
        if type(loc) == 'table' and loc.x then
            return { x = loc.x, y = loc.y, z = loc.z }
        end
    end
    return nil
end

function GetPublishedForHire()
    local list = {}
    for jobId, job in pairs(JCStorage_GetPublished()) do
        list[#list + 1] = {
            id = jobId,
            label = job.label,
            description = job.description or '',
            salary = (job.definition and job.definition.salary) or 140,
            coords = GetJobWorkCoords(jobId),
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

function EnsureCivilianJobsRegistered()
    if JCStorage_RegisterCivilianJobs then
        JCStorage_RegisterCivilianJobs()
    end
    return true
end

function GetLegacyJobId(jobId)
    return SunsetJobCreator.GetLegacyJobId(jobId)
end

exports('EnsureCivilianJobsRegistered', EnsureCivilianJobsRegistered)
exports('GetLegacyJobId', GetLegacyJobId)
exports('GetJobDefinition', GetJobDefinition)
exports('GetPublishedJobs', GetPublishedJobs)
exports('GetPublishedForHire', GetPublishedForHire)
exports('GetJobWorkCoords', GetJobWorkCoords)
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
    local ok, err = pcall(function()
        JCStorage_EnsureSchema()
        JCStorage_LoadAll()
        JCTemplates_Seed()
        JCStorage_RegisterCivilianJobs()
        JCSyncClients()
    end)
    if not ok then
        print(('^1[sunset_jobcreator] Failed to load jobs: %s^7'):format(tostring(err)))
        print('^3[sunset_jobcreator] Run sql/28-job-creator.sql on your database, then restart the resource.^7')
        return
    end
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
