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
    local attached, attachedEntity = GetVehicleTrailerVehicle(truck)
    local recovered = attached and attachedEntity == trailer
    Entity(truck).state:set('sunsetTrailerAttached', recovered, false)
    Entity(truck).state:set('sunsetTrailerNetId', NetworkGetNetworkIdFromEntity(trailer), false)
    if not recovered then
        return JC.notify('Trailer is upright but could not attach automatically — reverse into it', 'warning')
    end
    JC.notify(('Trailer recovered and attached. %d recoveries remain this shift.'):format(
        recovery.remaining or 0), 'success')
end

local function startTrucker()
    local data, err = Sunset.AwaitCallback('sunset:jobs:trucker:start')
    if not data then
        JC.notify(err or 'Could not start trucker shift', 'error')
        return
    end

    local cfg = Sunset.GetJobConfig('trucker')
    JC.sessionData = data
    JC.clearBlips()
    JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Trucker Depot')

    local truck = JC.spawnVehicle(cfg.truckModel, cfg.depot.spawn, true)
    if not truck then
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
        return
    end
    local trailer = JC.attachTrailer(truck, cfg.trailerModel, cfg.depot.trailerSpawn)
    if not trailer then
        JC.deleteVehicles()
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
        return JC.notify('Could not create the assigned trailer — try again', 'error')
    end
    local registered, registerErr = JC.registerVehiclesWithServer()
    if not registered then
        JC.deleteVehicles()
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
        return JC.notify(registerErr or 'Could not register the truck and trailer', 'error')
    end
    JC.monitorVehicles()

    JC.setWaypoint(data.pickup)
    JC.addBlip(vector3(data.pickup.x, data.pickup.y, data.pickup.z), { sprite = 478, color = 5 }, 'Cargo Pickup')
    JC.showObjective('Collect cargo', 'Drive the truck and trailer to ' .. (data.label or 'the pickup'), 0)
    JC.notify('Drive to pickup: ' .. (data.label or ''), 'info')

    CreateThread(function()
        local busy = false
        while JC.jobId == 'trucker' and JC.state ~= 'IDLE' do
            local session = JC.sessionData
            local stage = session and session.stage

            if stage == 'to_pickup' then
                local p = routePoint(session, 'pickup')
                if p then
                    JC.drawMarker(p, 255, 180, 0)
                    if isNearTruckerPoint(p, cfg) and inWorkTruck() and not busy then
                        JC.showHelp('Press ~INPUT_CONTEXT~ to load cargo')
                        if IsControlJustPressed(0, 38) then
                            busy = true
                            local newData, err2 = Sunset.AwaitCallback('sunset:jobs:trucker:atPickup')
                            busy = false
                            if newData then
                                JC.sessionData = newData
                                local delivery = routePoint(newData, 'delivery')
                                if delivery then
                                    JC.clearBlips()
                                    JC.addBlip(delivery, { sprite = 478, color = 2 }, 'Delivery')
                                    JC.setWaypoint(delivery)
                                end
                                JC.showObjective('Deliver cargo', 'Follow the GPS to the delivery point', 50)
                                JC.notify('Cargo loaded — deliver to destination', 'success')
                            else
                                JC.notify(err2 or 'Could not load cargo at the pickup', 'error')
                            end
                        end
                    end
                end
            elseif stage == 'to_delivery' then
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
                                JC.showObjective('Return the truck', 'Take the truck and trailer back to the depot', 90)
                                JC.notify(('Delivered! +$%s — return truck to depot'):format(result.pay or 0), 'success')
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
Sunset.Jobs.StartTrucker = startTrucker

RegisterCommand('recovertrailer', function()
    recoverTrailer()
end, false)

TriggerEvent('chat:addSuggestion', '/recovertrailer', 'Right and reattach your assigned Trucker trailer')
