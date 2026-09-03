fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_spawn'
author 'SunsetMP'
description 'Player spawn and world entry'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/utils.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_characters',
    'sunset_appearance',
}
