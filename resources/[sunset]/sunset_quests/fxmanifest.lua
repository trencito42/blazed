fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_quests'
author 'SunsetMP'
description 'Canonical quest/progression service (docs/product/RPG_PROGRESSION.md)'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

shared_scripts {
    '@sunset_core/shared/config.lua',
    'shared/chains.lua',
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
    'StartQuest',
    'AddProgress',
    'CompleteObjective',
    'IsQuestComplete',
    'GetProgress',
    'ClaimReward',
}
