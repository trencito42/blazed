local function notify(source, msg, typ)
    TriggerClientEvent('sunset:client:notify', source, msg, typ or 'info')
end

RegisterCommand('service', function(source, args)
    if source == 0 then return end
    local callType = args[1]
    if not callType then
        notify(source, 'Usage: /service [taxi|medic|fire|mechanic] [message]', 'error')
        return
    end
    local description = table.concat(args, ' ', 2)
    local call, err = ServiceCore.createServiceCall(source, callType, nil, nil, description)
    if not call then notify(source, err or 'Could not create service call', 'error'); return end
    TriggerEvent('sunset:dispatch:serviceCommand', source, call.callType, call.id, description)
end, false)

RegisterCommand('servicecalls', function(source)
    if source == 0 then return end
    local openCalls = ServiceCore.getActiveCalls(nil, { status = Sunset.Dispatch.States.OPEN })
    local lines = {}
    local shown = 0
    for _, call in ipairs(openCalls) do
        if ServiceCore.isProviderForType(source, call.callType) then
            shown = shown + 1
            local c = call.coords or {}
            lines[#lines + 1] = ('#%d %s — %s (%.0f, %.0f)'):format(
                call.id,
                Sunset.Dispatch.ServiceTypes[call.callType].label or call.callType,
                call.callerName or 'Unknown',
                c.x or 0,
                c.y or 0
            )
        end
    end
    if shown == 0 then
        notify(source, 'No open service calls for your duty role', 'info')
        return
    end
    notify(source, ('Open calls (%d): %s'):format(shown, table.concat(lines, ' | ')), 'info')
end, false)

RegisterCommand('accept', function(source, args)
    if source == 0 then return end
    local callType, callId = args[1], args[2]
    if not callType or not callId then
        notify(source, 'Usage: /accept [type] [id]', 'error')
        return
    end
    local call, err = ServiceCore.acceptCall(source, callType, callId)
    if not call then notify(source, err or 'Could not accept call', 'error') end
end, false)

RegisterCommand('cancel', function(source, args)
    if source == 0 then return end
    local callType, callId = args[1], args[2]
    if not callType or not callId then
        notify(source, 'Usage: /cancel [type] [id]', 'error')
        return
    end
    local ok, err = ServiceCore.cancelCall(source, callType, callId)
    if not ok then notify(source, err or 'Could not cancel call', 'error')
    else notify(source, 'Service call cancelled', 'success') end
end, false)

CreateThread(function()
    Wait(500)
    TriggerClientEvent('chat:addSuggestion', -1, '/service', 'Request a service', {
        { name = 'type', help = 'taxi | medic | fire | mechanic' },
        { name = 'message', help = 'optional details' },
    })
    TriggerClientEvent('chat:addSuggestion', -1, '/servicecalls', 'List open service calls for your duty role')
    TriggerClientEvent('chat:addSuggestion', -1, '/accept', 'Accept a service call', {
        { name = 'type', help = 'taxi | medic | fire | mechanic' },
        { name = 'id', help = 'Call ID' },
    })
    TriggerClientEvent('chat:addSuggestion', -1, '/cancel', 'Cancel a service call', {
        { name = 'type', help = 'taxi | medic | fire | mechanic' },
        { name = 'id', help = 'Call ID' },
    })
end)
