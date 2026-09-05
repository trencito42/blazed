fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_properties'
description 'Buyable properties and home spawn'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui', 'sunset_world', 'sunset_admin' }

shared_scripts {
    '@sunset_core/shared/config.lua',
    'shared/config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
