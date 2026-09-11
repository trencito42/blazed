fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_turfs'
description 'Los Santos Clan Turf Wars & Territory Control System'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_clans/shared/config.lua',
    '@sunset_clans/shared/ranks.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

dependencies {
    'sunset_core',
    'sunset_clans',
    'sunset_ui',
    'sunset_chat',
    'oxmysql',
}

exports {
    'RunChatCommand',
    'ExecutePlayerCommand',
}
