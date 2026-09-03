--- Export bridge + callbacks. Implementation in service_core.lua.
CreateThread(function()
    Wait(1000)
    ServiceCore.loadOpenCalls()
end)

local function wrapCreateCall(a, b, c, d, e)
    if type(a) == 'table' then
        local opts = a
        local source = opts.source or opts.callerSource
        if not source then return nil, 'source required in opts' end
        return ServiceCore.createServiceCall(
            source,
            opts.callType or opts.type,
            opts.location or opts.coords,
            opts.metadata,
            opts.description
        )
    end
    return ServiceCore.createServiceCall(a, b, c, d, e)
end

exports('CreateCall', wrapCreateCall)
exports('CreateServiceCall', wrapCreateCall)

exports('AcceptCall', function(sourceOrCallId, callTypeOrSource, callIdMaybe)
    if callIdMaybe then
        return ServiceCore.acceptCall(sourceOrCallId, callTypeOrSource, callIdMaybe)
    end
    return ServiceCore.acceptCall(callTypeOrSource, sourceOrCallId, callIdMaybe)
end)

exports('CancelCall', function(a, b, c, d)
    if type(c) == 'string' or type(c) == 'number' then
        return ServiceCore.cancelCall(a, b, c, d)
    end
    return ServiceCore.cancelCall(b, a, c, d)
end)

exports('CompleteCall', function(arg1, arg2, arg3)
    if arg3 ~= nil then
        return ServiceCore.completeCall(arg1, arg2, arg3)
    end
    local callId, source = arg1, arg2
    local call = ServiceCore.getCallById(callId)
    if not call then return nil, 'Call not found' end
    return ServiceCore.completeCall(source, call.callType, callId)
end)

exports('GetCall', function(callType, callId)
    if callId == nil then
        return ServiceCore.getCallById(callType)
    end
    return ServiceCore.getCall(callType, callId)
end)

exports('GetActiveCalls', function(callType, opts)
    return ServiceCore.getActiveCalls(callType, opts)
end)

exports('GetCallForResponder', function(characterId)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local char = exports.sunset_core:GetCharacter(src)
        if char and char.id == characterId then
            return ServiceCore.getPlayerActiveCall(src)
        end
    end
    return nil
end)

exports('GetPlayerActiveCall', function(source, callType)
    return ServiceCore.getPlayerActiveCall(source, callType)
end)

exports.sunset_core:RegisterCallback('sunset:dispatchList', function(source, callType)
    if not exports.sunset_factions:IsOnDuty(source) then
        return nil, 'You must be on duty'
    end
    callType = callType and Sunset.Dispatch.NormalizeServiceType(callType) or nil
    return ServiceCore.getActiveCalls(callType)
end)

exports.sunset_core:RegisterCallback('sunset:dispatchGet', function(source, callId)
    local call = ServiceCore.getCallById(callId)
    if not call then return nil, 'Call not found' end
    return ServiceCore.serializeCall(call, source)
end)

AddEventHandler('playerDropped', function()
    ServiceCore.handleDisconnect(source)
end)

exports('UpdateCallState', function(source, callType, callId, newState)
    return ServiceCore.updateCallState(source, callType, callId, newState)
end)

exports('IsProviderForType', function(source, callType)
    return ServiceCore.isProviderForType(source, callType)
end)

print('[sunset_dispatch] exports and callbacks ready')
