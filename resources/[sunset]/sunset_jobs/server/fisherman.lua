exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:start', function(source)
    local session, err = SunsetJobs_StartSession(source, 'fisherman', {
        catches = 0,
        pendingValue = 0,
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

    if not SunsetJobs_ValidateCoords(source, spot.coords, cfg.catchRadius or 8.0) then
        return nil, 'Not at a fishing spot'
    end

    if session.state == 'STARTING' then
        SunsetJobs_SetState(source, 'ACTIVE')
    end

    local value = math.random(cfg.catchPayMin or 30, cfg.catchPayMax or 100)
    session.data.catches = (session.data.catches or 0) + 1
    session.data.pendingValue = (session.data.pendingValue or 0) + value

    SunsetJobs_AddJobXP(source, 'fisherman', cfg.xpPerCatch or 12)
    return { value = value, catches = session.data.catches, pendingValue = session.data.pendingValue }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:sell', function(source)
    local session, err = SunsetJobs_RequireSession(source, 'fisherman', { 'ACTIVE' })
    if not session then return nil, err end

    local cfg = Sunset.GetJobConfig('fisherman')
    if not SunsetJobs_ValidateCoords(source, cfg.sellPoint.coords, cfg.sellRadius or 3.0) then
        return nil, 'Go to the fish buyer'
    end

    local pending = session.data.pendingValue or 0
    if pending <= 0 then return nil, 'Nothing to sell — catch some fish first' end

    local bonus = math.floor(pending * (cfg.sellBonusMultiplier or 1.0))
    SunsetJobs_PayReward(source, 'fisherman', bonus, 'fisherman_sell', true)

    session.data.pendingValue = 0
    SunsetJobs_ClearSession(source, 'COMPLETED', 'Catch sold')
    return { amount = bonus }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:fisherman:endShift', function(source)
    local session = SunsetJobs_GetSession(source)
    if not session or session.jobId ~= 'fisherman' then return nil, 'No fishing shift' end

    local pending = session.data.pendingValue or 0
    if pending > 0 then
        return nil, 'Sell your catch at the pier first'
    end

    SunsetJobs_ClearSession(source, 'CANCELLED', 'Shift ended')
    return true
end)
