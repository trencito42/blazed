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
    'web/css/*.css',
    'web/css/style.css',
    'web/css/fonts.css',
    'web/css/hud.css',
    'web/css/scoreboard.css',
    'web/css/chat.css',
    'web/css/menu.css',
    'web/css/panels.css',
    'web/css/studio.css',
    'web/css/phone.css',
    'web/css/fuel_pump.css',
    'web/css/fishing.css',
    'web/css/license_test.css',
    'web/css/license_quiz.css',
    'web/css/job_creator.css',
    'web/css/radar.css',
    'web/css/courier.css',
    'web/css/factions.css',
    'web/css/clans.css',
    'web/css/org-panels.css',
    'web/css/auth_loading.css',
    'web/css/spawn.css',
    'web/css/theme.css',
    'web/css/gameplay_glass.css',
    'web/css/mdc_tablet.css',
    'web/css/player_interaction.css',
    'web/css/atm.css',
    'web/css/battlepass.css',
    'web/css/redesign.css',
    'web/css/premium-factions.css',
    'web/css/fleeca-bank.css',
    'web/css/premium-menu.css',
    'web/css/premium-auth.css',
    'web/css/premium-properties.css',
    'web/js/*.js',
    'web/vendor/**/*',
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
