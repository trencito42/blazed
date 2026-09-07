local PublishedIds = {}

RegisterNetEvent('sunset:jobcreator:syncJobs', function(ids)
    PublishedIds = type(ids) == 'table' and ids or {}
end)

exports('IsCreatorJob', function(jobId)
    if not SunsetJobCreator.IsCreatorJobId(jobId) then return false end
    return PublishedIds[jobId] == true
end)

exports('GetMigrationTarget', function(legacyJobId)
    return SunsetJobCreator.GetMigrationTarget(legacyJobId)
end)

exports('StartWork', function(testJobId)
    JCRuntime_StartWork(testJobId)
end)

exports('CancelWork', function()
    return JCRuntime_Cancel()
end)

exports('IsSessionActive', function()
    return JCRuntime_IsActive()
end)

CreateThread(function()
    Wait(3000)
    TriggerServerEvent('sunset:jobcreator:requestSync')
end)

RegisterNetEvent('sunset:jobcreator:definitionsUpdated', function()
    TriggerServerEvent('sunset:jobcreator:requestSync')
end)
