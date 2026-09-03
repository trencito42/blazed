local activeWaypointCallId = nil

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function setWaypoint(coords)
    if not coords or not coords.x then return end
    SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
end

local function clearWaypoint()
    if activeWaypointCallId then
        SetWaypointOff()
        activeWaypointCallId = nil
    end
end

RegisterNetEvent('sunset:dispatch:waypoint', function(coords)
    setWaypoint(coords)
    notify('GPS waypoint set for service call', 'info')
end)

RegisterNetEvent('sunset:dispatch:newCall', function(call)
    if not call or not call.callType then return end
    local label = Sunset.Dispatch.ServiceTypes[call.callType]
        and Sunset.Dispatch.ServiceTypes[call.callType].label
        or call.callType
    notify(('New %s call #%d — /accept %s %d'):format(label, call.id, call.callType, call.id), 'warning')
end)

RegisterNetEvent('sunset:dispatch:callAccepted', function(call)
    if not call then return end
    notify('A responder is on the way', 'success')
end)

RegisterNetEvent('sunset:dispatch:callUpdated', function(call)
    if not call then return end
    if call.isResponder and call.coords and (
        call.status == Sunset.Dispatch.States.EN_ROUTE
        or call.status == Sunset.Dispatch.States.ASSIGNED
    ) then
        setWaypoint(call.coords)
        activeWaypointCallId = call.id
    end
end)

RegisterNetEvent('sunset:dispatch:callEnded', function(call)
    if call and call.id == activeWaypointCallId then clearWaypoint() end
end)

RegisterNetEvent('sunset:dispatch:callTaken', function(data)
    if data and data.id == activeWaypointCallId then clearWaypoint() end
end)

CreateThread(function()
    Wait(1500)
    TriggerEvent('chat:addSuggestion', '/service', 'Request a service', {
        { name = 'type', help = 'taxi | medic | fire | mechanic' },
        { name = 'message', help = 'optional details' },
    })
    TriggerEvent('chat:addSuggestion', '/servicecalls', 'List open service calls for your duty role')
    TriggerEvent('chat:addSuggestion', '/accept', 'Accept a service call', {
        { name = 'type', help = 'taxi | medic | fire | mechanic' },
        { name = 'id', help = 'Call ID' },
    })
    TriggerEvent('chat:addSuggestion', '/cancel', 'Cancel a service call', {
        { name = 'type', help = 'taxi | medic | fire | mechanic' },
        { name = 'id', help = 'Call ID' },
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearWaypoint() end
end)
