fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_clans'
author 'SunsetMP'
description 'Player-created clans with tags, Sunset Coins, and management UI'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    'shared/config.lua',
    'shared/tag.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/display.lua',
    'server/main.lua',
}

dependencies {
    'sunset_core',
    'sunset_ui',
}

exports {
    'FormatDisplayName',
    'GetClanChatMeta',
    'GetPlayerBaseName',
    'SyncPlayerClan',
}
