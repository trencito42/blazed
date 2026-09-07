local function pushFactionMotd(source, char)
    if GetResourceState('sunset_factions') ~= 'started' then return end
    local ok, payload = pcall(function()
        return exports.sunset_factions:GetConnectMotd(source, char)
    end)
    if ok and type(payload) == 'table' and payload.message and payload.message ~= '' then
        TriggerClientEvent('sunset:chat:message', source, payload)
    end
end

local function pushClanMotd(source, char)
    if GetResourceState('sunset_clans') ~= 'started' then return end
    local ok, payload = pcall(function()
        return exports.sunset_clans:GetConnectMotd(source, char)
    end)
    if ok and type(payload) == 'table' and payload.message and payload.message ~= '' then
        TriggerClientEvent('sunset:chat:message', source, payload)
    end
end

RegisterNetEvent('sunset:server:characterSpawned', function(characterId)
    local src = source
    local char = exports.sunset_core:GetCharacter(src)
    if not char or tonumber(characterId) ~= tonumber(char.id) then return end

    SetTimeout(1800, function()
        if not GetPlayerName(src) then return end
        pushFactionMotd(src, char)
        SetTimeout(500, function()
            if not GetPlayerName(src) then return end
            pushClanMotd(src, char)
        end)
    end)
end)
