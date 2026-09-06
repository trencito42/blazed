RobberySessions = {
    bySource = {},
    locationBusy = {},
    playerCd = {},
    locationCd = {},
    lastEvent = {},
    starting = {},
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

local function setDoors(session, unlocked)
    TriggerClientEvent('sunset:robbery:doorState', -1, session.locationId, unlocked == true)
end

local function scheduleDoorLock(session)
    local locationId = session.locationId
    SetTimeout(15000, function()
        if not RobberySessions.locationBusy[locationId] then
            TriggerClientEvent('sunset:robbery:doorState', -1, locationId, false)
        end
    end)
end

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
    if RobberySessions.locationBusy[locationId] and RobberySessions.locationBusy[locationId] ~= source then
        return nil, 'This store is already being hit'
    end
    local char = RobberyAdapter.getCharacter(source)
    if not char or not tonumber(char.id) then return nil, 'Your character is not loaded. Reconnect and try again.' end
    if skipGates or RobberyAdapter.isAdmin(source) then return loc, nil, char end
    if RobberyAdapter.isDead(source) then return nil, 'You cannot start a robbery right now' end
    if RobberyAdapter.isPoliceRestricted(source) then return nil, 'Law enforcement cannot commit robberies' end
    if RobberyAdapter.isJailed(source) then return nil, 'You cannot start a robbery while in custody' end
    if RobberyAdapter.isWanted(source) then return nil, 'You cannot start a robbery while wanted' end
    local now = os.time()
    local characterId = tonumber(char.id)
    local storedPlayerCd = RobberyAdapter.getCooldown('character', characterId)
    if storedPlayerCd == nil then return nil, 'The robbery ledger is unavailable. Try again shortly.' end
    local pcd = math.max(RobberySessions.playerCd[characterId] or 0, storedPlayerCd)
    RobberySessions.playerCd[characterId] = pcd
    if now < pcd then return nil, ('You must wait %d min before another robbery'):format(math.ceil((pcd - now) / 60)) end
    local storedLocationCd = RobberyAdapter.getCooldown('location', locationId)
    if storedLocationCd == nil then return nil, 'The robbery ledger is unavailable. Try again shortly.' end
    local lcd = math.max(RobberySessions.locationCd[locationId] or 0, storedLocationCd)
    RobberySessions.locationCd[locationId] = lcd
    if now < lcd then return nil, ('This store is on lockdown for %d min'):format(math.ceil((lcd - now) / 60)) end
    local needPolice = loc.minPolice or SunsetRobbery.MinPolice
    if RobberyAdapter.policeCount() < needPolice then
        return nil, ('Need at least %d police on duty'):format(needPolice)
    end
    if not RobberyAdapter.hasItem(source, SunsetRobbery.RequiredItem, 1) then
        local def = Sunset.Items and Sunset.Items[SunsetRobbery.RequiredItem]
        return nil, ('You need a %s in your inventory to bypass the store security.'):format(
            (def and def.label) or SunsetRobbery.RequiredItem or 'required tool')
    end
    local cost = SunsetRobbery.RobPointsToStart or 1
    if RobberyAdapter.getRobPoints(source) < cost then
        return nil, ('You need %d rob point(s). Earn them at payday.'):format(cost)
    end
    return loc, nil, char
end

local function shuffle(values)
    for i = #values, 2, -1 do
        local j = math.random(i)
        values[i], values[j] = values[j], values[i]
    end
    return values
end

local function nodeId(column, row)
    return ('C%dR%d'):format(column, row)
end

-- Generate a fresh circuit on every attempt. The client receives the circuit and
-- the requested channel, but never the solution path; all progress is verified here.
local function randomHack()
    local columns, rows = 6, 4
    local pathRows = { math.random(rows) }
    for column = 2, columns do
        local previous = pathRows[column - 1]
        local candidates = {}
        for row = math.max(1, previous - 1), math.min(rows, previous + 1) do
            candidates[#candidates + 1] = row
        end
        pathRows[column] = candidates[math.random(#candidates)]
    end

    local pathKinds = shuffle({ 'normal', 'locked', 'timed', 'normal' })
    local nodes, byId, edges = {}, {}, {}
    for column = 1, columns do
        for row = 1, rows do
            local id = nodeId(column, row)
            local onPath = pathRows[column] == row
            local kind
            if onPath and column == 1 then
                kind = 'source'
            elseif onPath and column == columns then
                kind = 'target'
            elseif onPath then
                kind = pathKinds[column - 1]
            else
                local roll = math.random(100)
                kind = roll <= 18 and 'corrupted'
                    or (roll <= 40 and 'decoy'
                        or (roll <= 50 and 'locked' or (roll <= 60 and 'timed' or 'normal')))
            end
            local node = {
                id = id,
                kind = kind,
                x = 7 + ((column - 1) * 17.2),
                y = 13 + ((row - 1) * 24.5),
                label = kind == 'source' and 'SOURCE'
                    or (kind == 'target' and 'CORE' or ('%02d-%s'):format(column, string.char(64 + row))),
                frequency = math.random(1, 3),
            }
            nodes[#nodes + 1] = node
            byId[id] = node
        end
    end

    -- Each active node connects only to the neighbouring row in the next bank.
    -- Candidate frequencies are unique, so the requested channel is a real clue.
    for column = 1, columns - 1 do
        for row = 1, rows do
            for nextRow = math.max(1, row - 1), math.min(rows, row + 1) do
                edges[#edges + 1] = { from = nodeId(column, row), to = nodeId(column + 1, nextRow) }
            end
        end
        local currentRow = pathRows[column]
        local frequencies = shuffle({ 1, 2, 3 })
        local cursor = 1
        for nextRow = math.max(1, currentRow - 1), math.min(rows, currentRow + 1) do
            byId[nodeId(column + 1, nextRow)].frequency = frequencies[cursor]
            cursor = cursor + 1
        end
    end

    local path = {}
    for column = 1, columns do path[column] = nodeId(column, pathRows[column]) end

    return {
        nodes = nodes,
        nodeById = byId,
        edges = edges,
        path = path,
        index = 1,
        trace = 0,
        mistakes = 0,
        startedAt = nil,
        lastCorrectAt = nil,
        lockNode = nil,
        lockExpiresAt = nil,
        burstDeadline = nil,
        timeLimit = SunsetRobbery.HackTimeSec,
    }
end

function RobberySessions.hackPublic(hack)
    local nextId = hack.path[hack.index + 1]
    local nextNode = nextId and hack.nodeById[nextId] or nil
    return {
        nodes = hack.nodes,
        edges = hack.edges,
        sourceId = hack.path[1],
        currentNode = hack.path[hack.index],
        signal = nextNode and nextNode.frequency or nil,
        timeLimit = hack.timeLimit,
    }
end

function RobberySessions.begin(source, locationId, skipGates)
    if RobberySessions.starting[source] or RobberySessions.bySource[source] then
        return nil, 'You are already starting a robbery'
    end
    if RobberySessions.locationBusy[locationId] then return nil, 'This store is already being hit' end
    RobberySessions.starting[source] = true
    RobberySessions.locationBusy[locationId] = source

    local loc, err, char = RobberySessions.canStart(source, locationId, skipGates)
    if not loc then
        RobberySessions.starting[source] = nil
        if RobberySessions.locationBusy[locationId] == source then RobberySessions.locationBusy[locationId] = nil end
        return nil, err
    end
    local liveCharacter = RobberyAdapter.getCharacter(source)
    if not GetPlayerName(source) or not liveCharacter or tonumber(liveCharacter.id) ~= tonumber(char.id) then
        RobberySessions.starting[source] = nil
        if RobberySessions.locationBusy[locationId] == source then RobberySessions.locationBusy[locationId] = nil end
        return nil, 'Your connection changed while the robbery was starting. Try again.'
    end
    if not skipGates and not RobberyAdapter.isAdmin(source) then
        if not RobberyAdapter.takeRobPoints(source, SunsetRobbery.RobPointsToStart or 1) then
            RobberySessions.starting[source] = nil
            if RobberySessions.locationBusy[locationId] == source then RobberySessions.locationBusy[locationId] = nil end
            return nil, 'Not enough rob points'
        end
    end
    local session = {
        id = ('%s_%d_%d_%06d'):format(locationId, source, os.time(), math.random(0, 999999)),
        source = source,
        characterId = char and tonumber(char.id) or nil,
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
    if not RobberyAdapter.startRun(session) then
        if not skipGates and not RobberyAdapter.isAdmin(source) then
            RobberyAdapter.refundRobPoints(source, SunsetRobbery.RobPointsToStart or 1)
        end
        RobberySessions.starting[source] = nil
        if RobberySessions.locationBusy[locationId] == source then RobberySessions.locationBusy[locationId] = nil end
        return nil, 'The robbery ledger is unavailable. Your rob point was returned; try again.'
    end
    liveCharacter = RobberyAdapter.getCharacter(source)
    if not GetPlayerName(source) or not liveCharacter or tonumber(liveCharacter.id) ~= session.characterId then
        RobberyAdapter.finishRun(session, 'cancelled')
        RobberySessions.starting[source] = nil
        if RobberySessions.locationBusy[locationId] == source then RobberySessions.locationBusy[locationId] = nil end
        return nil, 'Your connection changed while the robbery was starting. Reconnect and try again.'
    end
    RobberySessions.bySource[source] = session
    RobberySessions.locationBusy[locationId] = source
    RobberySessions.starting[source] = nil
    setDoors(session, true)
    RobberyAdapter.audit(session, 'started', { skipGates = skipGates == true })
    return session
end

function RobberySessions.setStage(session, stage)
    session.stage = stage
end

function RobberySessions.fail(source, reason)
    local session = RobberySessions.bySource[source]
    if not session then return end
    session.stage = STATES.FAILED
    local removed, cleanupOk = RobberyAdapter.removeRobberyLoot(source, session.characterId, session.id)
    if cleanupOk then RobberyAdapter.finishRun(session, 'failed') end
    RobberySessions.locationBusy[session.locationId] = nil
    RobberySessions.bySource[source] = nil
    local playerExpiry = os.time() + (SunsetRobbery.PlayerCooldownSec or 1800)
    local locationExpiry = os.time() + (SunsetRobbery.LocationCooldownSec or 2700)
    RobberySessions.playerCd[session.characterId] = playerExpiry
    RobberySessions.locationCd[session.locationId] = locationExpiry
    RobberyAdapter.setCooldown('character', session.characterId, playerExpiry)
    RobberyAdapter.setCooldown('location', session.locationId, locationExpiry)
    RobberyAdapter.audit(session, 'failed', { reason = reason, removedLoot = removed, cleanupOk = cleanupOk })
    scheduleDoorLock(session)
    TriggerClientEvent('sunset:robbery:ended', source, { ok = false, reason = reason or 'Robbery failed' })
end

function RobberySessions.success(source)
    local session = RobberySessions.bySource[source]
    if not session then return end
    session.stage = STATES.SUCCESS
    RobberyAdapter.finishRun(session, 'success')
    RobberySessions.locationBusy[session.locationId] = nil
    RobberySessions.bySource[source] = nil
    local playerExpiry = os.time() + (SunsetRobbery.PlayerCooldownSec or 1800)
    local locationExpiry = os.time() + (SunsetRobbery.LocationCooldownSec or 2700)
    RobberySessions.playerCd[session.characterId] = playerExpiry
    RobberySessions.locationCd[session.locationId] = locationExpiry
    RobberyAdapter.setCooldown('character', session.characterId, playerExpiry)
    RobberyAdapter.setCooldown('location', session.locationId, locationExpiry)
    if not session.wantedIssued then
        local delay = math.max(0, (session.alertAt or os.time()) - os.time())
        if delay == 0 then
            session.wantedIssued = true
            if not session.policeAlerted then
                session.policeAlerted = true
                RobberyPolice.alert(session, 'first')
            end
            RobberyAdapter.issueWanted(source, 'robbery')
        else
            local expectedCharacter = session.characterId
            SetTimeout(delay * 1000, function()
                local current = RobberyAdapter.getCharacter(source)
                local sameCharacter = current and tonumber(current.id) == expectedCharacter
                if not sameCharacter then session.source = 0 end
                if not session.policeAlerted then
                    session.policeAlerted = true
                    RobberyPolice.alert(session, 'first')
                end
                if sameCharacter then
                    session.wantedIssued = true
                    RobberyAdapter.issueWanted(source, 'robbery')
                end
            end)
        end
    end
    RobberyAdapter.audit(session, 'success', { hackResult = session.hackResult })
    scheduleDoorLock(session)
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
    local removed, cleanupOk = RobberyAdapter.removeRobberyLoot(source, session.characterId, session.id)
    if cleanupOk then RobberyAdapter.finishRun(session, 'cancelled') end
    RobberySessions.locationBusy[session.locationId] = nil
    RobberySessions.bySource[source] = nil
    RobberyAdapter.audit(session, 'cancelled', { reason = reason, removedLoot = removed, cleanupOk = cleanupOk })
    scheduleDoorLock(session)
    TriggerClientEvent('sunset:robbery:ended', source, { ok = false, reason = reason or 'Robbery cancelled' })
end

function RobberySessions.resetCooldowns(source, locationId)
    if source then
        local char = RobberyAdapter.getCharacter(source)
        local characterId = char and tonumber(char.id) or nil
        if characterId then
            RobberySessions.playerCd[characterId] = 0
            RobberyAdapter.clearCooldown('character', characterId)
        end
    end
    if locationId then
        RobberySessions.locationCd[locationId] = 0
        RobberyAdapter.clearCooldown('location', locationId)
    end
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
