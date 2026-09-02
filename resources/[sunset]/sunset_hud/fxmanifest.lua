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
}

client_scripts {
    'client/main.lua',
}

exports {
    'GetPaydaySeconds',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_vehicles',
}
