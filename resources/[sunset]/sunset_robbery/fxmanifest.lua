fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_robbery'
author 'SunsetMP'
description 'Interactive jewelry / luxury-store robbery'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/faction_core.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/items.lua',
    'shared/config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/nui.lua',
    'client/animations.lua',
    'client/world.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/adapter.lua',
    'server/loot.lua',
    'server/sessions.lua',
    'server/police.lua',
    'server/main.lua',
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_inventory',
}
