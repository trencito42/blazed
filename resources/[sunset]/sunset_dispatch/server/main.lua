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
    if callIdMaybe ~= nil then
        return ServiceCore.acceptCall(sourceOrCallId, callTypeOrSource, callIdMaybe)
    end
    local s1 = tonumber(sourceOrCallId)
    local s2 = tonumber(callTypeOrSource)
    if s1 and s2 then
        local call = ServiceCore.getCallById(s2) or ServiceCore.getCallById(s1)
        if call then
            local realCallId = (ServiceCore.getCallById(s2) and s2) or s1
            local realSource = (realCallId == s2 and s1) or s2
            return ServiceCore.acceptCall(realSource, call.callType, realCallId)
        end
        return ServiceCore.acceptCall(s1, 'police', s2)
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

exports('IsProviderForType', function(source, callType)
    return ServiceCore.isProviderForType(source, callType)
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

exports.sunset_core:RegisterCallback('sunset:dispatchAccept', function(source, callType, callId)
    if not exports.sunset_factions:IsOnDuty(source) then
        return nil, 'You must be on duty'
    end
    local call, err = ServiceCore.acceptCall(source, callType, callId)
    if not call then return nil, err end
    return call
end)

exports.sunset_core:RegisterCallback('sunset:dispatchPanelData', function(source)
    if not exports.sunset_factions:IsOnDuty(source) then
        return nil, 'You must be on duty'
    end

    local openCalls = ServiceCore.getActiveCalls(nil, { status = Sunset.Dispatch.States.OPEN })
    local uiCalls = {}
    for _, call in ipairs(openCalls) do
        if ServiceCore.isProviderForType(source, call.callType) then
            local cfg = Sunset.Dispatch.ServiceTypes[call.callType]
            local c = call.coords or {}
            uiCalls[#uiCalls + 1] = {
                id = call.id,
                type = call.callType,
                typeLabel = cfg and cfg.label or call.callType,
                title = call.description,
                message = call.description,
                caller = call.callerName,
                location = ('%.0f, %.0f'):format(c.x or 0, c.y or 0),
                status = 'open',
                canAccept = true,
            }
        end
    end
    return { calls = uiCalls }
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

local function create112Call(source, category, description, street, area)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character loaded' end

    category = tostring(category or 'emergency'):lower()
    local allowedCategories = {
        emergency = true,
        medical = true,
        fire = true,
        shots = true,
        robbery = true,
        theft = true,
        assault = true,
        traffic = true,
        suspicious = true,
    }
    if not allowedCategories[category] then category = 'emergency' end

    description = tostring(description or ''):gsub('^%s*(.-)%s*$', '%1')
    if description == '' then description = 'Citizen reported 112 emergency' end
    description = description:sub(1, 300)

    local ped = GetPlayerPed(source)
    local pCoords = (ped and ped ~= 0) and GetEntityCoords(ped) or vector3(0, 0, 0)

    local metadata = {
        emergency = '112',
        category = category,
        street = tostring(street or 'Unknown street'):sub(1, 80),
        area = tostring(area or 'Los Santos'):sub(1, 80),
        callerPhone = char.phone_number or 'Hidden',
        callerName = (char.firstname or '') .. ' ' .. (char.lastname or ''),
        timestamp = os.time(),
    }

    local callType = 'police'
    if category == 'medical' then callType = 'medic'
    elseif category == 'fire' then callType = 'fire' end

    local call, err = ServiceCore.createServiceCall(source, callType, pCoords, metadata, description)
    if not call then return nil, err end

    -- Broadcast alert to all active emergency responders
    for _, id in ipairs(GetPlayers()) do
        local officerSrc = tonumber(id)
        if officerSrc and (ServiceCore.isProviderForType(officerSrc, 'police') or ServiceCore.isProviderForType(officerSrc, callType)) then
            TriggerClientEvent('sunset:dispatch:112CallAlert', officerSrc, {
                callId = call.id,
                callType = callType,
                category = category,
                street = metadata.street,
                area = metadata.area,
                caller = metadata.callerName,
                phone = metadata.callerPhone,
                description = description,
                coords = { x = pCoords.x, y = pCoords.y, z = pCoords.z },
            })
        end
    end

    return { ok = true, callId = call.id, street = metadata.street, area = metadata.area }
end

-- Keep every 112 entry point on the same authoritative path. Phone SMS uses
-- this export, while the citizen form uses the callback below.
exports('Create112Call', create112Call)

exports.sunset_core:RegisterCallback('sunset:dispatch:call112', function(source, category, description, street, area)
    return create112Call(source, category, description, street, area)
end)

print('[sunset_dispatch] exports and callbacks ready')
