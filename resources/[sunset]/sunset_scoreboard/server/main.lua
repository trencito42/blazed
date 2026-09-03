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
            if char then
                local factionId = select(1, Sunset.GetCharacterFaction(char))
                local jobId = select(1, Sunset.GetCharacterJob(char))
                if factionId and Sunset.Factions[factionId] then
                    jobLabel = Sunset.Factions[factionId].label
                elseif Sunset.Jobs[jobId] then
                    jobLabel = Sunset.Jobs[jobId].label
                end
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
