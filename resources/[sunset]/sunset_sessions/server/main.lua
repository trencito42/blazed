-- ============================================================
--  sunset_sessions — Canonical gameplay session service
--  Design: docs/architecture/GAMEPLAY_SESSIONS.md
--  Rules: only the server transitions state; rewards are granted
--  exactly once via MarkRewardPending/CommitReward; every session
--  declares a reconnect policy and an activity cleanup handler.
-- ============================================================

local Sessions = {}          -- [sessionId] = session
local ByChar = {}            -- [charId] = sessionId
local BySource = {}          -- [source] = sessionId
local Activities = {}        -- [activity] = definition
local idCounter = 0

-- Terminal states are absorbing (mirrors shared/job_session.lua semantics).
local STATES = {
    IDLE = true, REQUESTED = true, STARTING = true, ACTIVE = true,
    OBJECTIVE_COMPLETE = true, REWARD_PENDING = true, COMPLETED = true,
    CANCELLED = true, FAILED = true, TIMED_OUT = true,
    PLAYER_DROPPED = true, ENTITY_LOST = true,
}
local TERMINAL = {
    COMPLETED = true, CANCELLED = true, FAILED = true,
    TIMED_OUT = true, PLAYER_DROPPED = true, ENTITY_LOST = true,
}

local function log(sessionId, msg, ...)
    print(('[sessions] %s | %s'):format(tostring(sessionId), msg:format(...)))
end

local function newSessionId(activity, charId)
    idCounter = idCounter + 1
    -- Unpredictable component: server time + counter + random.
    return ('%s-%d-%d-%d'):format(activity, charId or 0, os.time(), math.random(100000, 999999)) .. '-' .. idCounter
end

-- ------------------------------------------------------------
-- Activity registry
-- ------------------------------------------------------------
-- Definition fields:
--   states: optional custom transition whitelist
--   Cleanup/timeout/reconnect handlers CANNOT be Lua functions when
--   registered from another resource: FiveM serializes export arguments
--   (msgpack) and functions do not survive the boundary. Use EVENT NAMES:
--     onEndEvent       -> TriggerEvent(name, session, endState)   REQUIRED*
--     onTimeoutEvent   -> TriggerEvent(name, session)
--     onReconnectEvent -> TriggerEvent(name, session, newSource)
--   (*internal same-resource registrations may pass onEnd as a function;
--   cross-resource registrations must provide onEndEvent.)
--   reconnect: 'ABANDON' | 'SUSPEND' | 'PERSIST' (default ABANDON)
function RegisterActivity(name, def)
    if type(name) ~= 'string' or type(def) ~= 'table' then return false end
    if type(def.onEnd) ~= 'function' and type(def.onEndEvent) ~= 'string' then
        print(('[sessions] activity %s rejected: onEndEvent (or internal onEnd) is required'):format(name))
        return false
    end
    Activities[name] = def
    return true
end
exports('RegisterActivity', RegisterActivity)

local function runActivityHook(def, kind, ...)
    -- kind: 'onEnd' | 'onTimeout' | 'onReconnect'
    local fn = def[kind]
    if type(fn) == 'function' then
        local ok, err = pcall(fn, ...)
        if not ok then print(('[sessions] %s hook error: %s'):format(kind, tostring(err))) end
        return
    end
    local eventName = def[kind .. 'Event']
    if type(eventName) == 'string' then
        TriggerEvent(eventName, ...)
    end
end

