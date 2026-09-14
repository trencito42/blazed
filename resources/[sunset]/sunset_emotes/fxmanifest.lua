fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_emotes'
description 'Player animations and emotes'
version '1.0.0'

dependencies {  }

client_scripts { 'client/main.lua' }

client_exports { 'PlayEmote', 'StopEmote', 'IsPlaying', 'GetEmoteWheelList' }
