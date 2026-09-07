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