-- ------------------------------------------------------------
-- Session lifecycle
-- ------------------------------------------------------------
function CreateSession(opts)
    opts = type(opts) == 'table' and opts or {}
    local source = tonumber(opts.source)
    local charId = tonumber(opts.charId)
    local activity = tostring(opts.activity or '')
    if not source or not charId or not Activities[activity] then
        return nil, 'Invalid session parameters.'
    end
    if ByChar[charId] then
        local existing = Sessions[ByChar[charId]]
        if existing and not TERMINAL[existing.state] then
            return nil, 'You already have an active session.'
        end
    end
    -- [MULTI-PARTY] Optional extra participants (e.g. taxi passenger). Every
    -- participant is indexed in ByChar so central triggers (downed/jail/drop)
    -- end the session when ANY party becomes incapacitated.
    local participants = { charId }
    if type(opts.participants) == 'table' then
        for _, cid in ipairs(opts.participants) do
            cid = tonumber(cid)
            if cid and cid ~= charId then
                local existing = ByChar[cid] and Sessions[ByChar[cid]]
                if existing and not TERMINAL[existing.state] then
                    return nil, 'Another participant already has an active session.'
                end
                participants[#participants + 1] = cid
            end
        end
    end

    local id = newSessionId(activity, charId)
    local session = {
        id = id,
        charId = charId,
        source = source,
        activity = activity,
        state = 'STARTING',
        startedAt = os.time(),
        deadlineAt = opts.deadlineAt or (os.time() + (tonumber(opts.timeoutSec) or 1800)),
        entities = {},          -- [role] = netId
        entityModels = {},      -- [role] = model hash
        location = opts.location,
        progress = {},
        rewardState = 'none',   -- none | pending | granted
        rewardKey = opts.rewardKey,
        cancelReason = nil,
        reconnect = Activities[activity].reconnect or 'ABANDON',
        participants = participants, -- [charId,...] all parties in this session
        data = opts.data or {},
        ended = false,
    }
    Sessions[id] = session
    for _, cid in ipairs(participants) do ByChar[cid] = id end
    BySource[source] = id
    log(id, 'CREATED activity=%s source=%d char=%d parts=%d', activity, source, charId, #participants)
    TriggerClientEvent('sunset:sessions:started', source, {
        id = id, activity = activity, deadlineAt = session.deadlineAt, data = session.data,
    })
    return session
end
exports('CreateSession', CreateSession)

function GetSession(sessionId)
    return sessionId and Sessions[sessionId] or nil
end
exports('GetSession', GetSession)

function GetSessionBySource(source)
    local id = BySource[tonumber(source or 0)]
    local session = id and Sessions[id] or nil
    if session and TERMINAL[session.state] then return nil end
    return session
end
exports('GetSessionBySource', GetSessionBySource)

function GetSessionByChar(charId)
    local id = ByChar[tonumber(charId or 0)]
    local session = id and Sessions[id] or nil
    if session and TERMINAL[session.state] then return nil end
    return session
end

-- Central terminal handler: runs activity cleanup EXACTLY once.
local function finish(session, endState, reason)
    if session.ended then return end
    session.ended = true
    session.state = endState
    session.cancelReason = reason
    log(session.id, 'END state=%s reason=%s', endState, tostring(reason))

    local def = Activities[session.activity]
    runActivityHook(def, 'onEnd', session, endState)

    -- Notify EVERY online participant (not just the owner source).
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local ok, char = pcall(function() return exports.sunset_core:GetCharacter(src) end)
        if ok and char and char.id then
            for _, cid in ipairs(session.participants or {}) do
                if cid == char.id then
                    TriggerClientEvent('sunset:sessions:ended', src, {
                        id = session.id, state = endState, reason = reason,
                    })
                    break
                end
            end
        end
    end

    for _, cid in ipairs(session.participants or {}) do
        if ByChar[cid] == session.id then ByChar[cid] = nil end
    end
    if session.source then BySource[session.source] = nil end
    -- Keep the record briefly for late idempotency checks, then drop it.
    SetTimeout(60000, function() Sessions[session.id] = nil end)
end

function Transition(sessionId, newState, reason)
    local session = GetSession(sessionId)
    if not session then return false, 'Session not found' end
    if session.ended or TERMINAL[session.state] then return false, 'Session already ended' end
    if not STATES[newState] then return false, 'Invalid state' end

    if TERMINAL[newState] then
        finish(session, newState, reason)
        return true
    end
    local old = session.state
    session.state = newState
    log(sessionId, 'TRANSITION %s -> %s', old, newState)
    if GetPlayerName(session.source) then
        TriggerClientEvent('sunset:sessions:stateChanged', session.source, {
            id = sessionId, state = newState, data = session.data,
        })
    end
    return true
end
exports('Transition', Transition)

function CancelSession(sessionId, reason)
    return Transition(sessionId, 'CANCELLED', reason or 'cancelled')
end
exports('CancelSession', CancelSession)

function EndSession(sessionId, endState, reason)
    return Transition(sessionId, endState, reason)
end
exports('EndSession', EndSession)

-- ------------------------------------------------------------
-- Reward idempotency (INVARIANT S2/M5)
-- ------------------------------------------------------------
-- Activities MUST wrap payouts:
--   if not exports.sunset_sessions:MarkRewardPending(id) then return end
--   ...atomic payout...
--   exports.sunset_sessions:CommitReward(id)   (or FailReward to allow retry)
function MarkRewardPending(sessionId)
    local session = GetSession(sessionId)
    if not session then return false end
    if session.rewardState ~= 'none' then return false end
    session.rewardState = 'pending'
    return true
end
exports('MarkRewardPending', MarkRewardPending)

function CommitReward(sessionId)
    local session = GetSession(sessionId)
    if not session then return false end
    session.rewardState = 'granted'
    log(sessionId, 'REWARD granted')
    return true
end
exports('CommitReward', CommitReward)

function FailReward(sessionId)
    local session = GetSession(sessionId)
    if not session or session.rewardState ~= 'pending' then return false end
    session.rewardState = 'none'
    log(sessionId, 'REWARD rolled back to none (payout failed)')
    return true
end
exports('FailReward', FailReward)

-- ------------------------------------------------------------
-- Entity tracking
-- ------------------------------------------------------------
function SetEntity(sessionId, role, netId, model)
    local session = GetSession(sessionId)
    if not session then return false end
    session.entities[role] = tonumber(netId)
    if model then session.entityModels[role] = tonumber(model) end
    return true
end
exports('SetEntity', SetEntity)

function ResolveEntity(sessionId, role)
    local session = GetSession(sessionId)
    if not session then return nil end
    local netId = session.entities[role]
    if not netId then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    local expected = session.entityModels[role]
    if expected and GetEntityModel(ent) ~= expected then return nil end
    return ent
end
exports('ResolveEntity', ResolveEntity)

-- ------------------------------------------------------------
-- Admin diagnostics (observability)
-- ------------------------------------------------------------
function ListSessions()
    local out = {}
    for _, s in pairs(Sessions) do
        if not s.ended then
            out[#out + 1] = {
                id = s.id, activity = s.activity, state = s.state,
                charId = s.charId, source = s.source,
                rewardState = s.rewardState,
                ageSec = os.time() - s.startedAt,
                deadlineIn = s.deadlineAt - os.time(),
            }
        end
    end
    return out
end
exports('ListSessions', ListSessions)

-- ------------------------------------------------------------
-- Deadline monitor
-- ------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, session in pairs(Sessions) do
            if not session.ended and session.deadlineAt and now > session.deadlineAt then
                local def = Activities[session.activity]
                runActivityHook(def, 'onTimeout', session)
                finish(session, 'TIMED_OUT', 'deadline exceeded')
            end
        end
    end
end)

-- ------------------------------------------------------------
-- Central triggers (GAMEPLAY_SESSIONS.md §7)
-- ------------------------------------------------------------
local function cancelForSource(src, endState, reason)
    local session = GetSessionBySource(src)
    if not session then
        -- [MULTI-PARTY] Non-owner participants (e.g. taxi passenger) are not in
        -- BySource; look them up by character id so ANY party going downed/jailed
        -- ends the shared session.
        local ok, char = pcall(function() return exports.sunset_core:GetCharacter(src) end)
        if ok and char and char.id then
            session = GetSessionByChar(char.id)
        end
    end
    if session then
        finish(session, endState, reason)
    end
end

AddEventHandler('sunset:death:playerDowned', function(src)
    cancelForSource(tonumber(src), 'FAILED', 'player downed')
end)

-- [FIX] Client session cleanup used to call SetPlayerRoutingBucket locally
-- (server-only native -> nil on client). It now asks us to reset the bucket.
RegisterNetEvent('sunset:sessions:resetRoutingBucket', function()
    local src = source
    if GetResourceState('sunset_properties') == 'started' then
        pcall(function() exports.sunset_properties:LeaveProperty(src) end)
    end
    SetPlayerRoutingBucket(src, 0)
end)

AddEventHandler('sunset:faction:playerJailed', function(src)
    cancelForSource(tonumber(src), 'FAILED', 'player jailed')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local session = GetSessionBySource(src)
    if not session then
        -- [MULTI-PARTY] A participant (e.g. taxi passenger) dropping must also
        -- end the shared session under ABANDON policy.
        local ok, char = pcall(function() return exports.sunset_core:GetCharacter(src) end)
        if ok and char and char.id then session = GetSessionByChar(char.id) end
    end
    if not session then return end
    local policy = session.reconnect
    if policy == 'SUSPEND' or policy == 'PERSIST' then
        -- Keep the session but unbind the source; activity defines re-attach.
        BySource[src] = nil
        session.source = nil
        session.suspendedCharId = session.charId
        log(session.id, 'SUSPENDED on drop (policy=%s)', policy)
        -- Suspended sessions still expire at their deadline (monitor skips
        -- sourceless sessions for client events but finish() handles nil src).
    else
        finish(session, 'PLAYER_DROPPED', 'disconnected')
    end
end)

-- Re-attach suspended sessions on reconnect / character reselect.
AddEventHandler('sunset:server:characterSelected', function(src, charId)
    charId = tonumber(charId)
    if not charId then return end
    local id = ByChar[charId]
    local session = id and Sessions[id] or nil
    if not session or session.ended then return end
    if session.source == nil and (session.reconnect == 'SUSPEND' or session.reconnect == 'PERSIST') then
        local def = Activities[session.activity]
        session.source = src
        BySource[src] = id
        runActivityHook(def, 'onReconnect', session, src)
        log(id, 'REATTACHED source=%d', src)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- INVARIANT S8: a restart cannot leave players frozen/stuck. Cancel every
    -- live session; activity onEnd handlers run their server-side cleanup.
    for _, session in pairs(Sessions) do
        if not session.ended then
            finish(session, 'CANCELLED', 'resource stopping')
        end
    end
end)

print('^2[sunset_sessions]^7 session service online')
