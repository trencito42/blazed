Sunset = Sunset or {}

--- Unified service dispatch contract (taxi, medic, fire, mechanic).
Sunset.Dispatch = Sunset.Dispatch or {}

Sunset.Dispatch.States = {
    OPEN = 'OPEN',
    ASSIGNED = 'ASSIGNED',
    EN_ROUTE = 'EN_ROUTE',
    ARRIVED = 'ARRIVED',
    IN_PROGRESS = 'IN_PROGRESS',
    COMPLETED = 'COMPLETED',
    CANCELLED = 'CANCELLED',
}

Sunset.Dispatch.ServiceTypes = {
    taxi = {
        label = 'Taxi',
        factionTypes = { 'transport' },
        providerFactions = { 'taxi' },
    },
    medic = {
        label = 'Medic',
        factionTypes = { 'ems' },
        providerFactions = { 'medic' },
    },
    fire = {
        label = 'Fire Rescue',
        factionTypes = { 'fire_rescue' },
        providerFactions = { 'lsfd' },
    },
    mechanic = {
        label = 'Mechanic',
        factionTypes = { 'mechanic' },
        providerFactions = { 'mechanic' },
    },
}

Sunset.Dispatch.rateLimits = {
    createMs = 30000,
    acceptMs = 2000,
    cancelMs = 5000,
    listMs = 1500,
}

Sunset.Dispatch.callTimeoutSec = 600
Sunset.Dispatch.maxActiveCallsPerCaller = 1

--- Backward-compat aliases for integration consumers.
Sunset.Dispatch.CallStatus = {
    pending = Sunset.Dispatch.States.OPEN,
    accepted = Sunset.Dispatch.States.ASSIGNED,
    en_route = Sunset.Dispatch.States.EN_ROUTE,
    on_scene = Sunset.Dispatch.States.ARRIVED,
    completed = Sunset.Dispatch.States.COMPLETED,
    cancelled = Sunset.Dispatch.States.CANCELLED,
}

Sunset.Dispatch.CallType = {
    taxi_ride = 'taxi',
    ems_medical = 'medic',
    fire = 'fire',
    mechanic_roadside = 'mechanic',
    civilian_distress = 'medic',
    police_backup = 'medic',
}

local TERMINAL = {
    [Sunset.Dispatch.States.COMPLETED] = true,
    [Sunset.Dispatch.States.CANCELLED] = true,
}

local ACTIVE = {
    [Sunset.Dispatch.States.OPEN] = true,
    [Sunset.Dispatch.States.ASSIGNED] = true,
    [Sunset.Dispatch.States.EN_ROUTE] = true,
    [Sunset.Dispatch.States.ARRIVED] = true,
    [Sunset.Dispatch.States.IN_PROGRESS] = true,
}

local TRANSITIONS = {
    [Sunset.Dispatch.States.OPEN] = {
        [Sunset.Dispatch.States.ASSIGNED] = true,
        [Sunset.Dispatch.States.CANCELLED] = true,
    },
    [Sunset.Dispatch.States.ASSIGNED] = {
        [Sunset.Dispatch.States.EN_ROUTE] = true,
        [Sunset.Dispatch.States.CANCELLED] = true,
        [Sunset.Dispatch.States.OPEN] = true,
    },
    [Sunset.Dispatch.States.EN_ROUTE] = {
        [Sunset.Dispatch.States.ARRIVED] = true,
        [Sunset.Dispatch.States.CANCELLED] = true,
        [Sunset.Dispatch.States.OPEN] = true,
    },
    [Sunset.Dispatch.States.ARRIVED] = {
        [Sunset.Dispatch.States.IN_PROGRESS] = true,
        [Sunset.Dispatch.States.CANCELLED] = true,
    },
    [Sunset.Dispatch.States.IN_PROGRESS] = {
        [Sunset.Dispatch.States.COMPLETED] = true,
        [Sunset.Dispatch.States.CANCELLED] = true,
    },
}

function Sunset.Dispatch.IsTerminalState(state)
    return TERMINAL[state] == true
end

function Sunset.Dispatch.IsTerminalStatus(status)
    return Sunset.Dispatch.IsTerminalState(status)
end

function Sunset.Dispatch.IsActiveState(state)
    return ACTIVE[state] == true
end

function Sunset.Dispatch.NormalizeServiceType(serviceType)
    if not serviceType or type(serviceType) ~= 'string' then return nil end
    local key = string.lower(serviceType)
    if Sunset.Dispatch.ServiceTypes[key] then return key end
    local mapped = Sunset.Dispatch.CallType[key] or Sunset.Dispatch.CallType[serviceType]
    if mapped and Sunset.Dispatch.ServiceTypes[mapped] then return mapped end
    return nil
end

function Sunset.Dispatch.GetServiceConfig(serviceType)
    local key = Sunset.Dispatch.NormalizeServiceType(serviceType)
    if not key then return nil end
    return Sunset.Dispatch.ServiceTypes[key], key
end

function Sunset.Dispatch.ProviderFactionMatches(serviceType, factionId)
    local cfg = Sunset.Dispatch.GetServiceConfig(serviceType)
    if not cfg or not factionId then return false end
    for _, id in ipairs(cfg.providerFactions or {}) do
        if id == factionId then return true end
    end
    local fType = Sunset.GetFactionType(factionId)
    for _, t in ipairs(cfg.factionTypes or {}) do
        if t == fType then return true end
    end
    return false
end

function Sunset.Dispatch.AllowedStateTransition(fromState, toState)
    if fromState == toState then return true end
    if Sunset.Dispatch.IsTerminalState(fromState) then return false end
    local allowed = TRANSITIONS[fromState]
    return allowed and allowed[toState] == true
end

function Sunset.Dispatch.CanTransition(fromState, toState)
    return Sunset.Dispatch.AllowedStateTransition(fromState, toState)
end

function Sunset.Dispatch.EncodeCoords(coords)
    if not coords then return { x = 0.0, y = 0.0, z = 0.0 } end
    if type(coords) == 'vector3' or type(coords) == 'vector4' then
        return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
    end
    return {
        x = (coords.x or coords[1] or 0.0) + 0.0,
        y = (coords.y or coords[2] or 0.0) + 0.0,
        z = (coords.z or coords[3] or 0.0) + 0.0,
    }
end

function Sunset.Dispatch.SerializeCall(call)
    if not call then return nil end
    return {
        id = call.id,
        callType = call.callType or call.serviceType,
        serviceType = call.callType or call.serviceType,
        status = call.status or call.state,
        state = call.status or call.state,
        callerCharacterId = call.callerCharacterId or call.callerCharId,
        responderCharacterId = call.responderCharacterId or call.providerCharId,
        coords = call.coords,
        description = call.description,
        metadata = call.metadata,
        callerName = call.callerName,
        responderName = call.responderName or call.providerName,
        createdAt = call.createdAt,
    }
end
