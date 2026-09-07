SunsetJobCreator = SunsetJobCreator or {}

--- Legacy sunset_jobs id → published creator template id.
SunsetJobCreator.LegacyMigrations = {
    trucker = 'jc_tpl_route',
    courier = 'jc_tpl_courier',
    garbage = 'jc_tpl_garbage',
    fisherman = 'jc_tpl_gather',
    lumberjack = 'jc_tpl_lumber',
}

function SunsetJobCreator.GetMigrationTarget(legacyJobId)
    return SunsetJobCreator.LegacyMigrations[legacyJobId]
end

function SunsetJobCreator.GetLegacyJobId(jobId)
    jobId = tostring(jobId or '')
    if SunsetJobCreator.LegacyMigrations[jobId] then
        return jobId
    end
    for legacy, creatorId in pairs(SunsetJobCreator.LegacyMigrations) do
        if creatorId == jobId then
            return legacy
        end
    end
    return nil
end

function SunsetJobCreator.GetCreatorJobId(jobId)
    jobId = tostring(jobId or '')
    if SunsetJobCreator.IsCreatorJobId(jobId) then
        return jobId
    end
    return SunsetJobCreator.LegacyMigrations[jobId]
end
