Sunset = Sunset or {}

--- Static help catalog. Runtime filtering happens in sunset_help server.
Sunset.HelpAdminDescriptions = {
    kick = 'Kick a player from the server',
    ban = 'Permanently ban a player (player ID required)',
    unban = 'Remove a ban by player ID or license:xxx',
    tp = 'Teleport to a player or x y z coordinates',
    bring = 'Bring a player to your location',
    ['goto'] = 'Teleport to a player',
    car = 'Spawn a vehicle by model name',
    dv = 'Delete your current vehicle',
    heal = 'Heal yourself or another player',
    revive = 'Revive a downed player',
    noclip = 'Toggle noclip mode',
    god = 'Toggle god mode',
    announce = 'Send a server-wide announcement',
    setadmin = 'Set admin level for an account',
    coords = 'Copy your coordinates to clipboard',
    hudexport = 'Export HUD layout JSON',
}

Sunset.HelpGeneralEntries = {
    { cmd = '/help', desc = 'Open this command guide' },
    { cmd = '/me [text]', desc = 'Roleplay action visible to nearby players' },
    { cmd = '/do [text]', desc = 'Describe the scene or environment' },
    { cmd = 'M', desc = 'Player menu — stats, vehicle, job, settings' },
    { cmd = 'I', desc = 'Inventory' },
    { cmd = 'P', desc = 'Phone' },
    { cmd = 'TAB', desc = 'Hold for scoreboard' },
    { cmd = 'E', desc = 'Interact — shops, ATMs, faction HQ, crafting' },
    { cmd = '/inventory', desc = 'Open inventory' },
    { cmd = '/phone', desc = 'Toggle phone' },
    { cmd = '/documents', desc = 'View documents panel' },
    { cmd = '/id', desc = 'Show ID card' },
    { cmd = '/licenses', desc = 'Show licenses' },
    { cmd = '/v', desc = 'Personal vehicle garage' },
    { cmd = '/garage', desc = 'Garage panel' },
    { cmd = '/properties', desc = 'Browse properties' },
    { cmd = '/sethome [id]', desc = 'Set home at owned property' },
    { cmd = '/emotes', desc = 'Open emotes panel' },
    { cmd = '/e [name]', desc = 'Play an emote' },
    { cmd = '/stopemote', desc = 'Stop current emote' },
    { cmd = '/handsup', desc = 'Raise hands' },
    { cmd = '/jobs', desc = 'Open jobs panel' },
    { cmd = '/work [cancel]', desc = 'Start civilian job shift or cancel current shift' },
    { cmd = '/skills', desc = 'View job skill levels' },
    { cmd = '/jobhelp', desc = 'Help text for your civilian job' },
    { cmd = '/quitjob', desc = 'Quit civilian job at Job Center' },
    { cmd = '/faction', desc = 'Faction rank, salary, and your commands' },
    { cmd = '/leavefaction', desc = 'Leave your faction (job stays)' },
    { cmd = '/quitgroup', desc = 'Alias for /leavefaction (civilian job stays)' },
    { cmd = '/duty', desc = 'Toggle on/off duty at faction HQ' },
    { cmd = '/f [message]', desc = 'Faction chat' },
    { cmd = '/service [type] [msg]', desc = 'Request taxi, medic, fire, or mechanic' },
    { cmd = '/relook', desc = 'Re-open character appearance editor' },
    { cmd = '/respawn', desc = 'Respawn when dead (if allowed)' },
    { cmd = '/hudedit', desc = 'Move HUD panels' },
    { cmd = '/hudreset', desc = 'Reset HUD layout to default' },
}

Sunset.HelpDispatchEntries = {
    { cmd = '/calls', desc = 'Open service calls panel (on duty)' },
    { cmd = '/servicecalls', desc = 'List open calls for your duty role' },
    { cmd = '/accept [type] [id]', desc = 'Accept a service call' },
    { cmd = '/cancel [type] [id]', desc = 'Cancel a service call' },
}

Sunset.HelpFireEntries = {
    { cmd = '/firecalls', desc = 'List and route to active fire incidents' },
    { cmd = '/firestart', desc = 'Request an LSFD incident when none is active' },
}
