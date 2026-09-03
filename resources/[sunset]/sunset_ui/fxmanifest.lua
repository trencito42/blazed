fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_ui'
author 'SunsetMP'
description 'NUI framework — cinematic sunset design system'
version '1.0.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/style.css',
    'web/css/fonts.css',
    'web/css/hud.css',
    'web/css/scoreboard.css',
    'web/css/chat.css',
    'web/css/menu.css',
    'web/css/panels.css',
    'web/css/studio.css',
    'web/css/phone.css',
    'web/js/*.js',
    'web/assets/**/*',
}

client_scripts {
    'client/main.lua',
    'client/nui_bridge.lua',
}

exports {
    'Show',
    'Hide',
    'Send',
    'IsOpen',
    'Notify',
    'ProgressBar',
    'SetFocus',
}
