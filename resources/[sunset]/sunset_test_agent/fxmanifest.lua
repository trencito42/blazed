fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_test_agent'
author 'SunsetMP'
description 'DEV-ONLY: runtime testing bridge for MCP agents. Disabled by default; requires convar + admin allowlist.'
version '1.0.0'

-- NOT ensured in production server.cfg. Enabled explicitly by devs:
--   ensure sunset_test_agent
--   setr sunset_test_agent_enabled true
--   set sunset_test_agent_token <random dev token>

shared_scripts {
    '@sunset_core/shared/config.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/log.lua',
    'server/auth.lua',
    'server/rpc.lua',
    'server/tools.lua',
    'server/domains.lua',
    'server/http.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/log.lua',
    'client/rpc.lua',
    'client/nui_debug.lua',
    'client/tools.lua',
    'client/main.lua',
}

dependencies { 'sunset_core' }
