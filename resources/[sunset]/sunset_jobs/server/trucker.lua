local function validateTruckerCoords(source, target, cfg)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local t = type(target) == 'vector3' and target or vector3(target.x, target.y, target.z)
    local dx, dy = pos.x - t.x, pos.y - t.y
    if math.sqrt(dx * dx + dy * dy) > (cfg.deliveryRadius or 25.0) then return false end
    return math.abs(pos.z - t.z) <= (cfg.deliveryZTolerance or 8.0)
end

-- Pay bonus per rank (level): rank 1 = +0%, rank 5 = +5%
local TRUCKER_RANK_BONUS = { [1] = 0.00, [2] = 0.01, [3] = 0.02, [4] = 0.035, [5] = 0.05 }

-- XP thresholds per level (XP needed to go from level N to N+1).
-- Mirrors the fisherman pattern; tuned so rank 5 requires ~30-35 deliveries.
-- Level 1→2: 300 XP  (~3 basic deliveries at $600)
-- Level 2→3: 700 XP  (~7 basic deliveries)
-- Level 3→4: 1200 XP (~12 deliveries)
-- Level 4→5: 2000 XP (~20 deliveries)
-- Total to rank 5: 4200 XP ≈ 30-35 deliveries ≈ 10-12 hours trucking.
local TRUCKER_XP_THRESHOLDS = { 300, 700, 1200, 2000 }

local function truckerXpForLevel(level)
    return TRUCKER_XP_THRESHOLDS[level] or math.max(100, level * 500)
end

-- Override job_progress XP for trucker only by hooking AddJobXP after PayReward.
-- PayReward calls SunsetJobs_AddJobProgress(jobId, amount/10 ...) with the generic
-- xpForLevel. We compensate by awarding an ADJUSTMENT after the fact so the
-- effective threshold matches TRUCKER_XP_THRESHOLDS.
-- NOTE: simpler approach — use a dedicated helper that bypasses the global formula.
local function truckerAddXP(source, xpAmount)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end
    local row = MySQL.single.await(
        'SELECT xp, level, completed_tasks, total_earned FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'trucker' }
    )
    local xp     = (row and row.xp or 0) + xpAmount
    local level  = row and row.level or 1
    local tasks  = row and row.completed_tasks or 0
    local earned = row and row.total_earned or 0

    local needed = truckerXpForLevel(level)
    while xp >= needed do
        xp    = xp - needed
        level = level + 1
        needed = truckerXpForLevel(level)
        TriggerClientEvent('sunset:client:notify', source,
            ('Trucker rank %d!'):format(level), 'success', 5000)
        TriggerEvent('sunset:quest:progress', char.id, 'job_level_up', 1, { jobId = 'trucker', level = level })
    end

    if row then
        MySQL.update.await(
            'UPDATE job_progress SET xp = ?, level = ?, completed_tasks = ?, total_earned = ? WHERE character_id = ? AND job_id = ?',
            { xp, level, tasks, earned, char.id, 'trucker' }
        )
    else
        MySQL.insert.await(
            'INSERT INTO job_progress (character_id, job_id, xp, level, completed_tasks, total_earned) VALUES (?, ?, ?, ?, ?, ?)',
            { char.id, 'trucker', xp, level, tasks, earned }
        )
    end
end

-- Returns NPC menu data (job status for building hire/start/end actions).
exports.sunset_core:RegisterCallback('sunset:jobs:trucker:getNpcMenu', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return { job = nil, onShift = false } end
    local job = select(1, Sunset.GetCharacterJob(char))
    local session = SunsetJobs_GetSession(source)
    local onShift = session and session.jobId == 'trucker' and session.state ~= 'IDLE'
    return { job = job, onShift = onShift }
end)

-- Returns the player's trucker rank (level) and XP.
exports.sunset_core:RegisterCallback('sunset:jobs:trucker:getRank', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return { level = 1, xp = 0, xpNext = TRUCKER_XP_THRESHOLDS[1] } end
    local row = MySQL.single.await(
        'SELECT xp, level FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'trucker' }
    )
    local level  = (row and row.level) or 1
    local xp     = (row and row.xp) or 0
    local xpNext = truckerXpForLevel(level)
    local bonus  = TRUCKER_RANK_BONUS[level] or 0
    return { level = level, xp = xp, xpNext = xpNext, bonusPct = math.floor(bonus * 100) }
end)

-- Returns all routes (no locking — all available; rank only affects pay bonus).
exports.sunset_core:RegisterCallback('sunset:jobs:trucker:getRoutes', function(source)
    local cfg = Sunset.GetJobConfig('trucker')
    if not cfg or not cfg.routes then return {} end
    local level = SunsetJobs_GetJobLevel(source, 'trucker')
    local bonus = TRUCKER_RANK_BONUS[level] or 0
    local routes = {}
    for i, route in ipairs(cfg.routes) do
        local effectivePay = math.floor((route.pay or 500) * (1 + bonus))
        routes[#routes + 1] = {
            index      = i,
            label      = route.label,
            category   = route.category or 'general',
            basePay    = route.pay,
            pay        = effectivePay,   -- pay with rank bonus already applied
            bonusPct   = math.floor(bonus * 100),
        }
    end
    return routes
end)

