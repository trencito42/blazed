fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_world'
description 'Map blips, markers and world interaction zones'
version '1.1.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/faction_core.lua',
    'shared/faction.lua',
    '@sunset_core/shared/items.lua',
    '@sunset_core/shared/factions.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/interaction.lua',
    'client/world_tooltips.lua',
    'client/npc_lib.lua',
    'client/stores_247.lua',
    'client/business_npcs.lua',
    'client/main.lua',
    'client/elevators.lua',
    'client/fib_interior.lua',
}

server_scripts {
    'server/access.lua',
}

dependencies { 'sunset_core', 'sunset_ui' }
