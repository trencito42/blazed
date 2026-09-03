fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_auth'
description 'Username/password authentication'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/password.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}
