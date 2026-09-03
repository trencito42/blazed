local LastNeedsTick = {}

RegisterNetEvent('sunset:server:needsTick', function()
    local source = source
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end

    local now = os.time()
    local last = LastNeedsTick[source] or 0
    -- The normal client interval is 60 seconds. Reject replay/spam while allowing
    -- a little scheduling jitter.
    if now - last < 50 then return end
    LastNeedsTick[source] = now

    char.hunger = math.max(0, (char.hunger or 100) - (Sunset.Config.HungerDrain or 0.8))
    char.thirst = math.max(0, (char.thirst or 100) - (Sunset.Config.ThirstDrain or 1.2))
    char.stress = math.min(100, (char.stress or 0) + (Sunset.Config.StressDrain or 0.1))

    TriggerClientEvent('sunset:client:updateCharacter', source, char)
end)

AddEventHandler('playerDropped', function()
    LastNeedsTick[source] = nil
end)