exports.sunset_core:RegisterCallback('sunset:jobs:trucker:start', function(source, selectedRouteIdx)
    local cfg = Sunset.GetJobConfig('trucker')
    if not cfg or not cfg.routes or #cfg.routes == 0 then return nil, 'No routes configured' end
    if not SunsetJobs_ValidateCoords(source, cfg.depot.coords, 20.0) then return nil, 'Go to the trucker depot to start work' end

    local routeIdx
    if selectedRouteIdx and tonumber(selectedRouteIdx) then
        routeIdx = math.max(1, math.min(#cfg.routes, tonumber(selectedRouteIdx)))
    else
        routeIdx = math.random(1, #cfg.routes)
    end
    local route = cfg.routes[routeIdx]

    -- Pick truck model for this route's category
    local catTrucks    = cfg.categoryTrucks or {}
    local catData      = catTrucks[route.category or 'general'] or {}
    local models       = catData.models or { cfg.truckModel or 'phantom' }
    local truckModel   = models[math.random(#models)]
    local hasTrailer   = catData.hasTrailer ~= false   -- default true if unset
    local trailerModel = catData.trailerModel or cfg.trailerModel or 'trailers2'

    local session, err = SunsetJobs_StartSession(source, 'trucker', {
        routeIndex    = routeIdx,
        pickup        = { x = route.pickup.x, y = route.pickup.y, z = route.pickup.z },
        delivery      = { x = route.delivery.x, y = route.delivery.y, z = route.delivery.z },
        pay           = route.pay,
        label         = route.label,
        stage         = 'to_pickup',
        truckModel    = truckModel,
        hasTrailer    = hasTrailer,
        trailerModel  = trailerModel,
    })
    if not session then return nil, err end
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:trucker:atPickup', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'trucker', { 'ACTIVE' })
    if not session then return nil, err end
    if session.data.stage ~= 'to_pickup' then return nil, 'Not heading to pickup' end

    local cfg = Sunset.GetJobConfig('trucker')
    if not SunsetJobs_ValidateVehicle(source, session.data.truckModel or cfg.truckModel, true, 20.0) then
        return nil, 'Use your assigned work truck'
    end
    if session.data.hasTrailer then
        local trailerOk, trailerErr = SunsetJobs_ValidateTrailer(source, true, 18.0)
        if not trailerOk then return nil, trailerErr end
    end
    local route = cfg.routes[session.data.routeIndex]
    if not route then return nil, 'Route data is missing' end
    if not validateTruckerCoords(source, route.pickup, cfg) then
        return nil, 'Not at pickup location — drive into the loading dock marker'
    end

    session.data.stage = 'to_delivery'
    SunsetJobs_SetState(source, 'ACTIVE')
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:trucker:deliver', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'trucker', { 'ACTIVE' })
    if not session then return nil, err end
    if session.data.stage ~= 'to_delivery' then return nil, 'Cargo not loaded' end

    local cfg = Sunset.GetJobConfig('trucker')
    if not SunsetJobs_ValidateVehicle(source, session.data.truckModel or cfg.truckModel, true, 20.0) then
        return nil, 'Use your assigned work truck'
    end
    if session.data.hasTrailer then
        local trailerOk, trailerErr = SunsetJobs_ValidateTrailer(source, true, 18.0)
        if not trailerOk then return nil, trailerErr end
    end
    local route = cfg.routes[session.data.routeIndex]
    if not route then return nil, 'Route data is missing' end
    if not validateTruckerCoords(source, route.delivery, cfg) then
        return nil, 'Not at delivery location — drive into the green loading dock marker'
    end

    -- [AUDIT P2-SESSIONS] Scenario 14: flip the stage SYNCHRONOUSLY before any
    -- yielding payout call. Previously a second `deliver` arriving during the
    -- AddMoney/DB await still saw stage=='to_delivery' → double pay.
    session.data.stage = 'return_depot'
    local delivered = session.data.deliveredAt
    if delivered then return nil, 'Cargo already delivered on this route.' end
    session.data.deliveredAt = os.time()

    -- Apply rank bonus to pay (rank 1 = +0%, rank 5 = +5%)
    local level = SunsetJobs_GetJobLevel(source, 'trucker')
    local bonus = TRUCKER_RANK_BONUS[level] or 0
    local basePay = route.pay or 500
    local pay     = math.floor(basePay * (1 + bonus))

    -- Use AddMoney directly to avoid double-XP from SunsetJobs_PayReward.
    -- XP is awarded separately via truckerAddXP (uses trucker-specific thresholds).
    local paid = exports.sunset_core:AddMoney(source, 'cash', pay, 'trucker_delivery')
    if not paid then
        session.data.stage = 'to_delivery'
        session.data.deliveredAt = nil
        return nil, 'Payment could not be processed. Try delivering once more.'
    end
    -- XP = base pay / 10 (scales with route value, not fixed)
    truckerAddXP(source, math.max(5, math.floor(basePay / 10)))

    -- Battlepass mission progress
    if GetResourceState('sunset_pass') == 'started' then
        exports.sunset_pass:AddMissionProgress(source, 'trucker_delivery', 1)
    end

    SunsetJobs_SetState(source, 'RETURNING')
    return { pay = pay, basePay = basePay, bonusPct = math.floor(bonus * 100), stage = 'return_depot' }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:trucker:returnDepot', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'trucker', { 'RETURNING', 'ACTIVE' })
    if not session then return nil, err end

    local cfg = Sunset.GetJobConfig('trucker')
    if not SunsetJobs_ValidateVehicle(source, session.data.truckModel or cfg.truckModel, true, 20.0) then
        return nil, 'Return your assigned work truck'
    end
    if session.data.hasTrailer then
        local trailerOk, trailerErr = SunsetJobs_ValidateTrailer(source, true, 18.0)
        if not trailerOk then return nil, trailerErr end
    end
    if not SunsetJobs_ValidateCoords(source, cfg.depot.coords, cfg.returnRadius or 25.0) then
        return nil, 'Return the truck to the depot'
    end

    SunsetJobs_ClearSession(source, 'COMPLETED', 'Route complete')
    return true
end)
