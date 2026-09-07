local function requireAdmin(source)
    if source == 0 then return true end
    return exports.sunset_admin:IsAdmin(source, 3)
end

local function listJobsForAdmin()
    local ok, result = pcall(function()
        local jobs = JCStorage_List()
        if #jobs == 0 then
            JCTemplates_Seed()
            JCStorage_LoadAll()
            JCStorage_RegisterCivilianJobs()
            JCSyncClients()
            jobs = JCStorage_List()
        end
        return { jobs = jobs }
    end)
    if not ok then
        return nil, ('Job Creator database error: %s'):format(tostring(err))
    end
    return result
end

exports.sunset_core:RegisterCallback('sunset:jobcreator:list', function(source)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    return listJobsForAdmin()
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:seedTemplates', function(source)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    local before = #JCStorage_List()
    JCTemplates_Seed()
    JCStorage_LoadAll()
    JCStorage_RegisterCivilianJobs()
    JCSyncClients()
    TriggerClientEvent('sunset:jobcreator:definitionsUpdated', -1)
    local after = #JCStorage_List()
    return {
        jobs = JCStorage_List(),
        seeded = math.max(0, after - before),
        total = after,
    }
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:get', function(source, jobId)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    local job = JCStorage_Get(jobId)
    if not job then return nil, SunsetJobCreator.L('job_not_found') end
    return job
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:save', function(source, payload)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    payload = type(payload) == 'table' and payload or {}
    local jobId = SunsetJobCreator.NormalizeId(payload.id)
    if not jobId then return nil, 'Invalid job id.' end
    local actor = GetPlayerName(source) or tostring(source)
    return JCStorage_Save(jobId, {
        label = payload.label or jobId,
        description = payload.description or '',
        category = payload.category or 'civilian',
        icon = payload.icon or 'briefcase',
        status = payload.status or 'draft',
    }, payload.definition, actor)
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:publish', function(source, jobId, status)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    local actor = GetPlayerName(source) or tostring(source)
    local job, err = JCStorage_SetStatus(jobId, status or 'published', actor)
    if job then JCStorage_RegisterCivilianJobs() end
    JCSyncClients()
    TriggerClientEvent('sunset:jobcreator:definitionsUpdated', -1)
    return job, err
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:delete', function(source, jobId)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    local actor = GetPlayerName(source) or tostring(source)
    JCStorage_Delete(jobId, actor)
    JCStorage_RegisterCivilianJobs()
    JCSyncClients()
    TriggerClientEvent('sunset:jobcreator:definitionsUpdated', -1)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:export', function(source, jobId)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    return JCStorage_Export(jobId)
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:import', function(source, payload)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    local actor = GetPlayerName(source) or tostring(source)
    local job, err = JCStorage_Import(payload, actor)
    if job then
        JCStorage_RegisterCivilianJobs()
        if JCSyncClients then JCSyncClients() end
        TriggerClientEvent('sunset:jobcreator:definitionsUpdated', -1)
    end
    return job, err
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:clientAction', function(source, data)
    return JCEngine_ClientAction(source, data)
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:stageCatalog', function(source)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    return { catalog = SunsetJobCreator.GetStageCatalog() }
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:startWork', function(source, testJobId)
    local jobId = testJobId
    local testMode = false
    if jobId and requireAdmin(source) then
        testMode = true
    else
        local char = exports.sunset_core:GetCharacter(source)
        if not char then return nil, 'Character not loaded.' end
        jobId = select(1, Sunset.GetCharacterJob(char))
        local mig = SunsetJobCreator.GetMigrationTarget(jobId)
        if mig and JCStorage_Get(mig) and JCStorage_Get(mig).status == 'published' then
            jobId = mig
        end
    end
    if not SunsetJobCreator.IsCreatorJobId(jobId) then
        return nil, 'Not a creator job.'
    end
    local row = JCStorage_Get(jobId)
    if not row or row.status ~= 'published' then
        if not testMode then return nil, SunsetJobCreator.L('job_disabled') end
        row = JCStorage_Get(jobId)
    end
    if not row then return nil, SunsetJobCreator.L('job_not_found') end
    return JCEngine_Start(source, row, testMode)
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:interact', function(source)
    return JCEngine_Interact(source)
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:cancel', function(source)
    JCSessions_Clear(source, SunsetJobCreator.L('shift_cancelled'), false)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:debugSkip', function(source)
    if not requireAdmin(source) then return nil, SunsetJobCreator.L('not_admin') end
    return JCEngine_DebugSkip(source)
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:publishedForHire', function()
    return GetPublishedForHire()
end)
