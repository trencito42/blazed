-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (server/rpc.lua)
--  Correlated server→client request/response. The repo has no such
--  primitive (the callback bus is client→server only), so this adds
--  one, used exclusively by the test agent.
--
--  Flow: RpcClient.call(target, method, payload)
--    → TriggerClientEvent('sunset:testagent:rpc', target, id, method, payload)
--    → client executes the allowlisted handler
--    → TriggerServerEvent('sunset:testagent:rpcResult', id, ok, result, err)
--    → promise resolves/rejects; caller gets result or a typed error.
--
--  Safety: unknown ids are dropped, results after timeout are dropped,
--  and every call is bounded (no infinite waits).
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

local pending = {}   -- [id] = { promise, deadline, method, target }
local idCounter = 0
local reaperRunning = false

local function nextId()
    idCounter = idCounter + 1
    return ('ta_%d_%d'):format(GetGameTimer(), idCounter)
end

local function settle(id, ok, result, err)
    local entry = pending[id]
    if not entry then return false end   -- late/duplicate/unknown — drop
    pending[id] = nil
    if ok then
        entry.promise:resolve(result)
    else
        entry.promise:reject(err or SunsetTestAgent.Errors.INTERNAL)
    end
    return true
end

-- Reap expired calls so a dead client can never wedge the bridge.
local function ensureReaper()
    if reaperRunning then return end
    reaperRunning = true
    CreateThread(function()
        while next(pending) ~= nil do
            Wait(250)
            local now = GetGameTimer()
            for id, entry in pairs(pending) do
                if now >= entry.deadline then
                    pending[id] = nil
                    TestAgentLog.debug('rpc TIMEOUT id=%s method=%s target=%s',
                        id, tostring(entry.method), tostring(entry.target))
                    entry.promise:reject(SunsetTestAgent.Errors.TIMEOUT)
                end
            end
        end
        reaperRunning = false
    end)
end

-- Call a client method on `target`. Returns a promise resolving to the
-- client result, or rejecting with a typed error table.
function RpcClient.call(target, method, payload, timeoutMs)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then
        local p = promise.new()
        p:reject(SunsetTestAgent.Errors.TEST_PLAYER_NOT_CONNECTED)
        return p
    end
    local id = nextId()
    local p = promise.new()
    pending[id] = {
        promise = p,
        deadline = GetGameTimer() + (tonumber(timeoutMs) or Cfg.rpcTimeoutMs),
        method = method,
        target = target,
    }
    ensureReaper()
    TriggerClientEvent('sunset:testagent:rpc', target, id, method, payload)
    TestAgentLog.debug('rpc CALL id=%s method=%s target=%d', id, tostring(method), target)
    return p
end

-- Await-style wrapper: returns ok, resultOrError.
function RpcClient.await(target, method, payload, timeoutMs)
    local p = RpcClient.call(target, method, payload, timeoutMs)
    local ok, res = pcall(function() return Citizen.Await(p) end)
    if ok then return true, res end
    return false, (type(res) == 'table' and res.code) and res
        or SunsetTestAgent.Errors.TIMEOUT
end

RegisterNetEvent('sunset:testagent:rpcResult', function(id, ok, result, err)
    local source = source
    id = tostring(id or '')
    local entry = pending[id]
    if not entry then
        -- Unknown/late result — could be a replay or a timeout race. Drop it.
        TestAgentLog.debug('rpc result dropped (unknown id) id=%s from=%d', id, source)
        return
    end
    -- Only the intended target may answer its own call.
    if entry.target ~= source then
        TestAgentLog.warn('rpc result from wrong source id=%s expected=%d got=%d',
            id, entry.target, source)
        return
    end
    settle(id, ok == true, result, err)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, entry in pairs(pending) do
        if entry.target == src then
            pending[id] = nil
            entry.promise:reject(SunsetTestAgent.Errors.TEST_PLAYER_NOT_CONNECTED)
        end
    end
end)
