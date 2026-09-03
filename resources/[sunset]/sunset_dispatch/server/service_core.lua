ServiceCore = ServiceCore or {}

local Calls = {}
local RateLimits = {}
local AcceptLocks = {}
local ProviderActive = {}

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function findSourceByCharacterId(characterId)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = getChar(src)
        if c and c.id == characterId then return src end
    end
    return nil
end

local function playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return Sunset.Dispatch.EncodeCoords(GetEntityCoords(ped))
end

local function notify(source, msg, typ)
    TriggerClientEvent('sunset:client:notify', source, msg, typ or 'info')
end

local function checkRateLimit(source, key)
    local limits = Sunset.Dispatch.rateLimits or {}
    local cooldown = limits[key] or 2000
    local now = GetGameTimer()
    RateLimits[source] = RateLimits[source] or {}
    local last = RateLimits[source][key] or 0
    if now - last < cooldown then return false end
    RateLimits[source][key] = now
    return true
end

function ServiceCore.isProviderForType(source, callType)
    if callType == 'mechanic' and GetResourceState('sunset_jobs') == 'started' then
        local ok, providers = pcall(function() return exports.sunset_jobs:GetMechanicProviders() end)
        if ok and providers and providers[source] then return true end
    end
    local char = getChar(source)
    if not char or not exports.sunset_factions:IsOnDuty(source) then return false end
    local factionId = Sunset.GetCharacterFaction(char)
    return factionId and Sunset.Dispatch.ProviderFactionMatches(callType, factionId)
end

local function isEmergencyResponder(source)
    if not exports.sunset_factions:IsOnDuty(source) then return false end
    local char = getChar(source)
    if not char then return false end
    local factionId = Sunset.GetCharacterFaction(char)
    if not factionId then return false end
    local fType = Sunset.GetFactionType(factionId)
    return fType == 'law_enforcement' or fType == 'ems' or fType == 'fire_rescue'
end

local function broadcastBackupResponders(event, payload, excludeSource)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src ~= excludeSource and isEmergencyResponder(src) then
            TriggerClientEvent(event, src, payload)
        end
    end
end

local function serializeCall(call, viewerSource)
    if not call then return nil end
    local viewerChar = viewerSource and getChar(viewerSource)
    local callerSrc = call.callerSource or findSourceByCharacterId(call.callerCharacterId)
    local responderSrc = call.responderSource or findSourceByCharacterId(call.responderCharacterId)
    return {
        id = call.id,
        callType = call.callType,
        serviceType = call.callType,
        status = call.status,
        state = call.status,
        description = call.description,
        callerCharacterId = call.callerCharacterId,
        responderCharacterId = call.responderCharacterId,
        callerName = call.callerName,
        responderName = call.responderName,
        coords = call.coords,
        metadata = call.metadata,
        createdAt = call.createdAt,
        isCaller = viewerChar and viewerChar.id == call.callerCharacterId,
        isResponder = viewerChar and viewerChar.id == call.responderCharacterId,
        isProvider = viewerSource == responderSrc,
        callerSource = callerSrc,
        responderSource = responderSrc,
        callerServerId = callerSrc,
        responderServerId = responderSrc,
    }
end

local function persistStatus(callId, status, responderCharId)
    local terminal = Sunset.Dispatch.IsTerminalState(status)
    if terminal then
        MySQL.update.await([[
            UPDATE service_calls
            SET status = ?, responder_character_id = ?, completed_at = NOW()
            WHERE id = ?
        ]], { status, responderCharId, callId })
    else
        MySQL.update.await([[
            UPDATE service_calls
            SET status = ?, responder_character_id = ?
            WHERE id = ?
        ]], { status, responderCharId, callId })
    end
end

local function broadcastProviders(callType, event, payload)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if ServiceCore.isProviderForType(src, callType) then
            TriggerClientEvent(event, src, payload)
        end
    end
end

