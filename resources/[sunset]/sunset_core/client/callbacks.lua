Sunset = Sunset or {}

local PendingCallbacks = {}
local RequestId = 0
local ResourceRequestBase = math.abs(GetHashKey(GetCurrentResourceName())) * 100000

local function nextRequestId()
    RequestId = RequestId + 1
    if RequestId >= 99999 then RequestId = 1 end
    return ResourceRequestBase + RequestId
end

function TriggerCallback(name, cb, ...)
    local id = nextRequestId()
    PendingCallbacks[id] = cb
    TriggerServerEvent('sunset:server:triggerCallback', name, id, ...)
    SetTimeout(15000, function()
        local pending = PendingCallbacks[id]
        if not pending then return end
        PendingCallbacks[id] = nil
        pending(nil, ('%s timed out after 15 seconds. Reopen the screen and try again.'):format(name))
    end)
end
exports('TriggerCallback', TriggerCallback)

RegisterNetEvent('sunset:client:callbackResponse', function(requestId, result, err)
    local cb = PendingCallbacks[requestId]
    if cb then
        PendingCallbacks[requestId] = nil
        cb(result, err)
    end
end)

-- Promise-style for internal use — always returns result, err (never throws)
function Sunset.AwaitCallback(name, ...)
    local p = promise.new()
    TriggerCallback(name, function(result, err)
        p:resolve({ result = result, err = err })
    end, ...)
    local packed = Citizen.Await(p)
    return packed.result, packed.err
end
