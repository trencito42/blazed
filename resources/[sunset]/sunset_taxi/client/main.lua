local depotVehicle = nil
local activeRide = nil
local lastTaxiAppData = nil

local MAP = Sunset.Taxi.mapBounds or { minX = -4000, maxX = 6000, minY = -5500, maxY = 8000 }

local function isInTaxiVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return false end
    return Sunset.Taxi.IsValidTaxiVehicle(GetEntityModel(veh))
end

local function requireTaxiVehicle()
    if isInTaxiVehicle() then return true end
    notify('You must use a company cab, not a personal vehicle', 'error')
    return false
end

local function coordsFromServerId(serverId)
    serverId = tonumber(serverId)
    if not serverId then return nil end
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return vector3(c.x, c.y, c.z)
end

local function distKm(a, b)
    if not a or not b then return nil end
    return #(a - b) / 1000.0
end

local function pushTaxiDistanceUpdate(ride, extra)
    local payload = extra or {}
    if lastTaxiAppData then
        for k, v in pairs(lastTaxiAppData) do
            if payload[k] == nil then payload[k] = v end
        end
    end
    if ride then payload.activeRide = ride end
    exports.sunset_ui:Send('taxiUpdate', payload)
end

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function percentToWorld(px, py)
    px = math.max(0, math.min(100, tonumber(px) or 0))
    py = math.max(0, math.min(100, tonumber(py) or 0))
    local x = MAP.minX + (px / 100.0) * (MAP.maxX - MAP.minX)
    local y = MAP.maxY - (py / 100.0) * (MAP.maxY - MAP.minY)
    return x, y
end

local function groundZ(x, y)
    local found, z = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, 1000.0, false)
    return found and z or 30.0
end

local function streetLabel(x, y, z)
    local streetHash, crossingHash = GetStreetNameAtCoord(x + 0.0, y + 0.0, z + 0.0)
    local street = GetStreetNameFromHashKey(streetHash) or ''
    local crossing = GetStreetNameFromHashKey(crossingHash) or ''
    if crossing ~= '' and street ~= '' then
        return street .. ' / ' .. crossing
    end
    if street ~= '' then return street end
    return ('Map pin (%.0f, %.0f)'):format(x, y)
end

local function resolveDestination(px, py)
    local x, y = percentToWorld(px, py)
    local z = groundZ(x, y)
    return {
        x = x,
        y = y,
        z = z,
        label = streetLabel(x, y, z),
    }
end

local function setWaypoint(coords)
    if not coords then return end
    SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
end

local function getPickupCoords()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function clientPlayerPos()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x + 0.0, y = coords.y + 0.0 }
end

local function refreshPhoneTaxi()
    CreateThread(function()
        local data, err = Sunset.AwaitCallback('sunset:getTaxiAppData')
        if data then
            data.playerPos = clientPlayerPos()
            lastTaxiAppData = data
            if data.activeRide then
                activeRide = data.activeRide
                if activeRide.isDriver then activeRide.isDriver = true end
            end
            exports.sunset_ui:Send('taxiUpdate', data)
        else
            exports.sunset_ui:Send('taxiUpdate', {
                appName = Sunset.Taxi and Sunset.Taxi.appName or 'Downtown Cab',
                destinations = {},
                playerPos = nil,
                error = err or 'Could not load taxi app',
            })
            notify(err or 'Could not load taxi app', 'error')
        end
    end)
end

local function deleteDepotVehicle()
    if depotVehicle and DoesEntityExist(depotVehicle) then
        SetEntityAsMissionEntity(depotVehicle, true, true)
        DeleteVehicle(depotVehicle)
    end
    depotVehicle = nil
end

local function spawnDepotVehicle()
    local faction = Sunset.Factions and Sunset.Factions.taxi
    local depot = faction and faction.depot
    if not depot or not depot.spawn then
        notify('No cab depot configured', 'error')
        return
    end

    deleteDepotVehicle()

    local model = joaat(depot.vehicle or 'taxi')
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then
            notify('Failed to load cab model', 'error')
            return
        end
        Wait(10)
    end

    local s = depot.spawn
    local veh = CreateVehicle(model, s.x, s.y, s.z, s.w, true, false)
    if veh == 0 then
        SetModelAsNoLongerNeeded(model)
        notify('Could not spawn cab', 'error')
        return
    end

    SetVehicleNumberPlateText(veh, 'CAB' .. math.random(100, 999))
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetVehicleColours(veh, 88, 88)
    SetModelAsNoLongerNeeded(model)

    depotVehicle = veh
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    notify('Cab ready — open Downtown Cab app for rides', 'success')
end

RegisterNetEvent('sunset:client:taxiRefresh', function()
    refreshPhoneTaxi()
end)

RegisterNetEvent('sunset:client:taxiNewOffer', function(ride)
    notify(('New ride: $%s → %s'):format(ride.fare or 0, ride.destination and ride.destination.label or '?'), 'info')
    refreshPhoneTaxi()
end)

