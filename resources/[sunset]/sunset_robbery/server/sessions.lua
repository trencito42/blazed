RobberySessions = {
    bySource = {},
    locationBusy = {},
    playerCd = {},
    locationCd = {},
    lastEvent = {},
}

local STATES = {
    IDLE = 'IDLE',
    STARTING = 'STARTING',
    HACKING = 'HACKING',
    LOOTING = 'LOOTING',
    ESCAPING = 'ESCAPING',
    SUCCESS = 'SUCCESS',
    FAILED = 'FAILED',
    CANCELLED = 'CANCELLED',
}

function RobberySessions.rateOk(source)
    local now = GetGameTimer()
    local last = RobberySessions.lastEvent[source] or 0
    if now - last < (SunsetRobbery.RateLimitMs or 220) then return false end
    RobberySessions.lastEvent[source] = now
    return true
end

function RobberySessions.get(source)
    return RobberySessions.bySource[source]
end

function RobberySessions.canStart(source, locationId, skipGates)
    local loc = SunsetRobbery.Locations[locationId]
    if not loc then return nil, 'Unknown location' end
    if RobberySessions.bySource[source] then return nil, 'You are already in a robbery' end
    if RobberySessions.locationBusy[locationId] then return nil, 'This store is already being hit' end
    if skipGates or RobberyAdapter.isAdmin(source) then return loc end
    if RobberyAdapter.isDead(source) then return nil, 'You cannot start a robbery right now' end
    if RobberyAdapter.isPoliceRestricted(source) then return nil, 'You cannot rob on duty as law enforcement' end
    local now = os.time()
    local pcd = RobberySessions.playerCd[source] or 0
    if now < pcd then return nil, ('You must wait %d min before another robbery'):format(math.ceil((pcd - now) / 60)) end
    local lcd = RobberySessions.locationCd[locationId] or 0
    if now < lcd then return nil, ('This store is on lockdown for %d min'):format(math.ceil((lcd - now) / 60)) end
    local needPolice = loc.minPolice or SunsetRobbery.MinPolice
    if RobberyAdapter.policeCount() < needPolice then
        return nil, ('Need at least %d police on duty'):format(needPolice)
    end
    if not RobberyAdapter.hasItem(source, SunsetRobbery.RequiredItem, 1) then
        return nil, 'You are missing the required tool'
    end
    local cost = SunsetRobbery.RobPointsToStart or 1
    if RobberyAdapter.getRobPoints(source) < cost then
        return nil, ('You need %d rob point(s). Earn them at payday.'):format(cost)
    end
    return loc
end

