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
    '@sunset_core/shared/faction_core.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/police.lua',
}

dependencies { 'sunset_core', 'sunset_ui', 'sunset_world', 'sunset_inventory', 'sunset_death', 'sunset_appearance' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/loadout.lua',
    'client/friendlyfire.lua',
    'client/detention.lua',
    'client/police.lua',
    'client/ems.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core.lua',
    'server/faction_labels.lua',
    'server/detention.lua',
    'server/main.lua',
    'server/chat.lua',
    'server/leaders.lua',
    'server/faction_roster.lua',
    'server/police.lua',
    'server/ems.lua',
    'server/friendlyfire.lua',
}

exports { 'IsOnDuty', 'GetDutyState', 'IsFactionLeader', 'GetLeaderHqSpawn', 'HasFactionPerm', 'IsCuffed', 'GetWantedState', 'IsJailed', 'GetDetentionState', 'AddWantedCharge', 'ExecutePlayerCommand' }
