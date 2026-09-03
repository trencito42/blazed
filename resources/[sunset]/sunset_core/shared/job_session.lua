Sunset = Sunset or {}

--- Civilian job session state machine contract.
--- Consumers: sunset_jobs, sunset_ui (/jobs panel), sunset_dispatch (optional linkage).
Sunset.JobSession = Sunset.JobSession or {}

Sunset.JobSession.Status = {
    IDLE = 'IDLE',
    STARTING = 'STARTING',
    ACTIVE = 'ACTIVE',
    RETURNING = 'RETURNING',
    COMPLETED = 'COMPLETED',
    FAILED = 'FAILED',
    CANCELLED = 'CANCELLED',
}

Sunset.JobSession.Kind = {
    trucker = 'trucker',
    garbage = 'garbage',
    courier = 'courier',
    fisherman = 'fisherman',
    mechanic = 'mechanic',
}

Sunset.JobSession.Config = {
    maxActiveSessionsPerPlayer = 1,
    payoutOnCompleteOnly = true,
}

local TERMINAL = {
    COMPLETED = true,
    FAILED = true,
    CANCELLED = true,
    IDLE = true,
}

local TRANSITIONS = {
    IDLE = { STARTING = true },
    STARTING = { ACTIVE = true, FAILED = true, CANCELLED = true },
    ACTIVE = { RETURNING = true, COMPLETED = true, FAILED = true, CANCELLED = true },
    RETURNING = { COMPLETED = true, FAILED = true, CANCELLED = true },
}

function Sunset.JobSession.IsTerminalStatus(status)
    return TERMINAL[status] == true
end

function Sunset.JobSession.IsActive(status)
    return status == 'STARTING' or status == 'ACTIVE' or status == 'RETURNING'
end

function Sunset.JobSession.CanTransition(fromStatus, toStatus)
    if not fromStatus or not toStatus then return false end
    if fromStatus == toStatus then return true end
    if TERMINAL[fromStatus] then return false end
    local allowed = TRANSITIONS[fromStatus]
    return allowed and allowed[toStatus] == true
end

function Sunset.JobSession.IsValidKind(kind)
    return kind ~= nil and Sunset.JobSession.Kind[kind] ~= nil
end

function Sunset.JobSession.Serialize(session)
    if not session then return nil end
    return {
        jobId = session.jobId,
        state = session.state,
        data = session.data or {},
        startedAt = session.startedAt,
        isActive = Sunset.JobSession.IsActive(session.state),
    }
end

-- Alias for jobs_config consumers
Sunset.JobStates = Sunset.JobSession.Status
Sunset.IsTerminalJobState = Sunset.JobSession.IsTerminalStatus
Sunset.IsActiveJobState = Sunset.JobSession.IsActive
