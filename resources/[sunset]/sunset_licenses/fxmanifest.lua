fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_licenses'
description 'LSSI-style licenses — driving, pilot, boat, weapon tests and enforcement'
version '1.0.0'

shared_scripts {
    '@sunset_core/shared/config.lua',
    '@sunset_core/shared/profile.lua',
    '@sunset_core/shared/factions.lua',
    'shared/config.lua',
}

client_scripts {
    '@sunset_core/client/callbacks.lua',
    'client/main.lua',
    'client/test_hud.lua',
    'client/tests.lua',
    'client/quiz.lua',
    'client/enforcement.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/theory_answers.lua',
    'server/main.lua',
    'server/tests.lua',
    'server/reviews.lua',
    'server/admin.lua',
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
    'RevokeLicenseByCharacterId',
    'GetLicenses',
}

client_exports {
    'HasLicense',
    'IsInLicenseTest',
    'IsInLocalTest',
    'OpenTheoryQuiz',
    'CloseTheoryQuiz',
    'StartPracticalTest',
    'CleanupPracticalTest',
}

server_exports {
    'HasLicense',
    'IsInLicenseTest',
    'GrantLicense',
    'RevokeLicense',
    'RevokeLicenseByCharacterId',
    'GetLicenses',
    'GetLicenseRows',
    'AssessInstructorPromotion',
}
