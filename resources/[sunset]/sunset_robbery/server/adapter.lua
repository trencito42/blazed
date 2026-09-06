RobberyAdapter = {}

function RobberyAdapter.notify(source, message, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, message, kind or 'info', duration or 5000)
end

function RobberyAdapter.getCharacter(source)
    return exports.sunset_core:GetCharacter(source)
end

function RobberyAdapter.isDead(source)
    if GetResourceState('sunset_death') ~= 'started' then return false end
    local ok, downed = pcall(function()
        return exports.sunset_death:IsPlayerDowned(source)
    end)
    return ok and downed == true
end

function RobberyAdapter.isPoliceRestricted(source)
    local char = RobberyAdapter.getCharacter(source)
    if not char then return true end
    local factionId = select(1, Sunset.GetCharacterFaction(char))
    if factionId and SunsetRobbery.BlockedFactions[factionId] then return true end
    local onDuty = false
    pcall(function()
        onDuty = exports.sunset_factions:IsOnDuty(source) == true
    end)
    return onDuty and factionId and Sunset.FactionTypeMatches(factionId, 'law_enforcement')
end

function RobberyAdapter.policeCount()
    local count = 0
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local onDuty = false
        pcall(function()
            onDuty = exports.sunset_factions:IsOnDuty(src) == true
        end)
        if onDuty then
            local char = RobberyAdapter.getCharacter(src)
            local factionId = char and select(1, Sunset.GetCharacterFaction(char))
            if factionId and Sunset.FactionTypeMatches(factionId, 'law_enforcement') then
                count = count + 1
            end
        end
    end
    return count
end

function RobberyAdapter.hasItem(source, item, count)
    if not item then return true end
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, has = pcall(function()
        return exports.sunset_inventory:HasItem(source, item, count or 1)
    end)
    return ok and has == true
end

function RobberyAdapter.addItem(source, item, count, metadata)
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, added = pcall(function()
        return exports.sunset_inventory:AddItem(source, item, count or 1, nil, metadata)
    end)
    return ok and added == true
end

function RobberyAdapter.removeItem(source, item, count)
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, removed = pcall(function()
        return exports.sunset_inventory:RemoveItem(source, item, count or 1)
    end)
    return ok and removed == true
end

function RobberyAdapter.addCash(source, amount)
    return exports.sunset_core:AddMoney(source, 'cash', amount, 'fence') == true
end

function RobberyAdapter.playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function RobberyAdapter.dist(a, b)
    if not a or not b then return 9999.0 end
    return #(a - b)
end

function RobberyAdapter.getRobPoints(source)
    return exports.sunset_core:GetRobPoints(source)
end

function RobberyAdapter.takeRobPoints(source, amount)
    return exports.sunset_core:AddRobPoints(source, -(tonumber(amount) or 0))
end

function RobberyAdapter.issueWanted(source, reasonCode)
    if GetResourceState('sunset_factions') ~= 'started' then return end
    local ok, wanted = pcall(function()
        return exports.sunset_factions:AddWantedCharge(source, reasonCode or 'robbery')
    end)
    if ok and wanted then
        RobberyAdapter.notify(source, ('You are wanted ★%d for robbery. LSPD was alerted — this stays until they clear you.'):format(wanted.level), 'error', 9000)
    end
end

function RobberyAdapter.isAdmin(source)
    if GetResourceState('sunset_admin') ~= 'started' then return false end
    local ok, level = pcall(function()
        return exports.sunset_admin:GetAdminLevel(source)
    end)
    return ok and (tonumber(level) or 0) >= 1
end
