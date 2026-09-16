fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_slots'
description '5-Reel Sizzling Fruit Slot Machines for SunsetMP'
author 'XeX / SunsetMP'

ui_page 'html/ui.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client.lua',
}

server_scripts {
    'server.lua',
}

files {
    'html/ui.html',
    'html/*.js',
    'html/*.json',
    'html/design.css',
    'html/img/*.png',
    'html/audio/*.mp3'
}