local incidents = {}
local extinguisherHash = joaat(Sunset.Fire.extinguisherWeapon or 'WEAPON_FIREEXTINGUISHER')

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function distTo(coords)
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    return #(p - vector3(coords.x, coords.y, coords.z))
end

local function ensureExtinguisher()
    local ped = PlayerPedId()
    if HasPedGotWeapon(ped, extinguisherHash, false) then return true end
    GiveWeaponToPed(ped, extinguisherHash, 250, false, true)
    return true
end

local function spawnIncidentVehicle(inc)
    if inc.vehicle and DoesEntityExist(inc.vehicle) then return inc.vehicle end
    local model = joaat(inc.vehicleModel or 'sultan')
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end

    local c = inc.coords
    local veh = CreateVehicle(model, c.x, c.y, c.z, c.w or 0.0, true, false)
    if veh == 0 then return nil end

    SetEntityAsMissionEntity(veh, true, true)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if netId and netId ~= 0 then
        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, true)
    end
    SetVehicleEngineHealth(veh, 100.0)
    SetVehicleBodyHealth(veh, 200.0)
    SetVehicleUndriveable(veh, true)
    SetVehicleDoorOpen(veh, 4, false, false)
    local fireHandle = StartScriptFire(c.x, c.y, c.z, 25, false)
    SetModelAsNoLongerNeeded(model)

    inc.vehicle = veh
    inc.fireHandles = inc.fireHandles or {}
    inc.fireHandles[#inc.fireHandles + 1] = fireHandle
    return veh
end

local function storeIncident(serverIncident)
    local current = incidents[serverIncident.id]
    if current then
        serverIncident.vehicle = current.vehicle
        serverIncident.fireHandles = current.fireHandles
    end
    incidents[serverIncident.id] = serverIncident
    return serverIncident
end

local function cleanupIncident(incidentId)
    local inc = incidents[incidentId]
    if not inc then return end
    if inc.fireHandles then
        for _, handle in ipairs(inc.fireHandles) do
            if handle then RemoveScriptFire(handle) end
        end
    end
    if inc.vehicle and DoesEntityExist(inc.vehicle) then
        SetEntityAsMissionEntity(inc.vehicle, true, true)
        DeleteVehicle(inc.vehicle)
    end
    incidents[incidentId] = nil
end

local function syncIncidents(list, routeFirst)
    local active = {}
    for _, inc in ipairs(list or {}) do
        active[inc.id] = true
        inc = storeIncident(inc)
        spawnIncidentVehicle(inc)
    end
    for id in pairs(incidents) do
        if not active[id] then cleanupIncident(id) end
    end
    if routeFirst and list and list[1] then
        SetNewWaypoint(list[1].coords.x, list[1].coords.y)
        notify(('GPS set to fire incident #%s'):format(list[1].id), 'success')
    end
end

RegisterNetEvent('sunset:fire:newIncident', function(inc)
    if not inc or not inc.id then return end
    inc = storeIncident(inc)
    spawnIncidentVehicle(inc)
    SetNewWaypoint(inc.coords.x, inc.coords.y)
    notify(('Vehicle fire reported — incident #%s'):format(inc.id), 'warning', 8000)
end)

RegisterNetEvent('sunset:fire:incidentUpdate', function(inc)
    if not inc or not inc.id then return end
    storeIncident(inc)
end)

RegisterNetEvent('sunset:fire:incidentEnded', function(incidentId)
    cleanupIncident(incidentId)
    notify('Fire incident cleared', 'success')
end)

CreateThread(function()
    while true do
        local waitMs = 500
        local char = exports.sunset_core:GetCharacter()
        local factionId = char and Sunset.GetCharacterFaction(char)
        local onDuty = exports.sunset_factions:IsOnDuty()

        if factionId == Sunset.Fire.factionId and onDuty then
            local ped = PlayerPedId()
            local aiming = false
            local targetInc = nil

            for id, inc in pairs(incidents) do
                if inc.status == 'active' and distTo(inc.coords) <= (Sunset.Fire.extinguishRange or 8.0) then
                    targetInc = inc
                    break
                end
            end

            if targetInc then
                ensureExtinguisher()
                SetCurrentPedWeapon(ped, extinguisherHash, true)
                if IsPedShooting(ped) and GetSelectedPedWeapon(ped) == extinguisherHash then
                    aiming = true
                end
            end

            if aiming and targetInc then
                waitMs = 250
                local result, err = Sunset.AwaitCallback('sunset:fireExtinguish', targetInc.id, Sunset.Fire.extinguishRate or 12)
                if result and result.completed then
                    cleanupIncident(targetInc.id)
                elseif not result and err then
                    notify(err, 'error')
                end
            end
        else
            waitMs = 1500
        end
        Wait(waitMs)
    end
end)

CreateThread(function()
    Wait(4000)
    TriggerEvent('chat:addSuggestion', '/firecalls', 'List active fire incidents (LSFD on duty)')
end)

RegisterCommand('firecalls', function()
    CreateThread(function()
        local list, err = Sunset.AwaitCallback('sunset:fireGetIncidents')
        if not list then return notify(err or 'Could not load fire incidents', 'error') end
        if #list < 1 then return notify('No active fire incidents — use /firestart', 'info') end
        syncIncidents(list, true)
        for _, inc in ipairs(list) do
            notify(('#%s — %s (%s%% remaining)'):format(
                inc.id, inc.label, math.floor((inc.fireHealth / inc.maxHealth) * 100)), 'info', 6000)
        end
    end)
end, false)

RegisterCommand('firestart', function()
    CreateThread(function()
        local result, err = Sunset.AwaitCallback('sunset:fireRequestIncident')
        if not result then return notify(err or 'Could not request incident', 'error') end
        syncIncidents(result.incidents or {}, true)
        notify(result.existing and 'Existing LSFD incident loaded' or 'New LSFD incident dispatched', 'warning')
    end)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(incidents) do
        cleanupIncident(id)
    end
end)
