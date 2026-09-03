exports.sunset_core:RegisterCallback('sunset:jobs:trucker:start', function(source)
    local cfg = Sunset.GetJobConfig('trucker')
    if not cfg or not cfg.routes or #cfg.routes == 0 then return nil, 'No routes configured' end

    local routeIdx = math.random(1, #cfg.routes)
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
    local route = cfg.routes[session.data.routeIndex]
    if not SunsetJobs_ValidateCoords(source, route.pickup, cfg.deliveryRadius) then
        return nil, 'Not at pickup location'
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
    local route = cfg.routes[session.data.routeIndex]
    if not SunsetJobs_ValidateCoords(source, route.delivery, cfg.deliveryRadius) then
        return nil, 'Not at delivery location'
    end

    local pay = route.pay or 500
    SunsetJobs_PayReward(source, 'trucker', pay, 'trucker_delivery', true)
    SunsetJobs_AddJobXP(source, 'trucker', cfg.xpPerDelivery or 40)

    session.data.stage = 'return_depot'
    SunsetJobs_SetState(source, 'RETURNING')
    return { pay = pay, stage = 'return_depot' }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:trucker:returnDepot', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'trucker', { 'RETURNING', 'ACTIVE' })
    if not session then return nil, err end

    local cfg = Sunset.GetJobConfig('trucker')
    if not SunsetJobs_ValidateCoords(source, cfg.depot.coords, cfg.returnRadius or 15.0) then
        return nil, 'Return the truck to the depot'
    end

    SunsetJobs_ClearSession(source, 'COMPLETED', 'Route complete')
    return true
end)
