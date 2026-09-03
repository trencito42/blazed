fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_documents'
description 'ID card and licenses viewer'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