local function scheduleTimeout(callId)
    local timeoutSec = Sunset.Dispatch.callTimeoutSec or 600
    SetTimeout(timeoutSec * 1000, function()
        local call = Calls[callId]
        if not call or call.status ~= Sunset.Dispatch.States.OPEN then return end
        call.status = Sunset.Dispatch.States.CANCELLED
        pcall(function() persistStatus(callId, call.status, nil) end)
        local callerSrc = call.callerSource or findSourceByCharacterId(call.callerCharacterId)
        if callerSrc then
            notify(callerSrc, 'Your service request timed out — no responders available', 'warning')
            TriggerClientEvent('sunset:dispatch:callEnded', callerSrc, serializeCall(call, callerSrc))
        end
        broadcastProviders(call.callType, 'sunset:dispatch:callUpdated', serializeCall(call))
        TriggerEvent('sunset:dispatch:callCancelled', callId, call.callType, 'timeout')
        Calls[callId] = nil
    end)
end

local function hydrateCall(row)
    local coords = row.coords
    if type(coords) == 'string' then coords = json.decode(coords) end
    local metadata = row.metadata
    if type(metadata) == 'string' then metadata = json.decode(metadata) end
    local call = {
        id = row.id,
        callType = row.call_type,
        status = row.status,
        callerCharacterId = row.caller_character_id,
        responderCharacterId = row.responder_character_id,
        callerSource = findSourceByCharacterId(row.caller_character_id),
        responderSource = row.responder_character_id and findSourceByCharacterId(row.responder_character_id) or nil,
        callerName = row.caller_name,
        responderName = row.responder_name,
        coords = coords,
        description = row.description,
        metadata = metadata,
        createdAt = row.created_at,
    }
    Calls[call.id] = call
    if call.responderSource then ProviderActive[call.responderSource] = call.id end
    return call
end

function ServiceCore.loadOpenCalls()
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT sc.*,
                (SELECT CONCAT(firstname, ' ', lastname) FROM characters WHERE id = sc.caller_character_id LIMIT 1) AS caller_name,
                (SELECT CONCAT(firstname, ' ', lastname) FROM characters WHERE id = sc.responder_character_id LIMIT 1) AS responder_name
            FROM service_calls sc
            WHERE sc.status IN ('OPEN', 'ASSIGNED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS')
        ]])
    end)
    if not ok or not rows then return end
    for _, row in ipairs(rows) do
        hydrateCall(row)
        if row.status == Sunset.Dispatch.States.OPEN then
            scheduleTimeout(row.id)
            if row.call_type == 'police_backup' then
                broadcastBackupResponders('sunset:dispatch:backupAlert', serializeCall(Calls[row.id]))
            end
        end
    end
end

function ServiceCore.getCall(callType, callId)
    callId = tonumber(callId)
    local call = Calls[callId]
    if not call then return nil end
    if callType and call.callType ~= Sunset.Dispatch.NormalizeServiceType(callType) then return nil end
    return call
end

function ServiceCore.getCallById(callId)
    return Calls[tonumber(callId)]
end

