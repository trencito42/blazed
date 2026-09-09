fx_version 'cerulean'
game 'gta5'

name 'sunset_fishingshop'
description 'Fishing supply shop + job NPC at Paleto Bay pontoon'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/items.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
