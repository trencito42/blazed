fx_version 'cerulean'
game 'gta5'

name 'sunset_loadscreen'
author 'SunsetMP'
description 'Custom loading screen'
version '1.3.1'

loadscreen 'index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_hide_busyspinner 'yes'
loadscreen_cursor 'no'

files {
    'index.html',
    'style.css',
    'script.js',
    'assets/sunset.png',
    'assets/logoblaze.svg',
    -- [AUDIT P7-05] self-hosted fonts
    'assets/fonts/gfonts.css',
    'assets/fonts/gfonts/*.woff2',
}