function ServiceCore.getActiveCalls(callType, opts)
    opts = opts or {}
    local list = {}
    for _, call in pairs(Calls) do
        if Sunset.Dispatch.IsActiveState(call.status) then
            if not callType or call.callType == Sunset.Dispatch.NormalizeServiceType(callType) then
                if not opts.status or call.status == opts.status then
                    list[#list + 1] = serializeCall(call)
                end
            end
        end
    end
    table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return list
end

function ServiceCore.getPlayerActiveCall(source, callType)
    local char = getChar(source)
    if not char then return nil end
    for _, call in pairs(Calls) do
        if Sunset.Dispatch.IsActiveState(call.status)
            and (not callType or call.callType == Sunset.Dispatch.NormalizeServiceType(callType))
            and (call.callerCharacterId == char.id or call.responderCharacterId == char.id) then
            return call
        end
    end
    return nil
end

function ServiceCore.createServiceCall(source, callType, coords, metadata, description)
    callType = Sunset.Dispatch.NormalizeServiceType(callType)
    if not callType then return nil, 'Invalid service type' end

    metadata = metadata or {}
    description = description or ''
    local isSystem = not source or source == 0 or metadata.system == true

    local char = not isSystem and getChar(source) or nil
    if not isSystem and not char then return nil, 'No character' end
    if not isSystem then
        local rateKey = callType == 'police_backup' and 'backupMs' or 'createMs'
        if not checkRateLimit(source, rateKey) then
            return nil, callType == 'police_backup'
                and 'Please wait before requesting backup again'
                or 'Please wait before requesting another service'
        end
        if ServiceCore.getPlayerActiveCall(source, callType) then
            return nil, callType == 'police_backup'
                and 'You already have an active backup request — use /cbackup to cancel'
                or 'You already have an active service request'
        end
    end

    coords = Sunset.Dispatch.EncodeCoords(coords or (not isSystem and playerCoords(source)) or coords)
    local callerCharId = char and char.id or 0
    local callerName = isSystem and 'Dispatch' or exports.sunset_core:GetPlayerDisplayName(source)

    local insertId = MySQL.insert.await([[
        INSERT INTO service_calls (call_type, status, caller_character_id, coords, description, metadata)
        VALUES (?, 'OPEN', ?, ?, ?, ?)
    ]], { callType, callerCharId, json.encode(coords), description, json.encode(metadata) })
    if not insertId then return nil, 'Could not create service call' end

    local call = {
        id = insertId,
        callType = callType,
        status = Sunset.Dispatch.States.OPEN,
        callerCharacterId = callerCharId,
        responderCharacterId = nil,
        callerSource = isSystem and nil or source,
        responderSource = nil,
        callerName = callerName,
        responderName = nil,
        coords = coords,
        description = description,
        metadata = metadata,
        createdAt = os.time(),
    }
    Calls[call.id] = call

    local payload = serializeCall(call, source)
    local label = Sunset.Dispatch.ServiceTypes[callType].label or callType
    if not isSystem then
        notify(source, callType == 'police_backup'
            and 'Backup request sent — use /cbackup to cancel'
            or ('%s request sent — waiting for a responder'):format(label), 'success')
    end
    if callType == 'police_backup' then
        broadcastBackupResponders('sunset:dispatch:backupAlert', payload, source)
    elseif callType == 'mechanic' then
        broadcastProviders(callType, 'sunset:dispatch:newCall', payload)
        TriggerEvent('sunset:jobs:notifyMechanicCall', {
            id = call.id,
            callType = callType,
            label = description ~= '' and description or 'Mechanic service request',
            coords = coords,
            callerName = callerName,
            description = description,
            createdAt = call.createdAt,
        })
    else
        broadcastProviders(callType, 'sunset:dispatch:newCall', payload)
    end
    TriggerEvent('sunset:dispatch:callCreated', call.id, callType, source)
    scheduleTimeout(call.id)
    return payload
end

function ServiceCore.acceptCall(source, callType, callId)
    callType = Sunset.Dispatch.NormalizeServiceType(callType)
    callId = tonumber(callId)
    if not callType or not callId then return nil, 'Usage: /accept [type] [id]' end
    local cfg = Sunset.Dispatch.ServiceTypes[callType]
    if cfg and cfg.broadcastOnly then
        return nil, 'This call type cannot be accepted'
    end
    if not ServiceCore.isProviderForType(source, callType) then
        return nil, 'You must be on duty as a ' .. (Sunset.Dispatch.ServiceTypes[callType].label or callType) .. ' provider'
    end
    if not checkRateLimit(source, 'acceptMs') then return nil, 'Please wait before accepting another call' end
    if ProviderActive[source] then return nil, 'Finish your current call first' end

    local char = getChar(source)
    if not char then return nil, 'No character' end
    if AcceptLocks[callId] then return nil, 'Call is being assigned' end
    AcceptLocks[callId] = true

    local ok, result, err = pcall(function()
        local affected = MySQL.update.await([[
            UPDATE service_calls
            SET status = 'ASSIGNED', responder_character_id = ?
            WHERE id = ? AND call_type = ? AND status = 'OPEN'
        ]], { char.id, callId, callType })
        if affected ~= 1 then return nil, 'Call no longer available' end

        local call = Calls[callId]
        if not call or call.callType ~= callType then return nil, 'Call not found' end

        call.status = Sunset.Dispatch.States.ASSIGNED
        call.responderCharacterId = char.id
        call.responderSource = source
        call.responderName = exports.sunset_core:GetPlayerDisplayName(source)
        ProviderActive[source] = callId

        local payload = serializeCall(call, source)
        local callerSrc = call.callerSource or findSourceByCharacterId(call.callerCharacterId)
        if callerSrc then
            notify(callerSrc, ('%s accepted your request'):format(call.responderName), 'success')
            TriggerClientEvent('sunset:dispatch:callAccepted', callerSrc, payload)
        end
        TriggerClientEvent('sunset:dispatch:waypoint', source, call.coords)
        notify(source, ('Call #%d accepted — GPS set'):format(callId), 'success')
        broadcastProviders(callType, 'sunset:dispatch:callTaken', { id = callId })
        broadcastProviders(callType, 'sunset:dispatch:callUpdated', payload)
        TriggerEvent('sunset:dispatch:callAccepted', callId, callType, source, callerSrc)
        return payload
    end)

    AcceptLocks[callId] = nil
    if not ok then
        print(('[sunset_dispatch] acceptCall error: %s'):format(tostring(result)))
        return nil, 'Could not accept call'
    end
    return result, err
end

function ServiceCore.cancelCall(source, callType, callId, reason)
    callType = Sunset.Dispatch.NormalizeServiceType(callType)
    callId = tonumber(callId)
    if not callType or not callId then return nil, 'Usage: /cancel [type] [id]' end
    if not checkRateLimit(source, 'cancelMs') then return nil, 'Please wait before cancelling again' end

    local char = getChar(source)
    if not char then return nil, 'No character' end
    local call = Calls[callId]
    if not call or call.callType ~= callType then return nil, 'Call not found' end
    if Sunset.Dispatch.IsTerminalState(call.status) then return nil, 'Call already closed' end

    local isCaller = call.callerCharacterId == char.id
    local isResponder = call.responderCharacterId == char.id
    if not isCaller and not isResponder and not ServiceCore.isProviderForType(source, callType) then
        return nil, 'You cannot cancel this call'
    end
    if isResponder and not isCaller and call.status == Sunset.Dispatch.States.IN_PROGRESS then
        return nil, 'Cannot cancel while service is in progress'
    end

    call.status = Sunset.Dispatch.States.CANCELLED
    pcall(function() persistStatus(callId, call.status, call.responderCharacterId) end)
    if call.responderSource then ProviderActive[call.responderSource] = nil end

    local payload = serializeCall(call, source)
    local callerSrc = call.callerSource or findSourceByCharacterId(call.callerCharacterId)
    local responderSrc = call.responderSource or findSourceByCharacterId(call.responderCharacterId)
    if callerSrc and callerSrc ~= source then
        notify(callerSrc, reason or 'Service call was cancelled', 'warning')
        TriggerClientEvent('sunset:dispatch:callEnded', callerSrc, payload)
    end
    if callType == 'police_backup' then
        broadcastBackupResponders('sunset:dispatch:backupEnded', payload)
    end
    if responderSrc and responderSrc ~= source then
        notify(responderSrc, reason or 'Service call was cancelled', 'warning')
        TriggerClientEvent('sunset:dispatch:callEnded', responderSrc, payload)
    end
    broadcastProviders(callType, 'sunset:dispatch:callUpdated', payload)
    TriggerEvent('sunset:dispatch:callCancelled', callId, callType, isCaller and 'caller' or 'provider')
    Calls[callId] = nil
    return true
end

function ServiceCore.updateCallState(source, callType, callId, newState)
    callType = Sunset.Dispatch.NormalizeServiceType(callType)
    callId = tonumber(callId)
    newState = newState and string.upper(newState) or nil
    if not callType or not callId or not newState then return nil, 'Invalid arguments' end
    if not Sunset.Dispatch.States[newState] then return nil, 'Invalid state' end

    local call = Calls[callId]
    if not call or call.callType ~= callType then return nil, 'Call not found' end
    if not Sunset.Dispatch.AllowedStateTransition(call.status, newState) then
        return nil, ('Cannot transition from %s to %s'):format(call.status, newState)
    end

    local char = getChar(source)
    if not char then return nil, 'No character' end
    local isCaller = call.callerCharacterId == char.id
    local isResponder = call.responderCharacterId == char.id
    if not isCaller and not isResponder then return nil, 'Not part of this call' end

    call.status = newState
    pcall(function() persistStatus(callId, newState, call.responderCharacterId) end)

    local payload = serializeCall(call, source)
    local callerSrc = call.callerSource or findSourceByCharacterId(call.callerCharacterId)
    local responderSrc = call.responderSource or findSourceByCharacterId(call.responderCharacterId)
    if callerSrc then TriggerClientEvent('sunset:dispatch:callUpdated', callerSrc, payload) end
    if responderSrc then TriggerClientEvent('sunset:dispatch:callUpdated', responderSrc, payload) end
    broadcastProviders(callType, 'sunset:dispatch:callUpdated', payload)
    TriggerEvent('sunset:dispatch:callStateChanged', callId, callType, newState, source)

    if Sunset.Dispatch.IsTerminalState(newState) then
        if call.responderSource then ProviderActive[call.responderSource] = nil end
        Calls[callId] = nil
        if callerSrc then TriggerClientEvent('sunset:dispatch:callEnded', callerSrc, payload) end
        if responderSrc then TriggerClientEvent('sunset:dispatch:callEnded', responderSrc, payload) end
    end
    return payload
end

function ServiceCore.completeCall(source, callType, callId)
    local call = ServiceCore.getCall(callType, callId)
    if not call then return nil, 'Call not found' end

    -- A successful gameplay action (revive/extinguish/repair) is authoritative
    -- proof of service. Advance any skipped UI states so the persisted dispatch
    -- row cannot remain OPEN after the real incident was completed.
    if call.status == Sunset.Dispatch.States.OPEN then
        local accepted, err = ServiceCore.acceptCall(source, callType, callId)
        if not accepted then return nil, err end
        call = ServiceCore.getCall(callType, callId)
    end
    local steps = {
        [Sunset.Dispatch.States.ASSIGNED] = Sunset.Dispatch.States.EN_ROUTE,
        [Sunset.Dispatch.States.EN_ROUTE] = Sunset.Dispatch.States.ARRIVED,
        [Sunset.Dispatch.States.ARRIVED] = Sunset.Dispatch.States.IN_PROGRESS,
    }
    while call and steps[call.status] do
        local updated, err = ServiceCore.updateCallState(source, callType, callId, steps[call.status])
        if not updated then return nil, err end
        call = ServiceCore.getCall(callType, callId)
    end
    return ServiceCore.updateCallState(source, callType, callId, Sunset.Dispatch.States.COMPLETED)
end

function ServiceCore.handleDisconnect(source)
    RateLimits[source] = nil
    ProviderActive[source] = nil
    local char = getChar(source)
    if not char then return end

    for callId, call in pairs(Calls) do
        if call.callerCharacterId == char.id and Sunset.Dispatch.IsActiveState(call.status) then
            ServiceCore.cancelCall(source, call.callType, callId, 'Caller disconnected')
        elseif call.responderCharacterId == char.id and Sunset.Dispatch.IsActiveState(call.status) then
            if call.status == Sunset.Dispatch.States.IN_PROGRESS then
                ServiceCore.cancelCall(source, call.callType, callId, 'Responder disconnected')
            else
                call.status = Sunset.Dispatch.States.OPEN
                call.responderCharacterId = nil
                call.responderSource = nil
                call.responderName = nil
                pcall(function()
                    MySQL.update.await([[
                        UPDATE service_calls SET status = 'OPEN', responder_character_id = NULL WHERE id = ?
                    ]], { callId })
                end)
                local callerSrc = call.callerSource or findSourceByCharacterId(call.callerCharacterId)
                if callerSrc then
                    notify(callerSrc, 'Responder disconnected — searching for another provider', 'warning')
                end
                broadcastProviders(call.callType, 'sunset:dispatch:newCall', serializeCall(call))
                scheduleTimeout(callId)
            end
        end
    end
end

function ServiceCore.serializeCall(call, viewerSource)
    return serializeCall(call, viewerSource)
end
