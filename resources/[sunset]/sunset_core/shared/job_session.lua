Sunset = Sunset or {}

--- Civilian and faction job session state machine contract.
--- Consumers: sunset_jobs (Agent Jobs), sunset_ui (job HUD), sunset_dispatch (optional linkage).
Sunset.JobSession = Sunset.JobSession or {}

--- Session lifecycle — separate from dispatch CallStatus.
Sunset.JobSession.Status = {
    idle = 'idle',
    briefing = 'briefing',
    active = 'active',
    completing = 'completing',
    completed = 'completed',
    failed = 'failed',
    abandoned = 'abandoned',
}

--- Job kinds that use session loops (civilian first; factions may extend later).
Sunset.JobSession.Kind = {
    trucker = 'trucker',
    fisherman = 'fisherman',
    garbage = 'garbage',
    courier = 'courier',
}

Sunset.JobSession.Config = {
    maxActiveSessionsPerPlayer = 1,
    abandonCooldownSeconds = 30,
    payoutOnCompleteOnly = true,
}

local TERMINAL = {
    [Sunset.JobSession.Status.completed] = true,
    [Sunset.JobSession.Status.failed] = true,
    [Sunset.JobSession.Status.abandoned] = true,
    [Sunset.JobSession.Status.idle] = true,
}

local TRANSITIONS = {
    [Sunset.JobSession.Status.idle] = {
        [Sunset.JobSession.Status.briefing] = true,
    },
    [Sunset.JobSession.Status.briefing] = {
        [Sunset.JobSession.Status.active] = true,
        [Sunset.JobSession.Status.abandoned] = true,
        [Sunset.JobSession.Status.failed] = true,
    },
    [Sunset.JobSession.Status.active] = {
        [Sunset.JobSession.Status.completing] = true,
        [Sunset.JobSession.Status.abandoned] = true,
        [Sunset.JobSession.Status.failed] = true,
    },
    [Sunset.JobSession.Status.completing] = {
        [Sunset.JobSession.Status.completed] = true,
        [Sunset.JobSession.Status.failed] = true,
    },
}

function Sunset.JobSession.IsTerminalStatus(status)
    return TERMINAL[status] == true
end

function Sunset.JobSession.IsActive(status)
    return status == Sunset.JobSession.Status.briefing
        or status == Sunset.JobSession.Status.active
        or status == Sunset.JobSession.Status.completing
end

function Sunset.JobSession.CanTransition(fromStatus, toStatus)
    if not fromStatus or not toStatus then return false end
    if fromStatus == toStatus then return true end
    local allowed = TRANSITIONS[fromStatus]
    return allowed and allowed[toStatus] == true
end

function Sunset.JobSession.IsValidKind(kind)
    return kind ~= nil and Sunset.JobSession.Kind[kind] ~= nil
end

function Sunset.JobSession.IsValidStatus(status)
    return status ~= nil and Sunset.JobSession.Status[status] ~= nil
end

--- Default empty session for a character.
function Sunset.JobSession.New(characterId, kind)
    return {
        characterId = characterId,
        kind = kind,
        status = Sunset.JobSession.Status.idle,
        stage = nil,
        startedAt = nil,
        updatedAt = nil,
        waypointIndex = 0,
        payload = {},
    }
end

--- Snapshot for client HUD / NUI (Agent UI consumes this shape).
function Sunset.JobSession.Serialize(session)
    if not session then return nil end
    return {
        characterId = session.characterId,
        kind = session.kind,
        status = session.status,
        stage = session.stage,
        waypointIndex = session.waypointIndex or 0,
        payload = session.payload or {},
        startedAt = session.startedAt,
        updatedAt = session.updatedAt,
        isActive = Sunset.JobSession.IsActive(session.status),
    }
end
