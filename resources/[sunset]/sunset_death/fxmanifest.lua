fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_death'
description 'Death and respawn'
version '1.0.0'

dependencies { 'sunset_core', 'sunset_ui' }

shared_scripts { '@sunset_core/shared/config.lua' }

client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
