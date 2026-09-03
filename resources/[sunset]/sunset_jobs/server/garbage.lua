local function shuffleBins(bins, count)
    local copy = {}
    for i, v in ipairs(bins) do copy[i] = v end
    for i = #copy, 2, -1 do
        local j = math.random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    local out = {}
    for i = 1, math.min(count or #copy, #copy) do
        out[i] = { x = copy[i].x, y = copy[i].y, z = copy[i].z }
    end
    return out
end

exports.sunset_core:RegisterCallback('sunset:jobs:garbage:start', function(source)
    local cfg = Sunset.GetJobConfig('garbage')
    if not SunsetJobs_ValidateCoords(source, cfg.depot.coords, 20.0) then return nil, 'Go to the garbage depot to start work' end
    local routeBins = shuffleBins(cfg.bins, cfg.capacity + 2)

    local session, err = SunsetJobs_StartSession(source, 'garbage', {
        bins = routeBins,
        collected = 0,
        capacity = cfg.capacity or 8,
        stage = 'collecting',
        binIndex = 1,
    })
    if not session then return nil, err end
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:garbage:collectBin', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'garbage', { 'ACTIVE' })
    if not session then return nil, err end
    if session.data.stage ~= 'collecting' then return nil, 'Unload at depot first' end

    local cfg = Sunset.GetJobConfig('garbage')
    if not SunsetJobs_ValidateVehicle(source, cfg.truckModel, false, 25.0) then return nil, 'Your assigned trash truck must be nearby' end
    local idx = session.data.binIndex or 1
    local bin = session.data.bins[idx]
    if not bin then return nil, 'No more bins on route' end

    if not SunsetJobs_ValidateCoords(source, bin, cfg.collectRadius or 2.5) then
        return nil, 'Not at the bin'
    end

    session.data.collected = (session.data.collected or 0) + 1
    session.data.binIndex = idx + 1
    SunsetJobs_PayReward(source, 'garbage', cfg.payPerBin or 60, 'garbage_bin', false)
    SunsetJobs_AddJobXP(source, 'garbage', cfg.xpPerBin or 10)

    if session.data.collected >= session.data.capacity then
        session.data.stage = 'return_unload'
        SunsetJobs_SetState(source, 'RETURNING')
    end

    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:garbage:unload', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'garbage', { 'RETURNING', 'ACTIVE' })
    if not session then return nil, err end
    if session.data.stage ~= 'return_unload' then return nil, 'Truck not full yet' end

    local cfg = Sunset.GetJobConfig('garbage')
    if not SunsetJobs_ValidateVehicle(source, cfg.truckModel, true, 20.0) then return nil, 'Use your assigned trash truck' end
    local unload = cfg.depot.unload or cfg.depot.coords
    if not SunsetJobs_ValidateCoords(source, unload, 8.0) then
        return nil, 'Drive to the depot unload point'
    end

    local bonus = cfg.payPerUnload or 150
    SunsetJobs_PayReward(source, 'garbage', bonus, 'garbage_unload', true)
    SunsetJobs_AddJobXP(source, 'garbage', cfg.xpPerUnload or 25)

    SunsetJobs_ClearSession(source, 'COMPLETED', 'Route complete')
    return { bonus = bonus }
end)
