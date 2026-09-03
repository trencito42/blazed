local HelpLines = {
    '=== SunsetMP Help ===',
    '/help or /comanda — Show this list',
    'M — Player menu (ESC to close)',
    'I — Inventory',
    'T — Chat',
    'TAB — Scoreboard',
    '/e [name] — Play emote (wave, dance, sit, wank, etc.)',
    '/e cancel — Stop current emote',
    '/emotes — Emote menu',
    'X — Stop emote',
    'P — Phone',
    '/documents — ID card | /licenses — Licenses',
    '/setjob [id|username] [job] [grade] — Admin set job',
    '=== Factions (5 legal + 2 mafii) ===',
    'LSPD, EMS, Taxi, LS Customs, LS Fire — blip pe hartă, [E] la HQ',
    'Sunset Cartel, Night Syndicate — HQ ascuns (fără blip public)',
    '[E] la HQ — join faction | din nou — /duty ON/OFF',
    '/duty — Toggle shift | /faction — Info job',
    '/leavefaction — Părăsește facțiunea',
    '/f [mesaj] — Chat facțiune',
    '/finvite [id] — Recrutează (rank cu permisiune)',
    'PD: /fine [id] [sumă] [motiv] | /cuff [id]',
    'EMS/LSFD: /heal [id] | /revive [id]',
    'Mechanic: /repairveh [id]',
    'Taxi: /fare [id] [sumă]',
    '=== Crafting ===',
    'Workbench public (blip) — bandaje, lockpick, repair kit',
    'LSPD Armory, Cartel Lab, Syndicate Workshop — la HQ',
    'Job Center, shops, ATMs, garages — blips on map, [E] at marker',
    '/garage — Your vehicles',
    '/properties — Property list',
    '/inventory — Open inventory',
    'E — Interact (shops, ATM, properties, garage, HQ, crafting)',
    'N — Lock vehicle | K — Seatbelt | H — Lights | 2 — Engine',
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

RegisterCommand('comanda', function()
    showHelp()
end, false)

TriggerEvent('chat:addSuggestion', '/help', 'Show available commands')
TriggerEvent('chat:addSuggestion', '/comanda', 'Lista comenzi (help)')
