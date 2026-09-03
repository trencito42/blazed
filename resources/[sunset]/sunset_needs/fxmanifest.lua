fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_needs'
description 'Hunger, thirst, stress'
version '1.0.0'

dependencies { 'sunset_core' }

shared_scripts { '@sunset_core/shared/config.lua' }

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }
