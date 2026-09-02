fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_vehicles'
description 'Vehicle systems — lock, seatbelt, fuel, headlights'
version '1.0.0'

client_scripts {
    'client/main.lua',
}

dependencies { 'sunset_ui' }

exports {
    'GetVehicleState',
}
