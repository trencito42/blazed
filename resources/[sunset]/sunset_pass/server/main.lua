local function notify(source, message, kind)
    TriggerClientEvent('sunset:client:notify', source, message, kind or 'info', 5000)
end

local CharacterLocks = {}

local function withCharacterLock(characterId, operation)
    local key = tostring(characterId)
    if CharacterLocks[key] then
        return nil, 'Your Sunset Pass is already processing another action. Try again in a moment.'
    end

    CharacterLocks[key] = true
    local result = table.pack(xpcall(operation, debug.traceback))
    CharacterLocks[key] = nil

    if not result[1] then
        print(('[sunset_pass] operation failed for character %s: %s'):format(key, tostring(result[2])))
        return nil, 'Sunset Pass could not process the action. No second request was accepted.'
    end
    return table.unpack(result, 2, result.n)
end

local function getCharacter(source)
    return exports.sunset_core:GetCharacter(source)
end

local function getPlayer(source)
    return exports.sunset_core:GetPlayer(source)
end

local function maxTier()
    return #(SunsetPass.Tiers or {})
end

local function tierFromXp(xp)
    local per = SunsetPass.XpPerTier or 500
    return math.min(maxTier(), math.floor((tonumber(xp) or 0) / per) + 1)
end

local function claimKey(level, track)
    return ('%d_%s'):format(level, track)
end

