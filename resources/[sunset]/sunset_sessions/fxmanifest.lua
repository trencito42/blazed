fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_sessions'
author 'SunsetMP'
description 'Canonical server-authoritative gameplay session framework (docs/architecture/GAMEPLAY_SESSIONS.md)'
version '1.0.0'

dependencies { 'sunset_core' }

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

server_exports {
    'CreateSession',
    'GetSession',
    'GetSessionBySource',
    'Transition',
    'CancelSession',
    'EndSession',
    'RegisterActivity',
    'ListSessions',
}

client_exports {
    'EmergencyCleanup',
}
