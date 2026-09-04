local function buildDeliveryQueue(cfg)
    local deliveries = cfg.deliveries or {}
    local count = math.min(cfg.packagesPerRun or 4, #deliveries)
    local indices = {}
    for i = 1, #deliveries do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    local queue = {}
    for i = 1, count do
        local d = deliveries[indices[i]]
        queue[#queue + 1] = {
            coords = { x = d.coords.x, y = d.coords.y, z = d.coords.z },
            label = d.label,
        }
    end
    return queue
end

local function playerOnFoot(source)
    local ped = GetPlayerPed(source)
    return ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) == 0
end

local function validatePickupCoords(source, cfg)
    local pos = GetEntityCoords(GetPlayerPed(source))
    if not pos then return false end
    local target = cfg.warehouse.coords
    local t = type(target) == 'vector3' and target or vector3(target.x, target.y, target.z)
    local dx = pos.x - t.x
    local dy = pos.y - t.y
    local horiz = math.sqrt(dx * dx + dy * dy)
    if horiz > (cfg.pickupRadius or 3.0) then return false end
    return math.abs(pos.z - t.z) <= (cfg.pickupZTolerance or 5.0)
end

exports.sunset_core:RegisterCallback('sunset:jobs:courier:start', function(source)
    local cfg = Sunset.GetJobConfig('courier')
    local queue = buildDeliveryQueue(cfg)

    local session, err = SunsetJobs_StartSession(source, 'courier', {
        deliveries = queue,
        delivered = 0,
        total = #queue,
        stage = 'pickup',
        hasPackage = false,
        deliveryIndex = 1,
    })
    if not session then return nil, err end
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:courier:pickup', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'courier', { 'ACTIVE', 'STARTING' })
    if not session then return nil, err end
    if session.data.hasPackage then return nil, 'Already carrying a package' end

    local stage = session.data.stage
    if stage ~= 'pickup' and not (stage == 'delivering' and not session.data.hasPackage) then
        return nil, 'Not ready to pick up a package'
    end

    if not playerOnFoot(source) then
        return nil, 'Pick up packages on foot'
    end

    local cfg = Sunset.GetJobConfig('courier')
    if not validatePickupCoords(source, cfg) then
        return nil, 'Go to the warehouse loading dock'
    end

    if session.state == 'STARTING' then
        SunsetJobs_SetState(source, 'ACTIVE')
    end

    session.data.hasPackage = true
    session.data.stage = 'delivering'
    return session.data
end)

exports.sunset_core:RegisterCallback('sunset:jobs:courier:deliver', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'courier', { 'ACTIVE' })
    if not session then return nil, err end
    if not session.data.hasPackage then return nil, 'Pick up a package first' end
    if not playerOnFoot(source) then return nil, 'Deliver the package on foot' end

    local cfg = Sunset.GetJobConfig('courier')
    local idx = session.data.deliveryIndex or 1
    local target = session.data.deliveries[idx]
    if not target then return nil, 'No delivery assigned' end

    if not SunsetJobs_ValidateCoords(source, target.coords, cfg.deliveryRadius or 2.5) then
        return nil, 'Not at delivery address'
    end

    local pay = cfg.payPerPackage or 100
    SunsetJobs_PayReward(source, 'courier', pay, 'courier_delivery', false)
    SunsetJobs_AddJobXP(source, 'courier', cfg.xpPerPackage or 15)

    session.data.delivered = (session.data.delivered or 0) + 1
    session.data.hasPackage = false
    session.data.deliveryIndex = idx + 1

    if session.data.delivered >= session.data.total then
        SunsetJobs_ClearSession(source, 'COMPLETED', 'All packages delivered')
        return { pay = pay, completed = true }
    end

    session.data.stage = 'pickup'
    return { pay = pay, completed = false, data = session.data }
end)
