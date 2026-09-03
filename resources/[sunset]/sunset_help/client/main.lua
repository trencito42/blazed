local HelpLines = {
    '=== SunsetMP Help ===',
    '/help — Show this list',
    'M — Player menu | I — Inventory | P — Phone | TAB — Scoreboard',
    '=== JOBS vs FACTIONS (SAMP-style) ===',
    'JOB (civilian) — Job Center: Trucker, Fisherman, Unemployed',
    'FACTION — Join at HQ on map: LSPD, EMS, Taxi, Mechanic, Fire, Gangs',
    'You can have a JOB and a FACTION at the same time.',
    'Example: Job = Trucker, Faction = LSPD',
    '=== Payday & XP ===',
    'Payday every hour at :00 server time — paid to BANK',
    'Faction salary: must be ON DUTY (/duty at HQ)',
    'Civilian job salary: paid even off duty',
    'XP: earned while playing (+50 each payday, +2/min active)',
    'Level up at 5000 XP per level (shown in M menu)',
    '=== Factions ===',
    '[E] at HQ — join faction | again — /duty toggle',
    '/faction — rank, salary, your commands',
    '/leavefaction — leave faction (job stays)',
    '/f [msg] — Faction chat',
    'LSPD: /pd — full police help | /pdgarage — patrol car',
    'Gas stations — drive in, [E] refuel',
    '/v — personal vehicles garage',
    'E — interact everywhere (shops, ATM, HQ, crafting)',
}

local function showHelp()
    for _, line in ipairs(HelpLines) do
        exports.sunset_ui:Send('chatMessage', {
            id = 0,
            name = 'HELP',
            message = line,
            time = '',
        })
    end
end

RegisterCommand('help', function()
    showHelp()
end, false)

TriggerEvent('chat:addSuggestion', '/help', 'Show available commands')
