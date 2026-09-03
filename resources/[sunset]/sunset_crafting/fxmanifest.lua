fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_crafting'
description 'Crafting stations and recipes'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/crafting.lua',
    '@sunset_core/shared/items.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_inventory', 'sunset_world', 'sunset_factions' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts { 'server/main.lua' }