RegisterNetEvent('sunset:client:taxiRideTaken', function()
    refreshPhoneTaxi()
end)

RegisterNetEvent('sunset:client:taxiRideAccepted', function(ride)
    activeRide = ride
    if ride then ride.isDriver = true end
    if ride and ride.pickup then
        setWaypoint(ride.pickup)
        notify('GPS set to passenger pickup', 'success')
    end
    refreshPhoneTaxi()
end)

RegisterNetEvent('sunset:client:taxiRideInProgress', function(ride)
    activeRide = ride
    if ride and ride.destination then
        setWaypoint(ride.destination)
        notify('GPS set to destination', 'success')
    end
    refreshPhoneTaxi()
end)

RegisterNetEvent('sunset:client:taxiRideEnded', function()
    activeRide = nil
    refreshPhoneTaxi()
end)

AddEventHandler('sunset:nui:taxiRefresh', function()
    refreshPhoneTaxi()
end)

AddEventHandler('sunset:nui:taxiEstimate', function(data)
    CreateThread(function()
        local estimate
        if data.destination then
            estimate = Sunset.AwaitCallback('sunset:taxiEstimateCoords', getPickupCoords(), data.destination)
        else
            estimate = Sunset.AwaitCallback('sunset:taxiEstimate', data.destinationId, getPickupCoords())
        end
        if estimate then
            exports.sunset_ui:Send('taxiEstimate', estimate)
        end
    end)
end)

AddEventHandler('sunset:nui:taxiRequestRide', function(data)
    CreateThread(function()
        local ride, err
        if data.destination then
            ride, err = Sunset.AwaitCallback('sunset:taxiRequestRideCoords', getPickupCoords(), data.destination)
        else
            ride, err = Sunset.AwaitCallback('sunset:taxiRequestRide', data.destinationId, getPickupCoords())
        end
        if not ride then
            notify(err or 'Could not request ride', 'error')
            return
        end
        refreshPhoneTaxi()
    end)
end)

AddEventHandler('sunset:nui:taxiPickMap', function(data)
    if data.x and data.y then
        local x = tonumber(data.x) + 0.0
        local y = tonumber(data.y) + 0.0
        local z = groundZ(x, y)
        exports.sunset_ui:Send('taxiPickResult', {
            x = x,
            y = y,
            z = z,
            label = streetLabel(x, y, z),
        })
        return
    end

    local dest = resolveDestination(data.px, data.py)
    exports.sunset_ui:Send('taxiPickResult', dest)
end)

AddEventHandler('sunset:nui:taxiPickPlace', function(data)
    local row = Sunset.Taxi.FindDestination(data.destinationId)
    if not row or not row.coords then
        notify('Unknown place', 'error')
        return
    end
    local c = row.coords
    exports.sunset_ui:Send('taxiPickResult', {
        x = c.x,
        y = c.y,
        z = c.z,
        label = row.label,
        destinationId = row.id,
    })
end)

AddEventHandler('sunset:nui:taxiAcceptRide', function(data)
    CreateThread(function()
        if not requireTaxiVehicle() then return end
        local ride, err = Sunset.AwaitCallback('sunset:taxiAcceptRide', data.rideId)
        if not ride then notify(err or 'Could not accept', 'error') end
        refreshPhoneTaxi()
    end)
end)

AddEventHandler('sunset:nui:taxiCancelRide', function()
    CreateThread(function()
        local ok, err = Sunset.AwaitCallback('sunset:taxiCancelRide')
        if ok then notify('Ride cancelled', 'warning') else notify(err or 'Failed', 'error') end
        refreshPhoneTaxi()
    end)
end)

AddEventHandler('sunset:nui:taxiPickup', function()
    CreateThread(function()
        if not requireTaxiVehicle() then return end
        local ride, err = Sunset.AwaitCallback('sunset:taxiPickupPassenger')
        if not ride then notify(err or 'Failed', 'error') end
        refreshPhoneTaxi()
    end)
end)

AddEventHandler('sunset:nui:taxiComplete', function()
    CreateThread(function()
        if not requireTaxiVehicle() then return end
        local ok, err = Sunset.AwaitCallback('sunset:taxiCompleteRide')
        if not ok then notify(err or 'Failed', 'error') end
        refreshPhoneTaxi()
    end)
end)

AddEventHandler('sunset:nui:taxiSetAvailable', function(data)
    CreateThread(function()
        Sunset.AwaitCallback('sunset:taxiSetAvailable', data.available == true)
        refreshPhoneTaxi()
    end)
end)

AddEventHandler('sunset:nui:taxiTip', function(data)
    CreateThread(function()
        local ok, err = Sunset.AwaitCallback('sunset:taxiTip', tonumber(data.amount))
        if ok then notify('Tip sent — thank you!', 'success')
        else notify(err or 'Could not send tip', 'error') end
    end)
end)

local proximityHintAt = 0

