local SellLocks = {}

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
    for _, row in ipairs(exports.sunset_inventory:GetInventory(source) or {}) do
        if row.item == (cfg.fishItem or 'fresh_fish') then
            local rowCount = tonumber(row.count) or 0
            count = count + rowCount
            value = value + (tonumber(row.metadata and row.metadata.value) or cfg.catchPayMin or 35) * rowCount
        end
    end
    return count, value
end

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
        catches = 0,
        carried = carried,
        pendingValue = carriedValue,
        level = level,
        capacity = capacity,
        stage = 'fishing',
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

    if not spot or not SunsetJobs_ValidateCoordsCylinder(source, spot.coords,
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
    local carried = exports.sunset_inventory:CountItem(source, cfg.fishItem or 'fresh_fish') or 0
    session.data.level = level
    session.data.capacity = capacity
    session.data.carried = carried
    if carried >= capacity then
        return nil, ('Fishing bag full (%d/%d). Follow GPS to Fish Buyer or use /sellfish.'):format(
            carried, capacity)
    end
    local now = GetGameTimer()
    local challenge = session.data.fishingChallenge
    if challenge and now <= challenge.expiresAt then return nil, 'Your line is already cast' end

    local delay = math.random(cfg.biteDelayMinMs or 2500, cfg.biteDelayMaxMs or 6500)
    local window = cfg.reactionWindowMs or 1400
    local token = ('%d-%d-%d'):format(source, session.id, math.random(100000, 999999))
    session.data.fishingChallenge = {
        token = token,
        spotIndex = spotIndex,
        biteAt = now + delay,
        expiresAt = now + delay + window,
    }
    if session.state == 'STARTING' then SunsetJobs_SetState(source, 'ACTIVE') end
    return { token = token, delayMs = delay, windowMs = window }
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
    if now < challenge.biteAt then return nil, 'Too early — the fish escaped' end
    if now > challenge.expiresAt then return nil, 'Too late — the fish escaped' end

    local value = math.random(cfg.catchPayMin or 30, cfg.catchPayMax or 100)
    local level, capacity = fishLevelAndCapacity(source, cfg)
    local fishItem = cfg.fishItem or 'fresh_fish'
    local carried = exports.sunset_inventory:CountItem(source, fishItem) or 0
    if carried >= capacity then
        return nil, ('Fishing bag full (%d/%d). Sell your fish before casting again.'):format(carried, capacity)
    end
    if not exports.sunset_inventory:AddItem(source, fishItem, 1, nil, {
        value = value,
        caughtAt = os.time(),
    }) then
        return nil, 'The fish escaped because your inventory has no free slot or weight. Free space and try again.'
    end
    session.data.catches = (session.data.catches or 0) + 1
    session.data.pendingValue = (session.data.pendingValue or 0) + value
    session.data.carried = carried + 1
    session.data.capacity = capacity
    session.data.level = level

    SunsetJobs_AddJobXP(source, 'fisherman', cfg.xpPerCatch or 12)
    if GetResourceState('sunset_pass') == 'started' then
        exports.sunset_pass:AddMissionProgress(source, 'fish_catch', 1)
    end
    TriggerClientEvent('sunset:jobs:stateChanged', source, session.state, session.data)
    return {
        value = value,
        catches = session.data.catches,
        carried = session.data.carried,
        capacity = capacity,
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
        return nil, 'Only employed fishermen can sell fish here. Get the Fisherman job first.'
    end
    if not SunsetJobs_ValidateCoords(source, cfg.sellPoint.coords, cfg.sellRadius or 5.0) then
        return nil, 'You are not at Fish Buyer. Follow the yellow GPS marker at Del Perro Pier.'
    end
    if SellLocks[source] then return nil, 'Your fish sale is already being processed.' end

    local count, pending = fishInventorySummary(source, cfg)
    if count <= 0 or pending <= 0 then return nil, 'You have no Fresh Fish in your inventory. Catch fish with /fish first.' end

    SellLocks[source] = true
    local takeOk, removed = pcall(function()
        return exports.sunset_inventory:TakeAllItems(source, cfg.fishItem or 'fresh_fish')
    end)
    if not takeOk or not removed or #removed == 0 then
        SellLocks[source] = nil
        return nil, 'The fish sale could not read your inventory. Nothing was charged; reopen it and try again.'
    end
    local bonus = math.floor(pending * (cfg.sellBonusMultiplier or 1.0))
    local payOk, paid = pcall(SunsetJobs_PayReward, source, 'fisherman', bonus, 'fisherman_sell', true)
    if not payOk or not paid then
        for _, row in ipairs(removed) do
            exports.sunset_inventory:AddItem(source, cfg.fishItem or 'fresh_fish', row.count or 1, nil, row.metadata)
        end
        SellLocks[source] = nil
        return nil, 'Payment failed. Your fish were returned to your inventory.'
    end

    local session = SunsetJobs_GetSession(source)
    if session and session.jobId == 'fisherman' then
        session.data.pendingValue = 0
        session.data.carried = 0
        session.data.stage = 'fishing'
        session.data.fishingChallenge = nil
        if session.state == 'STARTING' then
            SunsetJobs_SetState(source, 'ACTIVE')
        end
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
