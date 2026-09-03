local Incidents = {}
local incidentSeq = 0
local LastExtinguish = {}
local LastIncidentRequest = 0

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function isFirefighter(source)
    local char = getChar(source)
    if not char then return false end
    local factionId = Sunset.GetCharacterFaction(char)
    if factionId ~= Sunset.Fire.factionId then return false end
    return exports.sunset_factions:IsOnDuty(source)
end

local function countActive()
    local n = 0
    for _, inc in pairs(Incidents) do
        if inc.status == 'active' then n = n + 1 end
    end
    return n
end

local function broadcastFirefighters(event, payload)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if isFirefighter(src) then
            TriggerClientEvent(event, src, payload)
        end
    end
end

local function serializeIncident(inc)
    return {
        id = inc.id,
        coords = inc.coords,
        label = inc.label,
        fireHealth = inc.fireHealth,
        maxHealth = inc.maxHealth,
        status = inc.status,
        vehicleModel = inc.vehicleModel,
        dispatchCallId = inc.dispatchCallId,
    }
end

local function spawnIncident()
    if countActive() >= (Sunset.Fire.maxActiveIncidents or 3) then return nil end

    local points = Sunset.Fire.spawnPoints or {}
    if #points < 1 then return nil end
    local spawn = points[math.random(1, #points)]
    local models = Sunset.Fire.vehicleModels or { 'sultan' }
    local model = models[math.random(1, #models)]

    incidentSeq = incidentSeq + 1
    local inc = {
        id = incidentSeq,
        coords = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w },
        label = 'Vehicle fire',
        fireHealth = Sunset.Fire.fireHealth or 100,
        maxHealth = Sunset.Fire.fireHealth or 100,
        status = 'active',
        vehicleModel = model,
        dispatchCallId = nil,
    }
    Incidents[inc.id] = inc

    pcall(function()
        local call = exports.sunset_dispatch:CreateServiceCall(
            0,
            'fire',
            inc.coords,
            { incidentId = inc.id, system = true },
            inc.label
        )
        if call and call.id then inc.dispatchCallId = call.id end
    end)

    broadcastFirefighters('sunset:fire:newIncident', serializeIncident(inc))
    TriggerEvent('sunset:fire:incidentSpawned', inc.id)
    return serializeIncident(inc)
end

local function completeIncident(incidentId, source)
    local inc = Incidents[incidentId]
    if not inc or inc.status ~= 'active' then return false, 'Incident not active' end

    inc.status = 'completed'
    local payout = Sunset.Fire.payout or 350
    local societyCut = math.floor(payout * (Sunset.Fire.societyCut or 0.15))
    local playerPay = payout - societyCut

    if source and source > 0 then
        exports.sunset_core:AddMoney(source, 'cash', playerPay, 'fire_incident')
        local char = getChar(source)
        if char then
            pcall(function()
                if FactionCore and FactionCore.auditLog then
                    FactionCore.auditLog(Sunset.Fire.factionId, char.id, 'fire_incident_complete', nil, {
                        incidentId = incidentId,
                        payout = playerPay,
                    })
                end
            end)
        end
        TriggerClientEvent('sunset:client:notify', source,
            ('Fire extinguished — earned $%s'):format(playerPay), 'success')
    end

    pcall(function() exports.sunset_factions:AddSocietyMoney('lsfd', societyCut) end)
    if inc.dispatchCallId then
        pcall(function() exports.sunset_dispatch:CompleteCall(source, 'fire', inc.dispatchCallId) end)
    end

    TriggerClientEvent('sunset:fire:incidentEnded', -1, incidentId)
    TriggerEvent('sunset:faction:activityComplete', source, 'fire_rescue', { incidentId = incidentId, payout = playerPay })
    return true
end

exports.sunset_core:RegisterCallback('sunset:fireGetIncidents', function(source)
    if not isFirefighter(source) then return nil, 'Must be on duty as LSFD' end
    local list = {}
    for _, inc in pairs(Incidents) do
        if inc.status == 'active' then
            list[#list + 1] = serializeIncident(inc)
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

exports.sunset_core:RegisterCallback('sunset:fireRequestIncident', function(source)
    if not isFirefighter(source) then return nil, 'Must be on duty as LSFD' end

    local list = {}
    for _, inc in pairs(Incidents) do
        if inc.status == 'active' then list[#list + 1] = serializeIncident(inc) end
    end
    if #list > 0 then return { existing = true, incidents = list } end

    local now = os.time()
    if now - LastIncidentRequest < 600 then
        return nil, ('No new incident available for %d seconds'):format(600 - (now - LastIncidentRequest))
    end
    local incident = spawnIncident()
    if not incident then return nil, 'Could not create a fire incident' end
    LastIncidentRequest = now
    return { existing = false, incidents = { incident } }
end)

exports.sunset_core:RegisterCallback('sunset:fireExtinguish', function(source, incidentId, amount)
    if not isFirefighter(source) then return nil, 'Must be on duty as LSFD' end

    incidentId = tonumber(incidentId)
    local inc = Incidents[incidentId]
    if not inc or inc.status ~= 'active' then return nil, 'Incident not found' end

    local now = GetGameTimer()
    if now - (LastExtinguish[source] or 0) < 200 then return nil, 'Extinguishing too quickly' end
    LastExtinguish[source] = now

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'Invalid player' end
    local pCoords = GetEntityCoords(ped)
    local iCoords = inc.coords
    local dist = #(pCoords - vector3(iCoords.x, iCoords.y, iCoords.z))
    if dist > (Sunset.Fire.extinguishRange or 8.0) + 2.0 then
        return nil, 'Too far from the fire'
    end

    amount = math.min(tonumber(amount) or 0, Sunset.Fire.extinguishRate or 12)
    if amount < 1 then return nil, 'Invalid extinguish amount' end

    inc.fireHealth = math.max(0, (inc.fireHealth or 0) - amount)
    broadcastFirefighters('sunset:fire:incidentUpdate', serializeIncident(inc))

    if inc.fireHealth <= 0 then
        completeIncident(incidentId, source)
        return { completed = true }
    end

    return { fireHealth = inc.fireHealth, maxHealth = inc.maxHealth }
end)

AddEventHandler('playerDropped', function()
    LastExtinguish[source] = nil
end)

exports.sunset_core:RegisterCallback('sunset:fireAcceptDispatch', function(source, callId)
    if not isFirefighter(source) then return nil, 'Not on duty' end
    local call, err = exports.sunset_dispatch:AcceptCall(source, 'fire', callId)
    if not call then return nil, err end
    return true
end)

AddEventHandler('sunset:dispatch:serviceCommand', function(callerSource, serviceType, callId)
    if serviceType ~= 'fire' then return end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if isFirefighter(src) then
            TriggerClientEvent('sunset:client:notify', src,
                ('Fire dispatch #%s — /accept fire %s'):format(callId, callId), 'warning', 10000)
        end
    end
end)

CreateThread(function()
    Wait(30000)
    while true do
        spawnIncident()
        Wait((Sunset.Fire.incidentIntervalSec or 900) * 1000)
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(15000, spawnIncident)
end)
