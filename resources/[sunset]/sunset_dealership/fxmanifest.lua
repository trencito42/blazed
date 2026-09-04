fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_dealership'
description 'Persistent vehicle dealership with stock, previews, test drives and admin management'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    'shared/config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_vehicles', 'sunset_admin' }
