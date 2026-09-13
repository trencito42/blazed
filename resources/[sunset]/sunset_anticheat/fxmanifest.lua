fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_anticheat'
author 'SunsetMP'
description 'Blaze Shield — evidence-gathering anticheat (no auto-bans; staff decide)'
version '0.1.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/items.lua',
    'shared/config.lua',
}

dependencies { 'sunset_core', 'sunset_ui' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/sampler.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/context.lua',
    'server/strikes.lua',
    'server/discord.lua',
    'server/ledger.lua',
    'server/detectors.lua',
    'server/main.lua',
}

server_exports {
    'MarkLegit',
    'MarkAdminAction',
    'IsWhitelisted',
    'GetContextSnapshot',
    'AddStrike',
    'GetHeat',
    'GetAllHeats',
    'DismissStrikes',
    'GetPanelSummary',
    'GetTicksForPanel',
}
