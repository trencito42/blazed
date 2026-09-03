fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_vehicles'
description 'Vehicle systems — lock, seatbelt, fuel, garage'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/items.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
    'client/fuel_pump.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies { 'sunset_ui', 'sunset_core', 'sunset_world' }

exports {
    'GetVehicleState',
    'IsPlateInWorld',
    'IsProtectedVehicle',
    'SetFuelLevel',
    'GetFuelLevel',
}
