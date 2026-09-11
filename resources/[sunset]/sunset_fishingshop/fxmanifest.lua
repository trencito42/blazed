fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_fishingshop'
description 'Fishing supply shop + job NPC at Paleto Bay pontoon'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/items.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_world', 'sunset_jobs', 'sunset_businesses' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

client_exports {
    'IsNearBillyRay',
    'IsMenuOpen',
}

server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