local function decodeJson(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    return ok and type(decoded) == 'table' and decoded or {}
end

local function loadRow(characterId)
    local row = MySQL.single.await([[
        SELECT xp, premium, claimed, mission_progress
        FROM character_pass_progress
        WHERE character_id = ? AND season_id = ?
        LIMIT 1
    ]], { characterId, SunsetPass.SeasonId })
    if row then return row end

    MySQL.insert.await([[
        INSERT INTO character_pass_progress (character_id, season_id, xp, premium, claimed, mission_progress)
        VALUES (?, ?, 0, 0, '{}', '{}')
    ]], { characterId, SunsetPass.SeasonId })

    return {
        xp = 0,
        premium = 0,
        claimed = '{}',
        mission_progress = '{}',
    }
end

local function saveRow(characterId, xp, premium, claimed, missionProgress)
    MySQL.update.await([[
        UPDATE character_pass_progress
        SET xp = ?, premium = ?, claimed = ?, mission_progress = ?
        WHERE character_id = ? AND season_id = ?
    ]], {
        xp,
        premium and 1 or 0,
        json.encode(claimed or {}),
        json.encode(missionProgress or {}),
        characterId,
        SunsetPass.SeasonId,
    })
end

local function missionById(id)
    for _, mission in ipairs(SunsetPass.Missions or {}) do
        if mission.id == id then return mission end
    end
    return nil
end

local function tierReward(level, track)
    for _, tier in ipairs(SunsetPass.Tiers or {}) do
        if tier.level == level then
            return track == 'premium' and tier.premium or tier.free
        end
    end
    return nil
end

local function grantReward(source, reward)
    if not reward or not reward.type then return false, 'Invalid reward.' end

    if reward.type == 'cash' or reward.type == 'bank' then
        local ok = exports.sunset_core:AddMoney(source, reward.type, reward.amount or 0, 'sunset_pass')
        if not ok then return false, 'Could not add money.' end
        return true
    end

    if reward.type == 'premium_points' then
        local player = getPlayer(source)
        if not player then return false, 'Account data unavailable.' end
        local amount = math.floor(tonumber(reward.amount) or 0)
        if amount <= 0 then return false, 'Invalid coin amount.' end
        local nextValue = (tonumber(player.premium_points) or 0) + amount
        local ok, err = Sunset.SetPersistentStat(source, 'account', 'premium_points', nextValue)
        if not ok then return false, err or 'Could not add Sunset Coins.' end
        return true
    end

    if reward.type == 'item' then
        if GetResourceState('sunset_inventory') ~= 'started' then
            return false, 'Inventory is unavailable.'
        end
        local added = exports.sunset_inventory:AddItem(source, reward.item, reward.count or 1)
        if not added then return false, 'Inventory full or item invalid.' end
        return true
    end

    return false, 'Unsupported reward type.'
end

function AddMissionProgress(source, missionId, amount)
    local char = getCharacter(source)
    missionId = tostring(missionId or '')
    amount = math.floor(tonumber(amount) or 0)
    if not char or missionId == '' or amount <= 0 then return false end

    local mission = missionById(missionId)
    if not mission then return false end

    return withCharacterLock(char.id, function()
        local row = loadRow(char.id)
        local missionProgress = decodeJson(row.mission_progress)
        local entry = missionProgress[missionId] or { progress = 0, completed = false }
        if entry.completed then return false end

        entry.progress = math.min(mission.goal, (tonumber(entry.progress) or 0) + amount)
        local xp = tonumber(row.xp) or 0
        if entry.progress >= mission.goal then
            entry.completed = true
            xp = xp + (mission.xp or 0)
        end
        missionProgress[missionId] = entry

        saveRow(char.id, xp, tonumber(row.premium) == 1, decodeJson(row.claimed), missionProgress)
        TriggerClientEvent('sunset:pass:refresh', source)
        return true
    end)
end

exports('AddMissionProgress', AddMissionProgress)

AddEventHandler('sunset:pass:addMission', function(source, missionId, amount)
    AddMissionProgress(source, missionId, amount)
end)

local function buildPayload(source, row)
    local char = getCharacter(source)
    local player = getPlayer(source)
    if not char then return nil end

    local xp = tonumber(row.xp) or 0
    local premium = tonumber(row.premium) == 1
    local claimed = decodeJson(row.claimed)
    local missionProgress = decodeJson(row.mission_progress)
    local currentTier = tierFromXp(xp)
    local per = SunsetPass.XpPerTier or 500
    local tierXp = xp % per
    local tiers = {}

    for _, tier in ipairs(SunsetPass.Tiers or {}) do
        local level = tier.level
        local unlocked = level <= currentTier
        local freeKey = claimKey(level, 'free')
        local premiumKey = claimKey(level, 'premium')

        local function mapReward(reward, track)
            if not reward then return nil end
            return {
                level = level,
                track = track,
                type = reward.type,
                label = reward.label,
                icon = reward.icon,
                amount = reward.amount,
                item = reward.item,
                count = reward.count,
                claimed = claimed[track == 'premium' and premiumKey or freeKey] == true,
                locked = track == 'premium' and not premium,
                canClaim = unlocked
                    and not (claimed[track == 'premium' and premiumKey or freeKey] == true)
                    and (track ~= 'premium' or premium)
                    and reward ~= nil,
            }
        end

        tiers[#tiers + 1] = {
            level = level,
            unlocked = unlocked,
            current = level == currentTier,
            free = mapReward(tier.free, 'free'),
            premium = mapReward(tier.premium, 'premium'),
        }
    end

    local missions = {}
    for _, mission in ipairs(SunsetPass.Missions or {}) do
        local entry = missionProgress[mission.id] or { progress = 0, completed = false }
        local progress = tonumber(entry.progress) or 0
        missions[#missions + 1] = {
            id = mission.id,
            title = mission.title,
            description = mission.description,
            goal = mission.goal,
            xp = mission.xp,
            icon = mission.icon,
            progress = progress,
            completed = entry.completed == true,
        }
    end

    return {
        seasonId = SunsetPass.SeasonId,
        seasonLabel = SunsetPass.SeasonLabel,
        xp = xp,
        tier = currentTier,
        maxTier = maxTier(),
        tierXp = tierXp,
        tierGoal = per,
        premium = premium,
        premiumCost = SunsetPass.PremiumCost or 250,
        accountCoins = player and (tonumber(player.premium_points) or 0) or 0,
        tiers = tiers,
        missions = missions,
    }
end

exports.sunset_core:RegisterCallback('sunset:pass:getData', function(source)
    local char = getCharacter(source)
    if not char then return nil, 'Character not loaded.' end
    local row = loadRow(char.id)
    return buildPayload(source, row)
end)

exports.sunset_core:RegisterCallback('sunset:pass:claim', function(source, data)
    local char = getCharacter(source)
    if not char then return nil, 'Character not loaded.' end

    local level = tonumber(data and data.level)
    local track = data and data.track
    if not level or level ~= math.floor(level) or level < 1 or level > maxTier()
        or (track ~= 'free' and track ~= 'premium') then
        return nil, 'Invalid claim request.'
    end

    return withCharacterLock(char.id, function()
        local row = loadRow(char.id)
        local xp = tonumber(row.xp) or 0
        local premium = tonumber(row.premium) == 1
        local claimed = decodeJson(row.claimed)
        local key = claimKey(level, track)

        if claimed[key] then return nil, 'Reward already claimed.' end
        if level > tierFromXp(xp) then return nil, 'Tier not unlocked yet.' end
        if track == 'premium' and not premium then return nil, 'Premium pass required.' end

        local reward = tierReward(level, track)
        if not reward then return nil, 'No reward on this tier.' end

        local ok, err = grantReward(source, reward)
        if not ok then return nil, err or 'Could not grant reward.' end

        claimed[key] = true
        saveRow(char.id, xp, premium, claimed, decodeJson(row.mission_progress))
        notify(source, ('Claimed: %s'):format(reward.label or 'reward'), 'success')
        return buildPayload(source, loadRow(char.id))
    end)
end)

exports.sunset_core:RegisterCallback('sunset:pass:buyPremium', function(source)
    local char = getCharacter(source)
    local player = getPlayer(source)
    if not char or not player then return nil, 'Character not loaded.' end

    return withCharacterLock(char.id, function()
        local row = loadRow(char.id)
        if tonumber(row.premium) == 1 then return nil, 'Premium pass already unlocked.' end

        -- Refresh the account inside the lock; a stale balance must never overwrite
        -- coins changed by another server action.
        player = getPlayer(source)
        if not player then return nil, 'Account data unavailable.' end
        local cost = math.floor(tonumber(SunsetPass.PremiumCost) or 0)
        local balance = tonumber(player.premium_points) or 0
        if cost <= 0 then return nil, 'Premium pass is not for sale yet.' end
        if balance < cost then
            return nil, ('You need %d Sunset Coins (you have %d).'):format(cost, balance)
        end

        local ok, err = Sunset.SetPersistentStat(source, 'account', 'premium_points', balance - cost)
        if not ok then return nil, err or 'Payment failed.' end

        saveRow(char.id, tonumber(row.xp) or 0, true, decodeJson(row.claimed), decodeJson(row.mission_progress))
        notify(source, 'Premium pass unlocked for this season.', 'success')
        return buildPayload(source, loadRow(char.id))
    end)
end)

-- Payday mission hook (safe, isolated from robbery edits).
-- Progress is applied from sunset_economy after each payday.
