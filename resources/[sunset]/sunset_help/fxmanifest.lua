fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_help'
description 'Permission-filtered help command system'
version '2.0.0'

shared_scripts {
    '@sunset_admin/shared/config.lua',
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/jobs_civilian.lua',
    '@sunset_core/shared/jobs_config.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/faction_core.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/dispatch.lua',
    '@sunset_core/shared/help_registry.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}
server_scripts { 'server/main.lua' }

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_admin',
    'sunset_factions',
    'sunset_dispatch',
}
