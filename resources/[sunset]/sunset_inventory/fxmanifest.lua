fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_inventory'
description 'Character inventory system'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/items.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
    'client/weapons.lua',
}

server_exports {
    'GetInventory', 'AddItem', 'RemoveItem', 'HasItem', 'UseItem',
    'SetItemMetadata', 'GetGasCanLiters', 'CountItem', 'TakeAllItems',
}
