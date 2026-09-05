fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_admin'
description 'Admin system — permissions & commands'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/utils.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/items.lua',
    '@sunset_core/shared/jobs_civilian.lua',
    '@sunset_core/shared/jobs_config.lua',
    '@sunset_core/shared/crafting.lua',
    'shared/config.lua',
    'shared/locations.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/checkpoints.lua',
    'server/commands.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_death', 'sunset_factions' }
