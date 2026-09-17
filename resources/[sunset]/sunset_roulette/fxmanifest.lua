fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_roulette'
description '1:1 GTA Online 3D Diamond Casino Roulette for SunsetMP'
version '1.0.0'

shared_scripts {
    'lib_shim.lua',
    'config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client.lua',
}

server_scripts {
    '@sunset_core/shared/config.lua',
    'server.lua',
}

dependencies {
    'sunset_core',
    'sunset_inventory',
    'sunset_ui',
}
