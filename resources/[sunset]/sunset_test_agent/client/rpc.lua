-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (client/rpc.lua)
--  Client side of the correlated RPC. Handlers are an explicit
--  allowlist table — the server can only invoke registered methods.
-- ═══════════════════════════════════════════════════════════════

ClientRpc = {}
ClientRpc.handlers = {}

function ClientRpc.register(method, fn)
    if type(method) ~= 'string' or type(fn) ~= 'function' then return end
    ClientRpc.handlers[method] = fn
end

RegisterNetEvent('sunset:testagent:rpc', function(id, method, payload)
    id = tostring(id or '')
    method = tostring(method or '')
    local handler = ClientRpc.handlers[method]
    if not handler then
        ClientLog.error('rpc: unknown method ' .. method)
        TriggerServerEvent('sunset:testagent:rpcResult', id, false, nil, {
            code = 'INVALID_ARGUMENT',
            message = 'Unknown client RPC method: ' .. method,
            retryable = false,
        })
        return
    end
    ClientLog.debug('rpc IN id=%s method=%s', id, method)
    -- Run in a thread so handlers may Wait (teleport fade, model load, ...).
    CreateThread(function()
        local results = { pcall(handler, payload) }
        local okCall = table.remove(results, 1)
        if okCall then
            TriggerServerEvent('sunset:testagent:rpcResult', id, true, results[1], nil)
        else
            ClientLog.error('rpc handler error ' .. method .. ': ' .. tostring(results[1]))
            TriggerServerEvent('sunset:testagent:rpcResult', id, false, nil, {
                code = 'INTERNAL',
                message = tostring(results[1]),
                retryable = false,
            })
        end
    end)
end)
