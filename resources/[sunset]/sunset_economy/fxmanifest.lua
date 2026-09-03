fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_economy'
description 'Payday, shops, ATM'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_inventory', 'sunset_ui', 'sunset_world', 'sunset_factions' }

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/jobs_civilian.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/items.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

exports {
    'GetNextPayday',
}
