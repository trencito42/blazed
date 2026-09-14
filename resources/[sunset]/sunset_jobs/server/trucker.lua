local function validateTruckerCoords(source, target, cfg)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local t = type(target) == 'vector3' and target or vector3(target.x, target.y, target.z)
    local dx, dy = pos.x - t.x, pos.y - t.y
    if math.sqrt(dx * dx + dy * dy) > (cfg.deliveryRadius or 25.0) then return false end
    return math.abs(pos.z - t.z) <= (cfg.deliveryZTolerance or 8.0)
end

-- Returns the player's trucker rank (level) and XP.
exports.sunset_core:RegisterCallback('sunset:jobs:trucker:getRank', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return { level = 1, xp = 0, xpNext = 100 } end
    local row = MySQL.single.await(
        'SELECT xp, level FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'trucker' }
    )
    local level  = (row and row.level) or 1
    local xp     = (row and row.xp) or 0
    local xpNext = xpForLevel and xpForLevel(level) or (100 * level)
    return { level = level, xp = xp, xpNext = xpNext }
end)

-- Returns the available routes with lock state based on the player's level.
exports.sunset_core:RegisterCallback('sunset:jobs:trucker:getRoutes', function(source)
    local cfg = Sunset.GetJobConfig('trucker')
    if not cfg or not cfg.routes then return {} end
    local level = SunsetJobs_GetJobLevel(source, 'trucker')
    local routes = {}
    for i, route in ipairs(cfg.routes) do
        routes[#routes + 1] = {
            index    = i,
            label    = route.label,
            category = route.category or 'general',
            pay      = route.pay,
            minLevel = route.minLevel or 1,
            locked   = level < (route.minLevel or 1),
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
        -- Verify the player has the required rank for this route
        local route = cfg.routes[routeIdx]
        if route and route.minLevel then
            local level = SunsetJobs_GetJobLevel(source, 'trucker')
            if level < route.minLevel then
                return nil, ('This route requires Rank %d (you are Rank %d)'):format(route.minLevel, level)
            end
        end
    else
        routeIdx = math.random(1, #cfg.routes)
    end
    local route = cfg.routes[routeIdx]
    local session, err = SunsetJobs_StartSession(source, 'trucker', {
        routeIndex = routeIdx,
        pickup = { x = route.pickup.x, y = route.pickup.y, z = route.pickup.z },
        delivery = { x = route.delivery.x, y = route.delivery.y, z = route.delivery.z },
        pay = route.pay,
        label = route.label,
        stage = 'to_pickup',
    })
    if not session then return nil, err end
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:trucker:atPickup', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'trucker', { 'ACTIVE' })
    if not session then return nil, err end
    if session.data.stage ~= 'to_pickup' then return nil, 'Not heading to pickup' end

    local cfg = Sunset.GetJobConfig('trucker')
    if not SunsetJobs_ValidateVehicle(source, cfg.truckModel, true, 20.0) then
        return nil, 'Use your assigned work truck'
    end
    local trailerOk, trailerErr = SunsetJobs_ValidateTrailer(source, true, 18.0)
    if not trailerOk then return nil, trailerErr end
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
    if not SunsetJobs_ValidateVehicle(source, cfg.truckModel, true, 20.0) then
        return nil, 'Use your assigned work truck'
    end
    local trailerOk, trailerErr = SunsetJobs_ValidateTrailer(source, true, 18.0)
    if not trailerOk then return nil, trailerErr end
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

    local pay = route.pay or 500
    local paid = SunsetJobs_PayReward(source, 'trucker', pay, 'trucker_delivery', true)
    if not paid then
        -- Payout failed (no char/DB): allow retry, restore stage.
        session.data.stage = 'to_delivery'
        session.data.deliveredAt = nil
        return nil, 'Payment could not be processed. Try delivering once more.'
    end
    SunsetJobs_AddJobXP(source, 'trucker', cfg.xpPerDelivery or 40)

    SunsetJobs_SetState(source, 'RETURNING')
    return { pay = pay, stage = 'return_depot' }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:trucker:returnDepot', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'trucker', { 'RETURNING', 'ACTIVE' })
    if not session then return nil, err end

    local cfg = Sunset.GetJobConfig('trucker')
    if not SunsetJobs_ValidateVehicle(source, cfg.truckModel, true, 20.0) then
        return nil, 'Return your assigned work truck'
    end
    local trailerOk, trailerErr = SunsetJobs_ValidateTrailer(source, true, 18.0)
    if not trailerOk then return nil, trailerErr end
    if not SunsetJobs_ValidateCoords(source, cfg.depot.coords, cfg.returnRadius or 25.0) then
        return nil, 'Return the truck to the depot'
    end

    SunsetJobs_ClearSession(source, 'COMPLETED', 'Route complete')
    return true
end)
