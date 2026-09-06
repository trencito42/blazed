fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_chat'
description 'Chat & comenzi SAMP-style'
version '1.0.0'

shared_scripts {
    '@sunset_admin/shared/config.lua',
    '@sunset_core/shared/help_registry.lua',
}

client_scripts { 'client/main.lua' }
server_scripts {
    'server/main.lua',
    'server/command_router.lua',
}

dependencies { 'sunset_ui', 'sunset_core', 'sunset_admin' }
