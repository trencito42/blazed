fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_clothing'
description 'Clothing and barber shops'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/items.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_world' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
