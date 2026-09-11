local SellLocks = {}

-- Point-in-polygon (ray casting) pentru zona de pescuit
local function inFishZone(source, cfg)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local zone = cfg and cfg.fishZone
    if not zone or #zone < 3 then
        -- fallback la radius daca nu exista polygon
        local spot = cfg and cfg.spots and cfg.spots[1]
        if not spot then return false end
        return SunsetJobs_ValidateCoordsCylinder(source, spot.coords, cfg.catchRadius or 50.0, cfg.catchZTolerance or 8.0)
    end
    local minZ = cfg.fishZoneMinZ or -5.0
    local maxZ = cfg.fishZoneMaxZ or 12.0
    if pos.z < minZ or pos.z > maxZ then return false end
    local inside = false
    local j = #zone
    for i = 1, #zone do
        local xi, yi = zone[i].x, zone[i].y
        local xj, yj = zone[j].x, zone[j].y
        if ((yi > pos.y) ~= (yj > pos.y)) and
           (pos.x < (xj - xi) * (pos.y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

-- ── Rod / Bait tables ─────────────────────────────────────────
-- rarityLevel = offset aplicat nivelului la selectia raritati pestelui
--   Mk1=+0, Mk2=+1, Mk3=+1, Mk4=+2, Mk5=+2 (cap la 5)
--   => un jucator nivel 1 cu Mk5 prinde pesti ca la nivelul 3
local ROD_TIERS = {
    { item = 'fishing_rod_5', valueMult = 1.75, delayReduction = 2000, windowBonus = 600, rarityLevel = 2 },
    { item = 'fishing_rod_4', valueMult = 1.50, delayReduction = 1500, windowBonus = 400, rarityLevel = 2 },
    { item = 'fishing_rod_3', valueMult = 1.30, delayReduction = 1000, windowBonus = 200, rarityLevel = 1 },
    { item = 'fishing_rod_2', valueMult = 1.15, delayReduction = 500,  windowBonus = 0,   rarityLevel = 1 },
    { item = 'fishing_rod_1', valueMult = 1.05, delayReduction = 0,    windowBonus = 0,   rarityLevel = 0 },
}

-- Bonus catch% per nivel de skill (nivel 1=+0%, nivel 5=+4%)
-- Recompenseaza grinding-ul cu mai putine rate, nu cu over-powered chances
local LEVEL_CATCH_BONUS = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4 }

-- baitTier: 0 = no bait, 1 = worm, 2 = lure, 3 = premium
local BAIT_TIERS = {
    { item = 'bait_premium', tier = 3 },
    { item = 'bait_lure',    tier = 2 },
    { item = 'bait_worm',    tier = 1 },
}

-- Sansa de prindere (%) pe tier momeala
local CATCH_CHANCE = { [0] = 35, [1] = 60, [2] = 75, [3] = 90 }

-- Peste + greutate aleatoare (kg) + pret/kg + tier minim momeala + greutati pe nivel (1-5)
-- minKg/maxKg = intervalul de greutate al pestelui (1 zecimala)
-- pricePerKg  = pretul de baza per kg (inainte de multiplicatorul unditei)
-- w[level]    = greutate selectie; 0 inseamna imposibil la nivelul respectiv
local ALL_FISH = {
    { item = 'fish_common',    minKg =  0.5, maxKg =  1.5, pricePerKg =  57, minBait = 0, w = { 90, 70, 55, 40, 25 } },
    { item = 'fish_uncommon',  minKg =  1.5, maxKg =  3.5, pricePerKg =  45, minBait = 1, w = {  8, 25, 28, 28, 25 } },
    { item = 'fish_rare',      minKg =  3.5, maxKg =  6.0, pricePerKg =  48, minBait = 2, w = {  0,  5, 15, 22, 25 } },
    { item = 'fish_epic',      minKg =  5.0, maxKg =  8.5, pricePerKg =  64, minBait = 3, w = {  0,  0,  2,  8, 15 } },
    { item = 'fish_legendary', minKg =  8.0, maxKg = 15.5, pricePerKg =  80, minBait = 3, w = {  0,  0,  0,  2, 10 } },
}

-- Toate itemele de peste (pentru inventar summary)
local ALL_FISH_ITEMS = { 'fresh_fish', 'fish_common', 'fish_uncommon', 'fish_rare', 'fish_epic', 'fish_legendary' }

-- Valori fixe pentru vanzare la Fish Buyer (media range-ului per tip)
local FISH_BASE_VALUES = {
    fresh_fish    = 45,
    fish_common   = 60,
    fish_uncommon = 120,
    fish_rare     = 225,
    fish_epic     = 435,
    fish_legendary = 925,
}

local function getEquippedRod(source)
    for _, rod in ipairs(ROD_TIERS) do
        if (exports.sunset_inventory:CountItem(source, rod.item) or 0) > 0 then
            return rod
        end
    end
    return { valueMult = 1.0, delayReduction = 0, windowBonus = 0, rarityLevel = 0 }
end

local function consumeBestBait(source)
    for _, bait in ipairs(BAIT_TIERS) do
        if (exports.sunset_inventory:CountItem(source, bait.item) or 0) > 0 then
            exports.sunset_inventory:RemoveItem(source, bait.item, 1)
            return bait.tier, bait.item
        end
    end
    return 0, nil
end

-- Selectie pondere a tipului de peste
-- rarityLvl = nivel efectiv de raritate (skill + rod offset, cap 5)
local function pickFishType(baitTier, level, rodRarityOffset)
    local rarityLvl = math.min(5, (level or 1) + (rodRarityOffset or 0))
    local pool = {}
    local totalW = 0
    for _, fish in ipairs(ALL_FISH) do
        if baitTier >= fish.minBait then
            local w = fish.w[rarityLvl] or 0
            if w > 0 then
                pool[#pool + 1] = { fish = fish, w = w }
                totalW = totalW + w
            end
        end
    end
    if #pool == 0 then
        return ALL_FISH[1]  -- fallback: common
    end
    local roll = math.random(1, totalW)
    local acc = 0
    for _, entry in ipairs(pool) do
        acc = acc + entry.w
        if roll <= acc then return entry.fish end
    end
    return pool[#pool].fish
end

local function fishLevel(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return 1 end
    return tonumber(MySQL.scalar.await(
        'SELECT level FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'fisherman' }
    )) or 1
end

local function fishInventorySummary(source, cfg)
    local count, value = 0, 0
    local inv = exports.sunset_inventory:GetInventory(source) or {}
    for _, row in ipairs(inv) do
        local baseVal = FISH_BASE_VALUES[row.item]
        if baseVal then
            local rowCount = tonumber(row.count) or 0
            count = count + rowCount
            -- usa valoarea stocata in metadata daca exista, altfel baza
            local rowVal = tonumber(row.metadata and row.metadata.value) or baseVal
            value = value + rowVal * rowCount
        end
    end
    return count, value
end

-- ── Callbacks ─────────────────────────────────────────────────

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:bagStatus', function(source)
    local cfg = Sunset.GetJobConfig('fisherman')
    local level = fishLevel(source)
    local carried, carriedValue = fishInventorySummary(source, cfg)
    local session = SunsetJobs_GetSession(source)
    if session and session.jobId == 'fisherman' then
        session.data.pendingValue = carriedValue
        session.data.level = level
    end
    return { carried = carried, pendingValue = carriedValue, level = level }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:start', function(source)
    local cfg = Sunset.GetJobConfig('fisherman')
    local existing = SunsetJobs_GetSession(source)
    if existing and existing.jobId == 'fisherman' then
        local lv = fishLevel(source)
        existing.data.level = lv
        return existing.data
    end
    local lv = fishLevel(source)
    local session, err = SunsetJobs_StartSession(source, 'fisherman', {
        catches      = 0,
        pendingValue = 0,
        level        = lv,
        stage        = 'fishing',
    })
    if not session then return nil, err end
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:catch', function(source, spotIndex)
    local session, err = SunsetJobs_RequireSession(source, 'fisherman', { 'ACTIVE', 'STARTING' })
    if not session then return nil, err end
    local cfg = Sunset.GetJobConfig('fisherman')
    if not inFishZone(source, cfg) then
        return nil, 'Not at a fishing spot'
    end
    return nil, 'Cast first with /fish'
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:cast', function(source, spotIndex)
    local session, err = SunsetJobs_RequireSession(source, 'fisherman', { 'ACTIVE', 'STARTING' })
    if not session then return nil, err end

    local cfg = Sunset.GetJobConfig('fisherman')
    spotIndex = tonumber(spotIndex) or 1
    if not inFishZone(source, cfg) then
        return nil, 'You are not in the fishing area'
    end

    session.data.level = fishLevel(source)

    -- Verifica spatiu in inventar (cel mai usor peste = fish_common = 0.8 kg)
    local inv = exports.sunset_inventory:GetInventory(source) or {}
    local currentWeight = 0
    for _, row in ipairs(inv) do
        local def = Sunset.Items[row.item]
        if def then currentWeight = currentWeight + (def.weight or 0) * (row.count or 1) end
    end
    local minFishWeight = (Sunset.Items['fish_common'] or {}).weight or 0.8
    if currentWeight + minFishWeight > Sunset.Config.MaxWeight then
        return nil, ('Bag full! Sell your fish first. (%.1f / %.1f kg)'):format(
            currentWeight, Sunset.Config.MaxWeight)
    end

    local now = GetGameTimer()
    local challenge = session.data.fishingChallenge
    if challenge and now <= challenge.expiresAt then return nil, 'Your line is already cast' end

    local rod = getEquippedRod(source)
    local baitTier, baitItem = consumeBestBait(source)

    local delay  = math.max(800,
        math.random(cfg.biteDelayMinMs or 2500, cfg.biteDelayMaxMs or 6500) - rod.delayReduction)
    local window = (cfg.reactionWindowMs or 1400) + rod.windowBonus
    local token  = ('%d-%d-%d'):format(source, session.id, math.random(100000, 999999))

    session.data.fishingChallenge = {
        token          = token,
        spotIndex      = spotIndex,
        biteAt         = now + delay,
        expiresAt      = now + delay + window,
        rodValueMult   = rod.valueMult,
        rodRarityLevel = rod.rarityLevel or 0,
        baitTier       = baitTier,
        level          = session.data.level,
    }
    if session.state == 'STARTING' then SunsetJobs_SetState(source, 'ACTIVE') end

    local castInfo = {
        token    = token,
        delayMs  = delay,
        windowMs = window,
        baitTier = baitTier,
    }
    if baitItem           then castInfo.baitUsed = baitItem end
    if rod.item           then castInfo.rodTier  = rod.item end
    return castInfo
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:reel', function(source, spotIndex, token)
    local session, err = SunsetJobs_RequireSession(source, 'fisherman', { 'ACTIVE' })
    if not session then return nil, err end

    local cfg = Sunset.GetJobConfig('fisherman')
    spotIndex = tonumber(spotIndex) or 1
    if not inFishZone(source, cfg) then
        session.data.fishingChallenge = nil
        return nil, 'You left the fishing area'
    end

    local challenge = session.data.fishingChallenge
    session.data.fishingChallenge = nil
    if not challenge or challenge.token ~= tostring(token or '') or challenge.spotIndex ~= spotIndex then
        return nil, 'Invalid cast — use /fish again'
    end

    local now = GetGameTimer()
    if now < challenge.biteAt    then return nil, 'Too early — the fish escaped' end
    if now > challenge.expiresAt then return nil, 'Too late — the fish escaped' end

    local rodValueMult   = challenge.rodValueMult   or 1.0
    local rodRarityLevel = challenge.rodRarityLevel or 0
    local baitTier       = challenge.baitTier       or 0
    local level          = challenge.level          or 1

    -- Sansa de prindere: baza (momeala) + bonus nivel skill, cap 98%
    -- Undita NU afecteaza catch chance — afecteaza raritatea pestelui prins
    local baseChance  = CATCH_CHANCE[baitTier] or 35
    local levelBonus  = LEVEL_CATCH_BONUS[level] or 0
    local catchChance = math.min(98, baseChance + levelBonus)
    local catchRoll   = math.random(1, 100)
    if catchRoll > catchChance then
        -- Rata — nimic prins
        return nil, 'The fish got away... try again!'
    end

    -- Selectie tip peste: undita creste nivelul efectiv de raritate
    local fishType = pickFishType(baitTier, level, rodRarityLevel)
    local fishKg   = math.random(math.floor(fishType.minKg * 10), math.floor(fishType.maxKg * 10)) / 10
    local value    = math.floor(fishKg * fishType.pricePerKg * rodValueMult)
    local fishItem = fishType.item

    if not exports.sunset_inventory:AddItem(source, fishItem, 1, nil, {
        value    = value,
        fishKg   = fishKg,
        caughtAt = os.time(),
    }) then
        return nil, 'Inventory full or no slot. Free space and try again.'
    end

    session.data.catches      = (session.data.catches or 0) + 1
    session.data.pendingValue = (session.data.pendingValue or 0) + value

    SunsetJobs_AddJobXP(source, 'fisherman', cfg.xpPerCatch or 12)
    if GetResourceState('sunset_pass') == 'started' then
        exports.sunset_pass:AddMissionProgress(source, 'fish_catch', 1)
    end
    TriggerClientEvent('sunset:jobs:stateChanged', source, session.state, session.data)
    return {
        value        = value,
        fishKg       = fishKg,
        fishItem     = fishItem,
        catches      = session.data.catches,
        pendingValue = session.data.pendingValue,
    }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:miss', function(source, token)
    local session, err = SunsetJobs_RequireSession(source, 'fisherman', { 'ACTIVE' })
    if not session then return nil, err end
    local challenge = session.data.fishingChallenge
    if challenge and challenge.token == tostring(token or '') then
        session.data.fishingChallenge = nil
    end
    return true
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:sell', function(source)
    local cfg = Sunset.GetJobConfig('fisherman')
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and try again.' end
    if select(1, Sunset.GetCharacterJob(char)) ~= 'fisherman' then
        return nil, 'Only employed fishermen can sell fish here.'
    end
    if not SunsetJobs_ValidateCoords(source, cfg.sellPoint.coords, cfg.sellRadius or 5.0) then
        return nil, 'You are not at Fish Buyer.'
    end
    if SellLocks[source] then return nil, 'Sale already being processed.' end

    local count, pending = fishInventorySummary(source, cfg)
    if count <= 0 or pending <= 0 then
        return nil, 'You have no fish in your inventory. Catch fish with /fish first.'
    end

    SellLocks[source] = true

    local bonus = math.floor(pending * (cfg.sellBonusMultiplier or 1.0))
    local fishSet = {}
    for _, item in ipairs(ALL_FISH_ITEMS) do fishSet[item] = true end
    local committed = MySQL.startTransaction(function()
        local rows = MySQL.query.await(
            'SELECT id, item, count, metadata FROM character_inventory WHERE character_id = ? FOR UPDATE',
            { char.id }) or {}
        local lockedCount, lockedValue, ids = 0, 0, {}
        for _, row in ipairs(rows) do
            if fishSet[row.item] then
                local metadata = row.metadata
                if type(metadata) == 'string' then
                    local ok, decoded = pcall(json.decode, metadata)
                    metadata = ok and decoded or nil
                end
                local rowCount = tonumber(row.count) or 0
                local rowValue = tonumber(metadata and metadata.value) or FISH_BASE_VALUES[row.item] or 0
                lockedCount = lockedCount + rowCount
                lockedValue = lockedValue + rowValue * rowCount
                ids[#ids + 1] = tonumber(row.id)
            end
        end
        if lockedCount < 1 or lockedValue <= 0 then error('fish_changed') end
        bonus = math.floor(lockedValue * (cfg.sellBonusMultiplier or 1.0))
        for _, id in ipairs(ids) do
            if MySQL.update.await('DELETE FROM character_inventory WHERE id = ? AND character_id = ?', { id, char.id }) ~= 1 then error('fish_changed') end
        end
        if MySQL.update.await('UPDATE characters SET cash = cash + ? WHERE id = ?', { bonus, char.id }) ~= 1 then error('payment_failed') end
        MySQL.insert.await([[INSERT INTO money_transactions
            (character_id, account, direction, amount, reason, balance_after)
            SELECT id, 'cash', 'in', ?, 'fisherman_sell', cash FROM characters WHERE id = ?]], { bonus, char.id })
        count = lockedCount
    end)
    if not committed then
        SellLocks[source] = nil
        exports.sunset_inventory:ReloadInventory(source)
        return nil, 'The fish sale was cancelled safely because your inventory changed. No fish or money was lost.'
    end
    exports.sunset_inventory:ReloadInventory(source)
    exports.sunset_core:RefreshMoney(source)
    SunsetJobs_AddJobProgress(source, 'fisherman', math.max(5, math.floor(bonus / 10)), 1, bonus)

    local session = SunsetJobs_GetSession(source)
    if session and session.jobId == 'fisherman' then
        session.data.pendingValue    = 0
        session.data.carried         = 0
        session.data.stage           = 'fishing'
        session.data.fishingChallenge = nil
        if session.state == 'STARTING' then SunsetJobs_SetState(source, 'ACTIVE') end
        TriggerClientEvent('sunset:jobs:stateChanged', source, session.state, session.data)
    end
    SellLocks[source] = nil
    return { amount = bonus, count = count, session = session and session.data }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:endShift', function(source)
    local session = SunsetJobs_GetSession(source)
    if not session or session.jobId ~= 'fisherman' then return nil, 'No fishing shift' end
    SunsetJobs_ClearSession(source, 'CANCELLED', 'Shift ended')
    return true
end)

AddEventHandler('playerDropped', function()
    SellLocks[source] = nil
end)
