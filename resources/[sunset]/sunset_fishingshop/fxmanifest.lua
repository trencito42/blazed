fx_version 'cerulean'
game 'gta5'

name 'sunset_fishingshop'
description 'Fishing supply shop + job NPC at Paleto Bay pontoon'
version '1.0.0'

shared_scripts { '../../[sunset]/sunset_core/shared/utils.lua' }

client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
