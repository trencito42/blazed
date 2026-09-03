fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_core'
author 'SunsetMP'
description 'Core framework — player management, database, callbacks'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/jobs_civilian.lua',
    'shared/profile.lua',
    'shared/faction_core.lua',
    'shared/factions.lua',
    'shared/crafting.lua',
    'shared/police.lua',
    'shared/utils.lua',
    'shared/items.lua',
    'shared/password.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/player.lua',
    'server/callbacks.lua',
}

client_scripts {
    'client/main.lua',
    'client/callbacks.lua',
}

exports {
    'GetPlayer',
    'GetCharacter',
    'TriggerCallback',
}

server_exports {
    'GetPlayer',
    'GetCharacter',
    'GetPlayerDisplayName',
    'RegisterCallback',
    'SaveCharacter',
    'AddMoney',
    'RemoveMoney',
    'GetMoney',
    'SetJob',
    'SetFaction',
    'AddXP',
    'GetSpawnPosition',
}
