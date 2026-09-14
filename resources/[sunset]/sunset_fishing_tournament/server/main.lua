-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Fishing Tournament (server/main.lua)
--  Tracks fish caught during the fishing tournament event.
--  Hooks into sunset_events' fishing_tournament event.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetFishingTournament.Config
local Scores = {} -- [charId] = { name, count }
local TournamentActive = false

local function notify(source, msg, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', duration or 5000)
end

local function getCharId(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.id) or nil
end

-- Listen for fishing tournament start/end from sunset_events (server-side)
AddEventHandler('sunset:events:serverStart', function(data)
    if data and data.type == 'fishing_tournament' then
        TournamentActive = true
        Scores = {}
    end
end)

AddEventHandler('sunset:events:serverEnd', function(data)
    if data and data.type == 'fishing_tournament' then
        TournamentActive = false
        endTournament()
    end
end)

-- Track fish caught (hooked from sunset_jobs via server event)
AddEventHandler('sunset:fishing:caught', function(source)
    if not TournamentActive then return end

    local charId = getCharId(source)
    if not charId then return end

    local name = exports.sunset_core:GetPlayerDisplayName(source) or 'Unknown'
    Scores[charId] = Scores[charId] or { name = name, count = 0 }
    Scores[charId].count = Scores[charId].count + 1
end)

function endTournament()
    -- Sort by count
    local ranked = {}
    for charId, data in pairs(Scores) do
        if data.count >= (Cfg.minFish or 3) then
            ranked[#ranked + 1] = { charId = charId, name = data.name, count = data.count }
        end
    end
    table.sort(ranked, function(a, b) return a.count > b.count end)

    -- Reward top 3
    for i = 1, math.min(3, #ranked) do
        local entry = ranked[i]
        local reward = Cfg.rewards[i]
        if reward then
            -- Find online source for this character
            for _, id in ipairs(GetPlayers()) do
                local src = tonumber(id)
                if getCharId(src) == entry.charId then
                    exports.sunset_core:AddMoney(src, 'cash', reward.cash, 'fishing_tournament')
                    pcall(function()
                        exports.sunset_core:AddXP(src, reward.xp)
                    end)
                    notify(src, ('🎣 Fishing Tournament — %s! %d fish. Reward: $%s + %d XP.'):format(
                        reward.label, entry.count, reward.cash, reward.xp), 'success', 12000)
                end
            end
        end
    end

    -- Broadcast results
    if #ranked > 0 then
        local results = {}
        for i = 1, math.min(3, #ranked) do
            results[#results + 1] = ('#%d %s (%d fish)'):format(i, ranked[i].name, ranked[i].count)
        end
        for _, id in ipairs(GetPlayers()) do
            TriggerClientEvent('sunset:client:notify', tonumber(id),
                ('🎣 Fishing Tournament results: %s'):format(table.concat(results, ' · ')), 'info', 12000)
        end
    end

    Scores = {}
end

-- Status callback
exports.sunset_core:RegisterCallback('sunset:fishingTournament:status', function(source)
    local charId = getCharId(source)
    local myScore = charId and Scores[charId] and Scores[charId].count or 0

    local ranked = {}
    for cid, data in pairs(Scores) do
        ranked[#ranked + 1] = { name = data.name, count = data.count }
    end
    table.sort(ranked, function(a, b) return a.count > b.count end)

    return {
        active = TournamentActive,
        myScore = myScore,
        leaderboard = ranked,
    }
end)

print('^2[sunset_fishing_tournament]^7 Fishing tournament online')
