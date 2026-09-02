fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_menu'
description 'Player menu (M) — stats reale'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
}

client_scripts { 'client/main.lua' }

dependencies { 'sunset_core', 'sunset_ui', 'sunset_hud' }