local function randomHack()
    local layouts = {
        {
            nodes = {
                { id = 'SRC', kind = 'source', x = 10, y = 50, label = 'SOURCE' },
                { id = 'A', kind = 'normal', x = 30, y = 28, label = '04-A' },
                { id = 'B', kind = 'normal', x = 30, y = 72, label = '04-B' },
                { id = 'L', kind = 'locked', x = 50, y = 16, label = 'LOCK' },
                { id = 'T', kind = 'timed', x = 52, y = 50, label = 'RELAY' },
                { id = 'C', kind = 'corrupted', x = 50, y = 84, label = 'CORR' },
                { id = 'D', kind = 'decoy', x = 72, y = 30, label = 'GHOST' },
                { id = 'E', kind = 'normal', x = 74, y = 70, label = '08-E' },
                { id = 'TGT', kind = 'target', x = 92, y = 50, label = 'CORE' },
            },
            path = { 'SRC', 'A', 'T', 'E', 'TGT' },
        },
        {
            nodes = {
                { id = 'SRC', kind = 'source', x = 10, y = 50, label = 'SOURCE' },
                { id = 'A', kind = 'normal', x = 32, y = 32, label = '11-A' },
                { id = 'B', kind = 'timed', x = 32, y = 68, label = '11-B' },
                { id = 'C', kind = 'normal', x = 54, y = 50, label = 'RELAY' },
                { id = 'D', kind = 'decoy', x = 56, y = 18, label = 'GHOST' },
                { id = 'E', kind = 'corrupted', x = 56, y = 82, label = 'CORR' },
                { id = 'F', kind = 'normal', x = 76, y = 50, label = '12-F' },
                { id = 'TGT', kind = 'target', x = 92, y = 50, label = 'CORE' },
            },
            path = { 'SRC', 'B', 'C', 'F', 'TGT' },
        },
    }
    local layout = layouts[math.random(1, #layouts)]
    return {
        nodes = layout.nodes,
        path = layout.path,
        index = 1,
        mistakes = 0,
        startedAt = nil,
        timeLimit = SunsetRobbery.HackTimeSec,
    }
end

function RobberySessions.begin(source, locationId, skipGates)
    local loc, err = RobberySessions.canStart(source, locationId, skipGates)
    if not loc then return nil, err end
    if not skipGates and not RobberyAdapter.isAdmin(source) then
        if not RobberyAdapter.takeRobPoints(source, SunsetRobbery.RobPointsToStart or 1) then
            return nil, 'Not enough rob points'
        end
    end
    local session = {
        id = ('%s_%d_%d'):format(locationId, source, os.time()),
        source = source,
        locationId = locationId,
        location = loc,
        stage = STATES.HACKING,
        startedAt = os.time(),
        hack = randomHack(),
        hackResult = nil,
        policeAlerted = false,
        alertAt = nil,
        escalateAt = nil,
        vehicleAt = nil,
        bagUsed = 0,
        bagCap = SunsetRobbery.BagCapacity,
        estimated = 0,
        displays = {},
        generatedLoot = {},
        firstSmashAt = nil,
    }
    for _, display in ipairs(loc.displays) do
        session.displays[display.id] = { smashed = false, items = nil }
    end
    RobberySessions.bySource[source] = session
    RobberySessions.locationBusy[locationId] = source
    return session
end

function RobberySessions.setStage(session, stage)
    session.stage = stage
end

function RobberySessions.fail(source, reason)
    local session = RobberySessions.bySource[source]
    if not session then return end
    session.stage = STATES.FAILED
    RobberySessions.locationBusy[session.locationId] = nil
    RobberySessions.bySource[source] = nil
    RobberySessions.playerCd[source] = os.time() + (SunsetRobbery.PlayerCooldownSec or 1800)
    RobberySessions.locationCd[session.locationId] = os.time() + (SunsetRobbery.LocationCooldownSec or 2700)
    TriggerClientEvent('sunset:robbery:ended', source, { ok = false, reason = reason or 'Robbery failed' })
end

function RobberySessions.success(source)
    local session = RobberySessions.bySource[source]
    if not session then return end
    session.stage = STATES.SUCCESS
    RobberySessions.locationBusy[session.locationId] = nil
    RobberySessions.bySource[source] = nil
    RobberySessions.playerCd[source] = os.time() + (SunsetRobbery.PlayerCooldownSec or 1800)
    RobberySessions.locationCd[session.locationId] = os.time() + (SunsetRobbery.LocationCooldownSec or 2700)
    if not session.wantedIssued then
        RobberyAdapter.issueWanted(source, 'robbery')
    end
    TriggerClientEvent('sunset:robbery:ended', source, {
        ok = true,
        reason = 'Loot secured. Find a fence to sell.',
        bagUsed = session.bagUsed,
        estimated = session.estimated,
    })
end

function RobberySessions.cancel(source, reason)
    local session = RobberySessions.bySource[source]
    if not session then return end
    session.stage = STATES.CANCELLED
    RobberySessions.locationBusy[session.locationId] = nil
    RobberySessions.bySource[source] = nil
    TriggerClientEvent('sunset:robbery:ended', source, { ok = false, reason = reason or 'Robbery cancelled' })
end

function RobberySessions.resetCooldowns(source, locationId)
    if source then RobberySessions.playerCd[source] = 0 end
    if locationId then RobberySessions.locationCd[locationId] = 0 end
end

function RobberySessions.hud(session)
    local delay = 0
    if session.alertAt then
        delay = math.max(0, session.alertAt - os.time())
    end
    return {
        stage = session.stage,
        bagUsed = session.bagUsed,
        bagCap = session.bagCap,
        estimated = session.estimated,
        response = delay,
        policeAlerted = session.policeAlerted,
        location = session.location.label,
        hackResult = session.hackResult,
        escapeRadius = SunsetRobbery.EscapeRadius,
    }
end
