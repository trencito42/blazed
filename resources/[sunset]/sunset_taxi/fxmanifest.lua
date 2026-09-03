fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_taxi'
description 'Downtown Cab — ride requests, dispatch, phone app'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/items.lua',
    'shared/config.lua',
    'shared/locations.lua',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_world',
    'sunset_factions',
    'sunset_phone',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
