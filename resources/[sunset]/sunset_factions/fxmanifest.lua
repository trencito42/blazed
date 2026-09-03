fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_factions'
description 'Factions — duty, commands, HQ, faction chat'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/jobs_civilian.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/factions.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_world', 'sunset_inventory', 'sunset_death', 'sunset_appearance' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/loadout.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

exports { 'IsOnDuty', 'GetDutyState', 'HasFactionPerm' }
