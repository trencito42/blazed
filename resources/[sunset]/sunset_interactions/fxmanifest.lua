fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_interactions'
author 'SunsetMP'
description 'Context-aware nearby player interaction menu'
version '1.0.0'

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_factions',
    'sunset_phone',
}

client_script 'client/main.lua'
server_script 'server/main.lua'
