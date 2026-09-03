fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_appearance'
description 'Character appearance editor on first spawn'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

shared_scripts {
    '@sunset_core/shared/config.lua',
}

exports { 'IsEditing' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
}

server_scripts { 'server/main.lua' }
