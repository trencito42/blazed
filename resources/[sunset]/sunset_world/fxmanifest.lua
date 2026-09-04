fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_world'
description 'Map blips, markers and world interaction zones'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/items.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies { 'sunset_core' }
