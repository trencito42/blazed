CreateThread(function()
    Wait(2000)
    exports.sunset_core:RegisterCallback('sunset:getScoreboard', function(source)
        local list = {}
        local maxClients = GetConvarInt('sv_maxclients', 48)

        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local char = exports.sunset_core:GetCharacter(src)
            local adminLevel = 0
            pcall(function()
                adminLevel = exports.sunset_admin:GetAdminLevel(src)
            end)

            local jobLabel = 'Unemployed'
            if char and Sunset.Jobs[char.job] then
                jobLabel = Sunset.Jobs[char.job].label
            end

            table.insert(list, {
                id = src,
                name = exports.sunset_core:GetPlayerDisplayName(src),
                ping = GetPlayerPing(src),
                job = jobLabel,
                money = char and char.cash or 0,
                level = 1,
                admin = adminLevel,
            })
        end

        table.sort(list, function(a, b) return a.id < b.id end)

        return {
            players = list,
            count = #list,
            max = maxClients,
            serverName = Sunset.Config.ServerName,
        }
    end)
end)
