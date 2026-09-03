fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_hud'
author 'SunsetMP'
description 'In-game HUD — health, money, street name'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/utils.lua',
    '@sunset_core/shared/jobs_civilian.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/factions.lua',
}

client_scripts {
    'client/world.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'hud_layout_default.json',
}

exports {
    'GetPaydaySeconds',
    'GetWantedLevel',
    'SetWantedLevel',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_vehicles',
    'sunset_admin',
}
