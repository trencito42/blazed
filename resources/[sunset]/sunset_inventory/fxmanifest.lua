fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_inventory'
description 'Character inventory system'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

server_exports { 'GetInventory', 'AddItem', 'RemoveItem', 'HasItem', 'UseItem' }
