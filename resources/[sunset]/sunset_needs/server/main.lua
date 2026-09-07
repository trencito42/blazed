CreateThread(function()
    while true do
        Wait(60000)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                local char = exports.sunset_core:GetCharacter(src)
                if char and not char.is_dead then
                    char.hunger = math.max(0, (char.hunger or 100) - (Sunset.Config.HungerDrain or 0.8))
                    char.thirst = math.max(0, (char.thirst or 100) - (Sunset.Config.ThirstDrain or 1.2))
                    char.stress = math.min(100, (char.stress or 0) + (Sunset.Config.StressDrain or 0.1))

                    TriggerClientEvent('sunset:client:updateCharacter', src, char)
                end
            end
        end
    end
end)

-- Kept for backward compatibility with clients; server heartbeat handles actual decay
RegisterNetEvent('sunset:server:needsTick', function()
    -- No-op: Server authoritative tick loop handles needs updates
end)
