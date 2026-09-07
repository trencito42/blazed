fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_licenses'
description 'LSSI-style licenses — driving, pilot, boat, weapon tests and enforcement'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    'shared/config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
    'client/enforcement.lua',
    'client/tests.lua',
    'client/quiz.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/tests.lua',
    'server/admin.lua',
}

ui_page 'web/quiz.html'

files {
    'web/quiz.html',
    'web/quiz.js',
    'web/quiz.css',
}

dependencies {
    'sunset_core',
    'sunset_ui',
    'sunset_factions',
}

exports {
    'HasLicense',
    'IsInLicenseTest',
    'GrantLicense',
    'RevokeLicense',
    'GetLicenses',
}

client_exports {
    'HasLicense',
    'IsInLicenseTest',
    'IsInLocalTest',
    'OpenTheoryQuiz',
    'StartPracticalTest',
    'CleanupPracticalTest',
}

server_exports {
    'HasLicense',
    'IsInLicenseTest',
    'GrantLicense',
    'RevokeLicense',
    'GetLicenses',
    'GetLicenseRows',
}
