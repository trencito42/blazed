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

local function getSessionVehicle(source)
    local session = SunsetJobs_GetSession(source)
    if not session or not session.vehicleNetId then return nil end
    local entity = NetworkGetEntityFromNetworkId(session.vehicleNetId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    return entity
end

local function getTruckRearCoords(entity, offsetY)
    local rear = GetOffsetFromEntityInWorldCoords(entity, 0.0, offsetY or -4.5, 0.0)
    return vector3(rear.x, rear.y, rear.z)
end

local function validateTruckRear(source, cfg)
    local entity = getSessionVehicle(source)
    if not entity then return false, 'Your assigned trash truck must be nearby' end
    if GetEntityModel(entity) ~= joaat(cfg.truckModel) then
        return false, 'Your assigned trash truck must be nearby'
    end
    local rear = getTruckRearCoords(entity, cfg.truckRearOffset or -4.5)
    if not SunsetJobs_ValidateCoords(source, rear, cfg.dumpRadius or 3.5) then
        return false, 'Go to the back of your trash truck'
    end
    return true
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
        carrying = false,
    })
    if not session then return nil, err end
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:garbage:pickupBin', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'garbage', { 'ACTIVE' })
    if not session then return nil, err end
    if session.data.stage ~= 'collecting' then return nil, 'Unload at depot first' end
    if session.data.carrying then return nil, 'You are already carrying a bag' end

    local cfg = Sunset.GetJobConfig('garbage')
    local idx = session.data.binIndex or 1
    local bin = session.data.bins[idx]
    if not bin then return nil, 'No more bins on route' end

    if not SunsetJobs_ValidateCoords(source, bin, cfg.collectRadius or 3.0) then
        return nil, 'Not at the bin'
    end

    session.data.carrying = true
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:garbage:dumpBin', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'garbage', { 'ACTIVE' })
    if not session then return nil, err end
    if session.data.stage ~= 'collecting' then return nil, 'Unload at depot first' end
    if not session.data.carrying then return nil, 'Pick up trash from the bin first' end

    local cfg = Sunset.GetJobConfig('garbage')
    local ok, truckErr = validateTruckRear(source, cfg)
    if not ok then return nil, truckErr end

    session.data.carrying = false
    session.data.collected = (session.data.collected or 0) + 1
    session.data.binIndex = (session.data.binIndex or 1) + 1
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
    if session.data.carrying then return nil, 'Dump the bag in your truck first' end

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
