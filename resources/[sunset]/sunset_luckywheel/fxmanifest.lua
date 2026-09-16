fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_luckywheel'
description '1:1 GTA Online 3D Lucky Wheel for SunsetMP'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client.lua',
}

server_scripts {
    '@sunset_core/shared/config.lua',
    'server.lua',
}

files {
    'audio/dlcvinewood_amp.dat10',
    'audio/dlcvinewood_amp.dat10.nametable',
    'audio/dlcvinewood_amp.dat10.rel',
    'audio/dlcvinewood_game.dat151',
    'audio/dlcvinewood_game.dat151.nametable',
    'audio/dlcvinewood_game.dat151.rel',
    'audio/dlcvinewood_mix.dat15',
    'audio/dlcvinewood_mix.dat15.nametable',
    'audio/dlcvinewood_mix.dat15.rel',
    'audio/dlcvinewood_sounds.dat54',
    'audio/dlcvinewood_sounds.dat54.nametable',
    'audio/dlcvinewood_sounds.dat54.rel',
    'audio/dlcvinewood_speech.dat4',
    'audio/dlcvinewood_speech.dat4.nametable',
    'audio/dlcvinewood_speech.dat4.rel',
    'audio/sfx/dlc_vinewood/*.awc',
}

data_file 'AUDIO_GAMEDATA' 'audio/dlcvinewood_game.dat'
data_file 'AUDIO_SOUNDDATA' 'audio/dlcvinewood_sounds.dat'
data_file 'AUDIO_DYNAMIXDATA' 'audio/dlcvinewood_mix.dat'
data_file 'AUDIO_SYNTHDATA' 'audio/dlcVinewood_amp.dat'
data_file 'AUDIO_SPEECHDATA' 'audio/dlcvinewood_speech.dat'
data_file 'AUDIO_WAVEPACK' 'audio/sfx/dlc_vinewood'

dependencies {
    'sunset_core',
    'sunset_inventory',
    'sunset_ui',
}
