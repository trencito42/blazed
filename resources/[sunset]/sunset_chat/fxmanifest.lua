fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_chat'
description 'Chat & comenzi SAMP-style'
version '1.0.0'

shared_scripts {
    '@sunset_admin/shared/config.lua',
    '@sunset_core/shared/help_registry.lua',
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/factions.lua',
    '@sunset_core/shared/faction_core.lua',
    '@sunset_core/shared/profile.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/suggestions.lua',
    'client/main.lua',
}
server_scripts {
    'server/main.lua',
    'server/command_router.lua',
    'server/connect_motd.lua',
}

dependencies { 'sunset_ui', 'sunset_core', 'sunset_admin', 'sunset_factions', 'sunset_clans' }

exports { 'IsChatOpen', 'GetChatSuggestions', 'SyncChatSuggestions' }
