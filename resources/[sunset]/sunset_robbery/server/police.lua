RobberyPolice = {}

local function eachPoliceMember(fn)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local char = RobberyAdapter.getCharacter(src)
        local factionId = char and select(1, Sunset.GetCharacterFaction(char))
        local onDuty = false
        pcall(function() onDuty = exports.sunset_factions:IsOnDuty(src) == true end)
        if onDuty and factionId and Sunset.FactionTypeMatches(factionId, 'law_enforcement') then
            fn(src)
        end
    end
end

function RobberyPolice.alert(session, stage)
    local loc = session.location
    local title = 'STORE ROBBERY'
    local lines = {
        first = ('%s — %s, %s. Robbery in progress.'):format(title, loc.label, loc.street),
        desc = ('%s — suspect description available at %s.'):format(title, loc.label),
        vehicle = ('%s — possible getaway vehicle near %s.'):format(title, loc.street),
    }
    local text = lines[stage] or lines.first
    eachPoliceMember(function(src)
        RobberyAdapter.notify(src, text, 'warning', 9000)
        TriggerClientEvent('sunset:chat:message', src, {
            id = 0,
            name = '[DISPATCH]',
            message = text,
            time = os.date('%H:%M'),
            type = 'police_alert',
        })
        if stage == 'first' then
            TriggerClientEvent('sunset:robbery:policePing', src, {
                x = loc.coords.x, y = loc.coords.y, z = loc.coords.z,
                label = loc.label,
                radius = 55.0,
            })
        end
    end)
    if stage == 'first' and GetResourceState('sunset_dispatch') == 'started' then
        pcall(function()
            exports.sunset_dispatch:CreateServiceCall(session.source, 'police_backup', loc.coords, {
                system = true,
                robbery = true,
                locationId = loc.id,
            }, text)
        end)
    end
end
