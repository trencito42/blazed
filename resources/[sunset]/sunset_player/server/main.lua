CreateThread(function()
    while true do
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local char = exports.sunset_core:GetCharacter(src)
            if char then
                exports.sunset_core:SaveCharacter(src)
            end
        end
        Wait((Sunset.Config.SaveInterval or 60) * 1000)
    end
end)
