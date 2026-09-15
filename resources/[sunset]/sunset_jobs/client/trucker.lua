local JC = Sunset.JobClient

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 3000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return NetworkHasControlOfEntity(entity)
end

local function isNearTruckerPoint(coords, cfg)
    local p = GetEntityCoords(PlayerPedId())
    local t = type(coords) == 'vector3' and coords or vector3(coords.x, coords.y, coords.z)
    local dx, dy = p.x - t.x, p.y - t.y
    if math.sqrt(dx * dx + dy * dy) > (cfg.deliveryRadius or 25.0) then return false end
    return math.abs(p.z - t.z) <= (cfg.deliveryZTolerance or 8.0)
end

local function routePoint(session, key)
    local point = session and session[key]
    if not point then return nil end
    return vector3(point.x, point.y, point.z)
end

local function inWorkTruck()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end
    local truck = JC.vehicles[1]
    if not truck or not DoesEntityExist(truck) then return true end
    return GetVehiclePedIsIn(ped, false) == truck
end

local function recoverTrailer()
    -- Only valid on trailer routes (e.g. phantom/fuel routes)
    if JC.sessionData and JC.sessionData.hasTrailer == false then
        return JC.notify('This truck does not use a trailer.', 'info')
    end
    local recovery, err = Sunset.AwaitCallback('sunset:jobs:recoverTrailer')
    if not recovery then
        return JC.notify(err or 'Trailer recovery is not available', 'error')
    end

    if recovery.respawn then
        local truck = NetworkGetEntityFromNetworkId(recovery.truckNetId or 0)
        if truck == 0 or not DoesEntityExist(truck) then
            truck = JC.vehicles[1]
        end
        local spawned, spawnErr = JC.respawnTrailer(truck, recovery.trailerModel)
        if not spawned then
            return JC.notify(spawnErr or 'Could not spawn replacement trailer', 'error')
        end
        return JC.notify(('Replacement trailer spawned. %d recoveries remain this shift.'):format(
            recovery.remaining or 0), 'success')
    end

    local truck = NetworkGetEntityFromNetworkId(recovery.truckNetId or 0)
    local trailer = NetworkGetEntityFromNetworkId(recovery.trailerNetId or 0)
    if truck == 0 or trailer == 0 or not DoesEntityExist(truck) or not DoesEntityExist(trailer) then
        return JC.notify('Could not find your assigned truck or trailer', 'error')
    end
    if not requestControl(trailer) then
        return JC.notify('Could not take control of the trailer — try again', 'error')
    end

    SetVehicleHandbrake(truck, true)
    SetEntityVelocity(trailer, 0.0, 0.0, 0.0)
    DetachVehicleFromTrailer(truck)
    Wait(150)

    local target = GetOffsetFromEntityInWorldCoords(truck, 0.0, -10.5, 1.0)
    local heading = GetEntityHeading(truck)
    SetEntityCoordsNoOffset(trailer, target.x, target.y, target.z, false, false, false)
    SetEntityRotation(trailer, 0.0, 0.0, heading, 2, true)
    SetEntityHeading(trailer, heading)
    SetVehicleOnGroundProperly(trailer)
    Wait(250)
    AttachVehicleToTrailer(truck, trailer, 1.0)
    SetVehicleHandbrake(truck, false)

    Wait(250)
    local isAttached = IsVehicleAttachedToTrailer(truck) == 1 or IsVehicleAttachedToTrailer(truck) == true
    local attached, attachedEntity = GetVehicleTrailerVehicle(truck)
    local dist = #(GetEntityCoords(truck) - GetEntityCoords(trailer))
    local recovered = isAttached or (attached and (attachedEntity == trailer or dist <= 20.0)) or dist <= 16.0
    if not recovered then
        return JC.notify('Trailer is upright but could not attach automatically — reverse into it', 'warning')
    end
    TriggerServerEvent('sunset:jobs:syncTrailerStatus', true)
    JC.notify(('Trailer recovered and attached. %d recoveries remain this shift.'):format(
        recovery.remaining or 0), 'success')
end

