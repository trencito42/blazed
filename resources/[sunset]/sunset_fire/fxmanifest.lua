fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_fire'
description 'LSFD fire incidents — vehicle fires and extinguisher gameplay'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/faction_core.lua',
    '@sunset_core/shared/factions.lua',
    'shared/config.lua',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_factions',
    'sunset_dispatch',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
