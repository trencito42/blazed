fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_businesses'
description 'Player-owned shop businesses'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/items.lua',
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

server_exports {
    'GetOwnedBusinesses',
    'TransferOwnership',
    'GetBusinessRow',
    'GetMaxOwnedPerCharacter',
    'RecordSale',
    'RecordSaleAtCoords',
    'IsNearTwentyFourSeven',
    'ExecutePlayerCommand',
}
