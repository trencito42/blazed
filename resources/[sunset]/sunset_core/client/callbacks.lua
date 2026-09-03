Sunset = Sunset or {}

local PendingCallbacks = {}
local RequestId = 0

function TriggerCallback(name, cb, ...)
    RequestId = RequestId + 1
    local id = RequestId
    PendingCallbacks[id] = cb
    TriggerServerEvent('sunset:server:triggerCallback', name, id, ...)
end
exports('TriggerCallback', TriggerCallback)

RegisterNetEvent('sunset:client:callbackResponse', function(requestId, result, err)
    local cb = PendingCallbacks[requestId]
    if cb then
        PendingCallbacks[requestId] = nil
        cb(result, err)
    end
end)

-- Promise-style for internal use
function Sunset.AwaitCallback(name, ...)
    local p = promise.new()
    TriggerCallback(name, function(result, err)
        if err then
            p:reject(err)
        else
            p:resolve(result)
        end
    end, ...)
    return Citizen.Await(p)
end
