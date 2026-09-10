fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_carjack'
description 'Illegal chop-shop / carjack job for SunsetMP'
version '1.0.1'

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_inventory',
    'oxmysql',
}

shared_scripts {
    '@sunset_core/shared/utils.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
