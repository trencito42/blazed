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
            local factionId, factionLabel = nil, nil
            if char then
                factionId, _ = Sunset.GetCharacterFaction(char)
                local jobId, _ = Sunset.GetCharacterJob(char)
                if factionId and Sunset.Factions[factionId] then
                    factionLabel = Sunset.Factions[factionId].label
                    jobLabel = factionLabel
                elseif Sunset.Jobs[jobId] then
                    jobLabel = Sunset.Jobs[jobId].label
                end
            end

            local st = Player(src).state
            local clanTag = st.clanTag
            local clanTagColor = st.clanTagColor
            local clanTagStyle = st.clanTagStyle
            if (not clanTag or clanTag == '') and GetResourceState('sunset_clans') == 'started' then
                local okMeta, meta = pcall(function()
                    return exports.sunset_clans:GetClanChatMeta(src)
                end)
                if okMeta and type(meta) == 'table' then
                    clanTag = meta.clanTag
                    clanTagColor = meta.clanTagColor
                    clanTagStyle = meta.clanTagStyle
                end
            end

            table.insert(list, {
                id = src,
                name = exports.sunset_core:GetPlayerBaseName(src),
                ping = GetPlayerPing(src),
                job = jobLabel,
                factionId = factionId,
                factionLabel = factionLabel,
                clanTag = clanTag,
                clanTagColor = clanTagColor,
                clanTagStyle = clanTagStyle,
                money = char and char.cash or 0,
                level = char and (tonumber(char.level) or 1) or 1,
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