local function startTrucker(selectedRouteIdx)
    local data, err = Sunset.AwaitCallback('sunset:jobs:trucker:start', selectedRouteIdx)
    if not data then
        JC.notify(err or 'Could not start trucker shift', 'error')
        return
    end

    local cfg = Sunset.GetJobConfig('trucker')
    -- Wait a tick for sessionStarted to arrive so JC.jobId / JC.state are set
    Wait(100)

    JC.sessionData = data
    JC.clearBlips()
    JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Trucker Depot')

    -- Clear any task/animation before warping into the vehicle
    ClearPedTasksImmediately(PlayerPedId())

    -- Spawn truck on road spawn (outside the terminal)
    local truckModel = data.truckModel or cfg.truckModel
    local truck = JC.spawnVehicle(truckModel, cfg.depot.spawn, true)
    if not truck then
        JC.notify('Could not spawn the truck — try again', 'error')
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
        return
    end

    if data.hasTrailer then
        local trailerModel = data.trailerModel or cfg.trailerModel
        local trailer = JC.attachTrailer(truck, trailerModel, cfg.depot.trailerSpawn)
        if not trailer then
            JC.deleteVehicles()
            Sunset.AwaitCallback('sunset:jobs:cancelWork')
            JC.notify('Could not create the assigned trailer — try again', 'error')
            return
        end
    end

    local registered, registerErr = JC.registerVehiclesWithServer()
    if not registered then
        JC.deleteVehicles()
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
        JC.notify(registerErr or 'Could not register the truck', 'error')
        return
    end
    JC.monitorVehicles()

    -- No-collision with nearby players at spawn (prevents vehicles spawning into each other)
    local spawnPos = vector3(cfg.depot.spawn.x, cfg.depot.spawn.y, cfg.depot.spawn.z)
    local myPed   = PlayerPedId()
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local theirPed = GetPlayerPed(pid)
            if DoesEntityExist(theirPed) then
                SetEntityNoCollisionEntity(myPed,  theirPed, false)
                SetEntityNoCollisionEntity(truck,  theirPed, false)
                if IsPedInAnyVehicle(theirPed, false) then
                    local theirVeh = GetVehiclePedIsIn(theirPed, false)
                    if theirVeh ~= 0 and DoesEntityExist(theirVeh) then
                        SetEntityNoCollisionEntity(truck, theirVeh, false)
                    end
                end
            end
        end
    end
    -- Lift collision once outside the 50 m spawn zone (or after 15 s)
    CreateThread(function()
        local deadline = GetGameTimer() + 15000
        while GetGameTimer() < deadline do
            if #(GetEntityCoords(PlayerPedId()) - spawnPos) > 50.0 then break end
            Wait(500)
        end
    end)

    -- Cargo is loaded at spawn — go straight to delivery
    local delivery = vector3(data.delivery.x, data.delivery.y, data.delivery.z)
    JC.addBlip(delivery, { sprite = 478, color = 2 }, 'Delivery')
    JC.setWaypoint(data.delivery)
    JC.showObjective('Deliver cargo', 'Follow the GPS to: ' .. (data.label or 'destination'), 30)
    JC.notify('Deliver to: ' .. (data.label or 'destination') .. '. Follow the map.', 'info', 8000)

    -- Job loop: delivery → return depot
    CreateThread(function()
        local busy = false
        while JC.jobId == 'trucker' and JC.state ~= 'IDLE' do
            local session = JC.sessionData
            local stage = session and session.stage

            if stage == 'to_delivery' then
                local d = routePoint(session, 'delivery')
                if d then
                    JC.drawMarker(d, 46, 204, 113)
                    if isNearTruckerPoint(d, cfg) and inWorkTruck() and not busy then
                        JC.showHelp('Press ~INPUT_CONTEXT~ to deliver cargo')
                        if IsControlJustPressed(0, 38) then
                            busy = true
                            local result, err2 = Sunset.AwaitCallback('sunset:jobs:trucker:deliver')
                            busy = false
                            if result then
                                JC.sessionData = JC.sessionData or {}
                                JC.sessionData.stage = result.stage or 'return_depot'
                                JC.clearBlips()
                                JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Return Depot')
                                JC.setWaypoint(cfg.depot.coords)
                                JC.showObjective('Return the truck', 'Drive back to the depot', 90)
                                local bonusStr = (result.bonusPct and result.bonusPct > 0)
                                    and (' (+%d%% rank bonus)'):format(result.bonusPct) or ''
                                JC.notify(('Delivered! +$%d%s — return the truck to the depot'):format(
                                    result.pay or 0, bonusStr), 'success', 8000)
                            else
                                JC.notify(err2 or 'Could not deliver cargo', 'error')
                            end
                        end
                    end
                end
            elseif stage == 'return_depot' then
                JC.drawMarker(cfg.depot.coords, 52, 152, 219)
                if JC.isNear(cfg.depot.coords, cfg.returnRadius or 25.0) and inWorkTruck() and not busy then
                    JC.showHelp('Press ~INPUT_CONTEXT~ to return the truck')
                    if IsControlJustPressed(0, 38) then
                        busy = true
                        local ok, err3 = Sunset.AwaitCallback('sunset:jobs:trucker:returnDepot')
                        busy = false
                        if ok then
                            JC.deleteVehicles()
                            SetWaypointOff()
                            break
                        else
                            JC.notify(err3 or 'Could not return the truck to the depot', 'error')
                        end
                    end
                end
            end
            Wait(0)
        end
    end)
end

Sunset.Jobs = Sunset.Jobs or {}
Sunset.Jobs.StartTrucker = startTrucker   -- called as StartTrucker(routeIndex)

RegisterCommand('recovertrailer', function()
    recoverTrailer()
end, false)

TriggerEvent('chat:addSuggestion', '/recovertrailer', 'Right and reattach your assigned Trucker trailer')
