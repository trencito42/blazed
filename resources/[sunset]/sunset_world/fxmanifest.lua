fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_world'
description 'Map blips, markers and world interaction zones'
version '1.0.2'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/faction_core.lua',
    'shared/faction.lua',
    '@sunset_core/shared/items.lua',
    '@sunset_core/shared/factions.lua',
}

client_scripts {
    'client/main.lua',
    'client/elevators.lua',
    'client/fib_interior.lua',
}

server_scripts {
    'server/access.lua',
}

dependencies { 'sunset_core', 'sunset_factions' }
