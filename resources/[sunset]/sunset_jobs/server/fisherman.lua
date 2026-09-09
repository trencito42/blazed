local SellLocks = {}

-- ── Rod / Bait tables ─────────────────────────────────────────
local ROD_TIERS = {
    { item = 'fishing_rod_5', valueMult = 1.75, delayReduction = 2000, windowBonus = 600 },
    { item = 'fishing_rod_4', valueMult = 1.50, delayReduction = 1500, windowBonus = 400 },
    { item = 'fishing_rod_3', valueMult = 1.30, delayReduction = 1000, windowBonus = 200 },
    { item = 'fishing_rod_2', valueMult = 1.15, delayReduction = 500,  windowBonus = 0   },
    { item = 'fishing_rod_1', valueMult = 1.05, delayReduction = 0,    windowBonus = 0   },
}

-- baitTier: 0 = no bait, 1 = worm, 2 = lure, 3 = premium
local BAIT_TIERS = {
    { item = 'bait_premium', tier = 3 },
    { item = 'bait_lure',    tier = 2 },
    { item = 'bait_worm',    tier = 1 },
}

-- Sansa de prindere (%) pe tier momeala
local CATCH_CHANCE = { [0] = 35, [1] = 60, [2] = 75, [3] = 90 }

-- Peste + pret + tier minim momeala + greutati pe nivel (1-5)
-- w[level] = greutate; 0 inseamna imposibil
local ALL_FISH = {
    { item = 'fish_common',   min = 40,  max = 80,   minBait = 0, w = { 90, 70, 55, 40, 25 } },
    { item = 'fish_uncommon', min = 90,  max = 150,  minBait = 1, w = {  8, 25, 28, 28, 25 } },
    { item = 'fish_rare',     min = 170, max = 280,  minBait = 2, w = {  0,  5, 15, 22, 25 } },
    { item = 'fish_epic',     min = 320, max = 550,  minBait = 3, w = {  0,  0,  2,  8, 15 } },
    { item = 'fish_legendary',min = 650, max = 1200, minBait = 3, w = {  0,  0,  0,  2, 10 } },
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
    return { valueMult = 1.0, delayReduction = 0, windowBonus = 0 }
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
local function pickFishType(baitTier, level)
    local pool = {}
    local totalW = 0
    for _, fish in ipairs(ALL_FISH) do
        if baitTier >= fish.minBait then
            local w = fish.w[level] or 0
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

local function fishLevelAndCapacity(source, cfg)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return 1, cfg.carryBase or 2 end
    local level = tonumber(MySQL.scalar.await(
        'SELECT level FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'fisherman' }
    )) or 1
    local capacity = (cfg.carryBase or 2) + math.max(0, level - 1) * (cfg.carryPerLevel or 1)
    return level, math.min(cfg.carryMax or 12, capacity)
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
    local level, capacity = fishLevelAndCapacity(source, cfg)
    local carried, carriedValue = fishInventorySummary(source, cfg)
    local session = SunsetJobs_GetSession(source)
    if session and session.jobId == 'fisherman' then
        session.data.carried = carried
        session.data.capacity = capacity
        session.data.pendingValue = carriedValue
        session.data.level = level
    end
    return {
        carried = carried,
        capacity = capacity,
        pendingValue = carriedValue,
        full = carried >= capacity,
    }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:start', function(source)
    local cfg = Sunset.GetJobConfig('fisherman')
    local existing = SunsetJobs_GetSession(source)
    if existing and existing.jobId == 'fisherman' then
        local level, capacity = fishLevelAndCapacity(source, cfg)
        local carried, carriedValue = fishInventorySummary(source, cfg)
        existing.data.level = level
        existing.data.capacity = capacity
        existing.data.carried = carried
        existing.data.pendingValue = carriedValue
        return existing.data
    end
    local level, capacity = fishLevelAndCapacity(source, cfg)
    local carried, carriedValue = fishInventorySummary(source, cfg)
    local session, err = SunsetJobs_StartSession(source, 'fisherman', {
        catches      = 0,
        carried      = carried,
        pendingValue = carriedValue,
        level        = level,
        capacity     = capacity,
        stage        = 'fishing',
    })
    if not session then return nil, err end
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:catch', function(source, spotIndex)
    local session, err = SunsetJobs_RequireSession(source, 'fisherman', { 'ACTIVE', 'STARTING' })
    if not session then return nil, err end
    local cfg = Sunset.GetJobConfig('fisherman')
    local spot = cfg.spots[tonumber(spotIndex) or 1]
    if not spot then return nil, 'Invalid fishing spot' end
    if not SunsetJobs_ValidateCoordsCylinder(source, spot.coords,
        cfg.catchRadius or 1.6, cfg.catchZTolerance or 0.75) then
        return nil, 'Not at a fishing spot'
    end
    return nil, 'Cast first with /fish'
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:cast', function(source, spotIndex)
    local session, err = SunsetJobs_RequireSession(source, 'fisherman', { 'ACTIVE', 'STARTING' })
    if not session then return nil, err end

    local cfg = Sunset.GetJobConfig('fisherman')
    spotIndex = tonumber(spotIndex) or 1
    local spot = cfg.spots[spotIndex]
    if not spot or not SunsetJobs_ValidateCoordsCylinder(source, spot.coords,
        cfg.catchRadius or 1.6, cfg.catchZTolerance or 0.75) then
        return nil, 'Stand inside a fishing marker'
    end

    local level, capacity = fishLevelAndCapacity(source, cfg)
    local carried = 0
    for _, fi in ipairs(ALL_FISH_ITEMS) do
        carried = carried + (exports.sunset_inventory:CountItem(source, fi) or 0)
    end
    session.data.level = level
    session.data.capacity = capacity
    session.data.carried = carried
    if carried >= capacity then
        return nil, ('Fishing bag full (%d/%d). Sell fish first.'):format(carried, capacity)
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
        token        = token,
        spotIndex    = spotIndex,
        biteAt       = now + delay,
        expiresAt    = now + delay + window,
        rodValueMult = rod.valueMult,
        baitTier     = baitTier,
        level        = level,
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
    local spot = cfg.spots[spotIndex]
    if not spot or not SunsetJobs_ValidateCoordsCylinder(source, spot.coords,
        cfg.catchRadius or 1.6, cfg.catchZTolerance or 0.75) then
        session.data.fishingChallenge = nil
        return nil, 'You moved away from the fishing spot'
    end

    local challenge = session.data.fishingChallenge
    session.data.fishingChallenge = nil
    if not challenge or challenge.token ~= tostring(token or '') or challenge.spotIndex ~= spotIndex then
        return nil, 'Invalid cast — use /fish again'
    end

    local now = GetGameTimer()
    if now < challenge.biteAt    then return nil, 'Too early — the fish escaped' end
    if now > challenge.expiresAt then return nil, 'Too late — the fish escaped' end

    local rodValueMult = challenge.rodValueMult or 1.0
    local baitTier     = challenge.baitTier     or 0
    local level        = challenge.level        or 1

    -- Verifica sansa de prindere
    local catchRoll = math.random(1, 100)
    local catchChance = CATCH_CHANCE[baitTier] or 35
    if catchRoll > catchChance then
        -- Rata — nimic prins
        return nil, 'The fish got away... try again!'
    end

    -- Selectie tip peste
    local fishType = pickFishType(baitTier, level)
    local baseValue = math.random(fishType.min, fishType.max)
    local value     = math.floor(baseValue * rodValueMult)
    local fishItem  = fishType.item

    local level2, capacity = fishLevelAndCapacity(source, cfg)
    local carried = 0
    for _, fi in ipairs(ALL_FISH_ITEMS) do
        carried = carried + (exports.sunset_inventory:CountItem(source, fi) or 0)
    end
    if carried >= capacity then
        return nil, ('Fishing bag full (%d/%d). Sell your fish before casting again.'):format(carried, capacity)
    end

    if not exports.sunset_inventory:AddItem(source, fishItem, 1, nil, {
        value    = value,
        caughtAt = os.time(),
    }) then
        return nil, 'Inventory full or no slot. Free space and try again.'
    end

    session.data.catches      = (session.data.catches or 0) + 1
    session.data.pendingValue = (session.data.pendingValue or 0) + value
    session.data.carried      = carried + 1
    session.data.capacity     = capacity
    session.data.level        = level2

    SunsetJobs_AddJobXP(source, 'fisherman', cfg.xpPerCatch or 12)
    if GetResourceState('sunset_pass') == 'started' then
        exports.sunset_pass:AddMissionProgress(source, 'fish_catch', 1)
    end
    TriggerClientEvent('sunset:jobs:stateChanged', source, session.state, session.data)
    return {
        value        = value,
        fishItem     = fishItem,
        catches      = session.data.catches,
        carried      = session.data.carried,
        capacity     = capacity,
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

    -- Rimuovi tutti i tipi di pesce
    for _, fi in ipairs(ALL_FISH_ITEMS) do
        local c = exports.sunset_inventory:CountItem(source, fi) or 0
        if c > 0 then
            exports.sunset_inventory:RemoveItem(source, fi, c)
        end
    end

    local bonus = math.floor(pending * (cfg.sellBonusMultiplier or 1.0))
    local payOk, paid = pcall(SunsetJobs_PayReward, source, 'fisherman', bonus, 'fisherman_sell', true)
    if not payOk or not paid then
        SellLocks[source] = nil
        return nil, 'Payment failed.'
    end

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
