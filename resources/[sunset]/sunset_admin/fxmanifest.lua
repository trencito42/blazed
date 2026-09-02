fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_admin'
description 'Admin system — permissions & commands'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/utils.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/commands.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies { 'sunset_core', 'sunset_ui' }
