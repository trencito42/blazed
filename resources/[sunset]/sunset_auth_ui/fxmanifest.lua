fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sunset_auth_ui'
description 'Minimal auth NUI — login/register/saved accounts only'
version '1.0.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/auth.css',
    'web/auth.js',
    'web/background.webp',
}

client_scripts {
    'client/main.lua',
}

-- NOTE: no dependency on sunset_auth (that resource calls OUR exports, and a
-- mutual dependency would be a hard cycle). Linkage is runtime-only:
-- sunset_auth pushes state via exports.sunset_auth_ui:Send/Show, and this
-- resource forwards NUI callbacks as 'sunset:nui:<name>' client events.
dependencies { 'sunset_core' }
