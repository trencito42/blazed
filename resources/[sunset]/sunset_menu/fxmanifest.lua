fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_menu'
description 'Player menu (M)'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/factions.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_phone', 'sunset_vehicles' }
