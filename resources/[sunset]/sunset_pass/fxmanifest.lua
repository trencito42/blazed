fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_pass'
author 'SunsetMP'
description 'Sunset Pass — seasonal battle pass and missions'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/items.lua',
    'shared/config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
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
