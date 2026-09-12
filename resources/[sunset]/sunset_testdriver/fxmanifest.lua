fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_testdriver'
author 'SunsetMP'
description 'DEV-ONLY: DB integrity checks + callback smoke tests. NOT ensured in production server.cfg.'
version '1.0.0'

dependencies { 'sunset_core', 'oxmysql' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
