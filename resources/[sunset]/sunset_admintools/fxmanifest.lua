fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_admintools'
author 'SunsetMP'
description 'Admin diagnostics: resmon/lag profiler, raycast entity inspector, orphan entity sweeper, cinematic camera director'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_admin' }

server_scripts {
    'server/main.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/profiler.lua',
    'client/inspector.lua',
    'client/cinematic.lua',
}
