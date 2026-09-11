fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_tuning'
description 'ECU tuning — exhaust, dyno, drift, anti-lag (Sunset style)'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts {
    '@sunset_core/shared/config.lua',
    'shared/config.lua',
    'shared/vehicle_profiles.lua',
    'shared/profile_resolver.lua',
    'shared/tune_calculator.lua',
    'shared/tune_validator.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/baseline.lua',
    'client/apply.lua',
    'client/exhaust_ptfx.lua',
    'client/cosmetics.lua',
    'client/effects.lua',
    'client/dyno.lua',
    'client/bootstrap.lua',
    'client/lsc_menu.lua',
    'client/main.lua',
    'client/diagnostics.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_vehicles',
    'sunset_factions',
    'sunset_admin',
}

exports {
    'ApplyTune',
    'CaptureModelBaseline',
    'GetTuneForPlate',
    'ExportTuneForStore',
    'OpenTuningPanel',
    'OpenLsCustomsMenu',
    'FormatVehicleInfo',
    'GetVehicleTuningInfo',
    'GetVehicleCapabilities',
}
