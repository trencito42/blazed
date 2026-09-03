fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_dispatch'
author 'SunsetMP'
description 'Unified service dispatch — EMS, fire, police backup, mechanic, taxi'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/faction_core.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/dispatch.lua',
}

dependencies {
    'sunset_core',
    'sunset_factions',
    'oxmysql',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/service_core.lua',
    'server/commands.lua',
    'server/main.lua',
}

server_exports {
    'CreateCall',
    'CreateServiceCall',
    'AcceptCall',
    'CancelCall',
    'CompleteCall',
    'GetCall',
    'GetActiveCalls',
    'GetCallForResponder',
    'GetPlayerActiveCall',
}
