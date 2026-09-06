RobberyPolice = {}

local function collectLawEnforcement()
    local priority = {}
    local regular = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local char = RobberyAdapter.getCharacter(src)
        local factionId = char and select(1, Sunset.GetCharacterFaction(char))
        local onDuty = false
        pcall(function() onDuty = exports.sunset_factions:IsOnDuty(src) == true end)
        if onDuty and factionId and Sunset.FactionTypeMatches(factionId, 'law_enforcement') then
            local faction = Sunset.Factions[factionId]
            if faction and faction.robberyDispatch then
                priority[#priority + 1] = src
            else
                regular[#regular + 1] = src
            end
        end
    end
    return priority, regular
end

function RobberyPolice.alert(session, stage)
    local loc = session.location
    if not session.policeSnapshot then
        local snapshot = { description = 'Unknown suspect', vehicle = 'No getaway vehicle identified' }
        pcall(function()
            local src = session.source
            local name = exports.sunset_core:GetPlayerDisplayName(src) or ('Player %s'):format(src)
            snapshot.description = ('Suspect %s (%s)'):format(name, src)
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle and vehicle ~= 0 then
                    local plate = tostring(GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'):gsub('^%s*(.-)%s*$', '%1')
                    snapshot.vehicle = ('Getaway vehicle, plate %s'):format(plate)
                end
            end
        end)
        session.policeSnapshot = snapshot
    end
    local title = 'STORE ROBBERY'
    local lines = {
        first = ('%s — %s, %s. Robbery in progress.'):format(title, loc.label, loc.street),
        desc = ('%s — %s at %s.'):format(title, session.policeSnapshot.description, loc.label),
        vehicle = ('%s — %s near %s.'):format(title, session.policeSnapshot.vehicle, loc.street),
    }
    local text = lines[stage] or lines.first

    local function notifyOfficer(src, priority)
        local dispatchText = priority and ('[PRIORITY] %s'):format(text) or text
        RobberyAdapter.notify(src, dispatchText, 'warning', 9000)
        TriggerClientEvent('sunset:chat:message', src, {
            id = 0,
            name = priority and '[ROBBERY DISPATCH]' or '[DISPATCH]',
            message = dispatchText,
            time = os.date('%H:%M'),
            type = 'police_alert',
        })
        if stage == 'first' then
            TriggerClientEvent('sunset:robbery:policePing', src, {
                x = loc.coords.x, y = loc.coords.y, z = loc.coords.z,
                label = loc.label,
                radius = priority and 65.0 or 55.0,
            })
        end
    end

    local priority, regular = collectLawEnforcement()
    for _, src in ipairs(priority) do notifyOfficer(src, true) end
    for _, src in ipairs(regular) do notifyOfficer(src, false) end

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
