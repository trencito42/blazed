fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_interactions'
author 'SunsetMP'
description 'Context-aware nearby player interaction menu'
version '1.0.0'

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_factions',
    'sunset_phone',
}

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/police.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_script 'server/main.lua'
