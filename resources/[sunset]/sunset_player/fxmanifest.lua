fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_player'
description 'Auto-save and character sync'
version '1.0.0'

dependencies { 'sunset_core' }

shared_scripts { '@sunset_core/shared/config.lua' }

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }
