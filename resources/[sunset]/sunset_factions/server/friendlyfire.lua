local function syncCombatState(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then
        Player(source).state:set('sunsetFaction', nil, true)
        Player(source).state:set('sunsetOnDuty', false, true)
        return
    end
    local factionId = select(1, Sunset.GetCharacterFaction(char))
    Player(source).state:set('sunsetFaction', factionId, true)
    Player(source).state:set('sunsetOnDuty', OnDuty[source] == true, true)
end

AddEventHandler('sunset:server:characterSelected', function(source)
    syncCombatState(source)
end)

AddEventHandler('sunset:server:jobChanged', function(source)
    syncCombatState(source)
end)

AddEventHandler('playerDropped', function()
    -- state bags clear automatically on disconnect
end)

function SyncPlayerCombatState(source)
    syncCombatState(source)
end