CreateThread(function()
    while true do
        local waitMs = Sunset.Taxi.distanceUpdateMs or 1500
        local ride = activeRide or (lastTaxiAppData and lastTaxiAppData.activeRide)
        if ride and (ride.status == 'accepted' or ride.status == 'in_progress') then
            local myCoords = GetEntityCoords(PlayerPedId())
            local arrivingKm = Sunset.Taxi.arrivingDistanceKm or 0.15
            local completeRadius = Sunset.Taxi.completeRadius or Sunset.Taxi.dropoffRadius or 60.0
            local pickupRadius = Sunset.Taxi.pickupRadius or 18.0

            local driverDistanceKm = nil
            local passengerDistanceKm = nil
            local driverStatusText = nil
            local passengerStatusText = nil
            local nearDestination = false
            local nearPickup = false

            local char = exports.sunset_core:GetCharacter()
            local isDriver = ride.isDriver or (char and Sunset.GetCharacterFaction(char) == 'taxi' and exports.sunset_factions:IsOnDuty())

            if isDriver then
                local targetCoords
                if ride.status == 'accepted' then
                    if ride.pickup then
                        targetCoords = vector3(ride.pickup.x, ride.pickup.y, ride.pickup.z)
                    end
                    if ride.passengerServerId then
                        local pCoords = coordsFromServerId(ride.passengerServerId)
                        if pCoords then targetCoords = pCoords end
                    end
                elseif ride.status == 'in_progress' and ride.passengerServerId then
                    local pCoords = coordsFromServerId(ride.passengerServerId)
                    if pCoords then targetCoords = pCoords end
                end

                if targetCoords then
                    passengerDistanceKm = distKm(myCoords, targetCoords)
                    if ride.status == 'accepted' then
                        nearPickup = #(myCoords - targetCoords) <= pickupRadius
                        passengerStatusText = nearPickup and 'At pickup' or 'En route to passenger'
                    else
                        passengerStatusText = 'Passenger on board'
                    end
                end

                if ride.status == 'in_progress' and ride.destination then
                    local dest = vector3(ride.destination.x, ride.destination.y, ride.destination.z)
                    nearDestination = #(myCoords - dest) <= completeRadius
                end
            else
                if ride.driverServerId then
                    local dCoords = coordsFromServerId(ride.driverServerId)
                    if dCoords then
                        driverDistanceKm = distKm(myCoords, dCoords)
                        if ride.status == 'accepted' then
                            driverStatusText = driverDistanceKm <= arrivingKm and 'Driver arriving' or 'Driver en route'
                        else
                            driverStatusText = 'Trip in progress'
                        end
                    elseif ride.status == 'accepted' then
                        driverStatusText = 'Driver en route'
                    end
                end
            end

            pushTaxiDistanceUpdate(ride, {
                driverDistanceKm = driverDistanceKm,
                passengerDistanceKm = passengerDistanceKm,
                driverStatusText = driverStatusText,
                passengerStatusText = passengerStatusText,
                nearDestination = nearDestination,
                nearPickup = nearPickup,
            })
        else
            waitMs = 2000
        end
        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        local waitMs = 1500
        if activeRide then
            waitMs = 500
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local pickupR = Sunset.Taxi.pickupRadius or 18.0
            local dropR = Sunset.Taxi.dropoffRadius or 28.0
            local char = exports.sunset_core:GetCharacter()
            local isDriver = char and Sunset.GetCharacterFaction(char) == 'taxi' and exports.sunset_factions:IsOnDuty()

            if isDriver and activeRide.isDriver then
                if activeRide.status == 'accepted' and activeRide.pickup then
                    local p = activeRide.pickup
                    local dist = #(coords - vector3(p.x, p.y, p.z))
                    if dist <= pickupR and GetGameTimer() - proximityHintAt > 8000 then
                        proximityHintAt = GetGameTimer()
                        notify('Near pickup — use the Cab app to confirm passenger picked up', 'info')
                    end
                elseif activeRide.status == 'in_progress' and activeRide.destination then
                    local d = activeRide.destination
                    local dist = #(coords - vector3(d.x, d.y, d.z))
                    if dist <= dropR and GetGameTimer() - proximityHintAt > 8000 then
                        proximityHintAt = GetGameTimer()
                        notify('Near destination — complete trip in the Cab app', 'info')
                    end
                end
            end
        end
        Wait(waitMs)
    end
end)

AddEventHandler('sunset:world:taxiDepot', function()
    local char = exports.sunset_core:GetCharacter()
    if not char or Sunset.GetCharacterFaction(char) ~= 'taxi' then
        notify('You must work for Downtown Cab Co.', 'error')
        return
    end
    if not exports.sunset_factions:IsOnDuty() then
        notify('Go on duty at the cab office first ([E] at yellow marker)', 'error')
        return
    end
    spawnDepotVehicle()
end)

CreateThread(function()
    Wait(4000)
    local faction = Sunset.Factions and Sunset.Factions.taxi
    local depot = faction and faction.depot
    if not depot or not depot.coords then return end

    TriggerEvent('sunset:world:registerTaxiDepot', depot)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deleteDepotVehicle()
end)
