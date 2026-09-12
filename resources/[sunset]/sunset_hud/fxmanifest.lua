fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_hud'
author 'SunsetMP'
description 'In-game HUD — health, money, street name'
version '1.0.2'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/utils.lua',
    '@sunset_core/shared/jobs_civilian.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/faction_core.lua',
    '@sunset_core/shared/factions.lua',
}

client_scripts {
    'client/world.lua',
    'client/main.lua',
    'client/voice.lua',
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
    'CycleVoiceProximity',
    'SetVoiceProximity',
    'GetVoiceProximity',
    'GetVoiceHudData',
}

-- [AUDIT 3-9.1] pma-voice is NOT shipped in resources/ (Docker installs it at build
-- time; local Windows installs do not). A hard dependency made sunset_hud fail to
-- start locally, killing the entire HUD. client/voice.lua already degrades
-- gracefully via GetResourceState('pma-voice') checks, so the dependency is dropped.
dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_vehicles',
    'sunset_admin',
}
