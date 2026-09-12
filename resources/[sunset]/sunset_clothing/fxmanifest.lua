fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_clothing'
description 'Clothing and barber shops'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/items.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_world', 'sunset_appearance', 'oxmysql' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    '@sunset_appearance/client/torso_data.lua',
    '@sunset_appearance/client/appearance_lib.lua',
    '@sunset_appearance/client/clothing_compat.lua',
    'client/wardrobe.lua',
    'client/debug.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/outfits.lua',
}
