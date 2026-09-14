fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_fishing_tournament'
description 'Fishing tournament — periodic competition, most fish wins'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies { 'sunset_core', 'sunset_events' }
