local HelpLines = {
    '^3=== SunsetMP Help ===^7',
    '/help — Show this list',
    'M — Player menu',
    'I — Inventory',
    'T — Chat',
    'TAB — Scoreboard',
    '/e [name] — Play emote (wave, dance, sit, wank, etc.)',
    '/emotes — Emote menu',
    '/garage — Your vehicles',
    '/properties — Property list',
    '/inventory — Open inventory',
    'E — Interact (shops, ATM, properties, garage)',
    'N — Lock vehicle | K — Seatbelt | H — Lights | 2 — Engine',
}

RegisterCommand('help', function()
    for _, line in ipairs(HelpLines) do
        TriggerEvent('chat:addMessage', { color = { 255, 140, 0 }, multiline = true, args = { 'HELP', line } })
    end
end, false)

TriggerEvent('chat:addSuggestion', '/help', 'Show available commands')
