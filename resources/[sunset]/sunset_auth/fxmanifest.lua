fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_auth'
description 'Username/password authentication'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
