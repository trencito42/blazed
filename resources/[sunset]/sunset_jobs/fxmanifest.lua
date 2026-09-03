fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_jobs'
description 'Job center, civilian job loops, and setjob'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/jobs_civilian.lua',
    '@sunset_core/shared/jobs_config.lua',
    '@sunset_core/shared/job_session.lua',
    '@sunset_core/shared/job_session.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/items.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_world' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/core.lua',
    'client/trucker.lua',
    'client/garbage.lua',
    'client/courier.lua',
    'client/fisherman.lua',
    'client/mechanic.lua',
    'client/commands.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core.lua',
    'server/trucker.lua',
    'server/garbage.lua',
    'server/courier.lua',
    'server/fisherman.lua',
    'server/mechanic.lua',
    'server/main.lua',
}

server_exports {
    'GetMechanicProviders',
}
