fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_jobcreator'
description 'Universal civilian job creator engine for SunsetMP'
version '0.1.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/jobs_civilian.lua',
    '@sunset_core/shared/job_session.lua',
    '@sunset_core/shared/profile.lua',
    'shared/schema.lua',
    'shared/locale.lua',
    'shared/stage_catalog.lua',
    'shared/modules.lua',
    'shared/migrations.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
    'client/entities.lua',
    'client/trucking.lua',
    'client/placement.lua',
    'client/runtime.lua',
    'client/creator.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/storage.lua',
    'server/sessions.lua',
    'server/stages.lua',
    'server/engine.lua',
    'server/trucking.lua',
    'server/creator.lua',
    'server/templates.lua',
    'server/main.lua',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_jobs',
    'sunset_admin',
}

server_exports {
    'IsCreatorJob',
    'GetJobDefinition',
    'GetPublishedJobs',
    'GetPublishedForHire',
    'GetJobWorkCoords',
    'GetMigrationTarget',
    'EnsureCivilianJobsRegistered',
    'GetLegacyJobId',
    'StartJob',
    'CancelJob',
    'GetActiveJob',
    'RegisterStageType',
    'ExecutePlayerCommand',
}

exports {
    'IsCreatorJob',
    'GetJobDefinition',
    'GetPublishedJobs',
    'GetMigrationTarget',
    'EnsureCivilianJobsRegistered',
    'GetLegacyJobId',
    'StartJob',
    'CancelJob',
    'GetActiveJob',
    'RegisterStageType',
    'StartWork',
    'CancelWork',
}
