fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_appearance'
description 'Character appearance editor on first spawn'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/utils.lua',
}

exports { 'IsEditing', 'ApplyAppearance' }

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/torso_data.lua',
    'client/appearance_lib.lua',
    'client/main.lua',
}

files {
    'data/besttorso_male.json',
    'data/besttorso_female.json',
}

server_scripts { 'server/main.lua' }
