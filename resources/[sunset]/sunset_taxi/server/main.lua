local Rides = {}
local rideSeq = 0
local DriverAvailable = {}
local DriverSessionStats = {}
local MeterThreads = {}


local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function findSourceByCharacterId(characterId)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = getChar(src)
        if c and c.id == characterId then
            return src
        end
    end
    return nil
end

local function isTaxiDriver(source)
    local char = getChar(source)
    if not char then return false end
    local factionId = Sunset.GetCharacterFaction(char)
    if factionId ~= Sunset.Taxi.factionId then return false end
    return exports.sunset_factions:IsOnDuty(source)
end

local function encodeCoords(coords)
    return {
        x = coords.x or coords[1] or 0.0,
        y = coords.y or coords[2] or 0.0,
        z = coords.z or coords[3] or 0.0,
    }
end

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if type(c) == 'vector3' then return c end
    return vector3(c.x or c[1] or 0.0, c.y or c[2] or 0.0, c.z or c[3] or 0.0)
end

local function distanceBetween(a, b)
    if not a or not b then return 999999.0 end
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

local function getDriverVehicleModel(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    return GetEntityModel(veh)
end

local function requireTaxiVehicle(source)
    local model = getDriverVehicleModel(source)
    if not model then
        return false, 'You must be in a cab vehicle'
    end
    if not Sunset.Taxi.IsValidTaxiVehicle(model) then
        return false, 'You must use a company cab, not a personal vehicle'
    end
    return true
end

local function rideForPassenger(charId)
    for _, ride in pairs(Rides) do
        if ride.passengerCharId == charId and ride.status ~= 'completed' and ride.status ~= 'cancelled' then
            return ride
        end
    end
end

local function rideForDriver(charId)
    for _, ride in pairs(Rides) do
        if ride.driverCharId == charId and ride.status ~= 'completed' and ride.status ~= 'cancelled' then
            return ride
        end
    end
end

local function serializeRide(ride, viewerSource)
    if not ride then return nil end
    local viewerChar = getChar(viewerSource)
    local out = {
        id = ride.id,
        status = ride.status,
        fare = ride.fare,
        meterFare = ride.meterFare,
        distanceKm = ride.distanceKm,
        meterKm = ride.meterKm,
        pickup = ride.pickup,
        destination = ride.destination,
        passengerName = ride.passengerName,
        driverName = ride.driverName,
        createdAt = ride.createdAt,
        isPassenger = viewerChar and viewerChar.id == ride.passengerCharId,
        isDriver = viewerChar and viewerChar.id == ride.driverCharId,
        passengerServerId = ride.passengerSource,
        driverServerId = ride.driverSource,
    }
    return out
end

local function pushTaxiUpdate(source)
    TriggerClientEvent('sunset:client:taxiRefresh', source)
end

local function recordTaxiActivity(driverSource, ride, amount)
    local char = getChar(driverSource)
    if not char then return end
    local factionId = Sunset.GetCharacterFaction(char)
    if factionId ~= Sunset.Taxi.factionId then return end
    pcall(function()
        if FactionCore and FactionCore.auditLog then
            FactionCore.auditLog(factionId, char.id, 'taxi_ride_complete', ride.passengerCharId, {
                fare = amount,
                distanceKm = ride.meterKm or ride.distanceKm,
                rideId = ride.id,
            })
        end
    end)
    TriggerEvent('sunset:faction:activityComplete', driverSource, 'transport', {
        fare = amount,
        distanceKm = ride.meterKm or ride.distanceKm,
    })
end

local function createDispatchForRide(ride)
    pcall(function()
        local call = exports.sunset_dispatch:CreateServiceCall(
            ride.passengerSource,
            'taxi',
            ride.pickup,
            { rideId = ride.id, fare = ride.fare },
            ('Cab to %s — $%s'):format(ride.destination.label or 'destination', ride.fare)
        )
        if call and call.id then
            ride.dispatchCallId = call.id
        end
    end)
end

local function stopMeter(rideId)
    MeterThreads[rideId] = nil
end

local function startMeter(ride)
    local cfg = Sunset.Taxi.meter or {}
    local tickMs = cfg.tickMs or 2000
    local minMove = cfg.minMoveMeters or 4.0
    local idleSec = cfg.idleTimeoutSec or 45
    ride.meterKm = 0.0
    ride.meterFare = ride.fare or Sunset.Taxi.minFare
    ride.lastMeterPos = getPlayerCoords(ride.driverSource)
    ride.lastMoveAt = os.time()
    MeterThreads[ride.id] = true

    CreateThread(function()
        while MeterThreads[ride.id] and ride.status == 'in_progress' do
            Wait(tickMs)
            if not ride.driverSource or ride.status ~= 'in_progress' then break end

            local coords = getPlayerCoords(ride.driverSource)
            local last = ride.lastMeterPos
            if coords and last then
                local moved = distanceBetween(coords, last)
                if moved >= minMove then
                    ride.meterKm = (ride.meterKm or 0) + (moved / 1000.0)
                    ride.lastMeterPos = coords
                    ride.lastMoveAt = os.time()
                    local baseFare = Sunset.Taxi.baseFare or 75
                    local perKm = Sunset.Taxi.perKm or 35
                    local computed = math.floor(baseFare + ride.meterKm * perKm)
                    local maxFare = math.floor((ride.fare or computed) * (cfg.maxFareMultiplier or 1.5))
                    ride.meterFare = math.min(math.max(computed, Sunset.Taxi.minFare or 100), maxFare)
                end
            end

            TriggerClientEvent('sunset:client:taxiMeterUpdate', ride.driverSource, {
                rideId = ride.id,
                meterKm = ride.meterKm,
                meterFare = ride.meterFare,
            })
            local passengerSrc = findSourceByCharacterId(ride.passengerCharId)
            if passengerSrc then
                TriggerClientEvent('sunset:client:taxiMeterUpdate', passengerSrc, {
                    rideId = ride.id,
                    meterKm = ride.meterKm,
                    meterFare = ride.meterFare,
                })
            end
        end
        MeterThreads[ride.id] = nil
    end)
end

local function broadcastDrivers(event, payload)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if isTaxiDriver(src) and DriverAvailable[src] ~= false then
            TriggerClientEvent(event, src, payload)
        end
    end
end

local function addSociety(amount)
    local cut = math.floor(amount or 0)
    if cut <= 0 then return end
    pcall(function()
        MySQL.update.await('UPDATE societies SET balance = balance + ? WHERE name = ?', { cut, 'taxi' })
    end)
end

local function getDriverStats(charId)
    local session = DriverSessionStats[charId] or { rides = 0, earnings = 0 }
    local todayRides, todayEarnings = 0, 0
    pcall(function()
        local row = MySQL.single.await([[
            SELECT COUNT(*) AS rides, COALESCE(SUM(fare), 0) AS earnings
            FROM taxi_rides
            WHERE driver_character_id = ? AND status = 'completed' AND DATE(completed_at) = CURDATE()
        ]], { charId })
        if row then
            todayRides = tonumber(row.rides) or 0
            todayEarnings = tonumber(row.earnings) or 0
        end
    end)
    return {
        sessionRides = session.rides or 0,
        sessionEarnings = session.earnings or 0,
        todayRides = todayRides,
        todayEarnings = todayEarnings,
    }
end

local function buildAppData(source)
    local char = getChar(source)
    if not char then return nil end

    local destinations = {}
    for _, dest in ipairs(Sunset.Taxi.BuildAllDestinations()) do
        local c = dest.coords
        destinations[#destinations + 1] = {
            id = dest.id,
            label = dest.label,
            category = dest.category,
            x = c.x,
            y = c.y,
        }
    end

    local ped = GetPlayerPed(source)
    local px, py = GetEntityCoords(ped)
    if type(px) == 'vector3' then
        px, py = px.x, px.y
    end

    local data = {
        appName = Sunset.Taxi.appName,
        appShort = Sunset.Taxi.appShort,
        isDriver = Sunset.GetCharacterFaction(char) == Sunset.Taxi.factionId,
        onDuty = isTaxiDriver(source),
        driverAvailable = DriverAvailable[source] ~= false,
        destinations = destinations,
        mapBounds = Sunset.Taxi.mapBounds,
        playerPos = { x = px + 0.0, y = py + 0.0 },
        activeRide = nil,
        pendingOffers = {},
        pricing = {
            base = Sunset.Taxi.baseFare,
            perKm = Sunset.Taxi.perKm,
            min = Sunset.Taxi.minFare,
            companyCut = math.floor((Sunset.Taxi.companyCut or 0.12) * 100),
        },
        tipOptions = Sunset.Taxi.tipOptions or { 25, 50, 100 },
    }

    if Sunset.GetCharacterFaction(char) == Sunset.Taxi.factionId then
        data.driverStats = getDriverStats(char.id)
    end

    local active = rideForPassenger(char.id) or rideForDriver(char.id)
    data.activeRide = serializeRide(active, source)

    if isTaxiDriver(source) and DriverAvailable[source] ~= false then
        local offers = {}
        for _, ride in pairs(Rides) do
            if ride.status == 'pending' and not ride.driverCharId then
                offers[#offers + 1] = serializeRide(ride, source)
            end
        end
        table.sort(offers, function(a, b) return (a.id or 0) < (b.id or 0) end)
        data.pendingOffers = offers
    end

    return data
end

exports.sunset_core:RegisterCallback('sunset:getTaxiAppData', function(source)
    return buildAppData(source)
end)

local function startRide(source, pickup, destination, destLabel)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    if isTaxiDriver(source) then return nil, 'Go off duty to request a ride' end
    if rideForPassenger(char.id) then return nil, 'You already have an active ride' end

    pickup = encodeCoords(pickup)
    destination = encodeCoords(destination)
    local fare, km = Sunset.TaxiEstimateFare(pickup, destination)
    local label = destLabel or 'Custom destination'

    rideSeq = rideSeq + 1
    local ride = {
        id = rideSeq,
        passengerSource = source,
        passengerCharId = char.id,
        passengerName = exports.sunset_core:GetPlayerDisplayName(source),
        driverSource = nil,
        driverCharId = nil,
        driverName = nil,
        pickup = pickup,
        destination = { x = destination.x, y = destination.y, z = destination.z, label = label },
        fare = fare,
        distanceKm = km,
        status = 'pending',
        createdAt = os.time(),
    }
    Rides[ride.id] = ride
    createDispatchForRide(ride)

    broadcastDrivers('sunset:client:taxiNewOffer', serializeRide(ride, source))
    TriggerClientEvent('sunset:client:notify', source,
        ('Ride requested — $%s to %s. Waiting for a driver...'):format(fare, label), 'success')

    SetTimeout((Sunset.Taxi.requestTimeout or 300) * 1000, function()
        local current = Rides[ride.id]
        if current and current.status == 'pending' then
            current.status = 'cancelled'
            local pSrc = findSourceByCharacterId(current.passengerCharId)
            if pSrc then
                TriggerClientEvent('sunset:client:notify', pSrc, 'No drivers accepted your ride', 'error')
                pushTaxiUpdate(pSrc)
            end
            broadcastDrivers('sunset:client:taxiRideTaken', { id = ride.id })
        end
    end)

    return serializeRide(ride, source)
end

local function estimateRide(pickup, destination, destLabel)
    pickup = encodeCoords(pickup)
    destination = encodeCoords(destination)
    local fare, km = Sunset.TaxiEstimateFare(pickup, destination)
    return {
        fare = fare,
        distanceKm = km,
        label = destLabel or 'Custom destination',
        destination = destination,
    }
end

exports.sunset_core:RegisterCallback('sunset:taxiEstimate', function(source, destinationId, pickup)
    pickup = pickup or {}
    local destRow = Sunset.Taxi.FindDestination(destinationId)
    if not destRow then return nil, 'Invalid destination' end
    return estimateRide(pickup, destRow.coords, destRow.label)
end)

exports.sunset_core:RegisterCallback('sunset:taxiEstimateCoords', function(source, pickup, destination)
    if not destination or not destination.x then return nil, 'Invalid destination' end
    return estimateRide(pickup, destination, destination.label)
end)

exports.sunset_core:RegisterCallback('sunset:taxiRequestRide', function(source, destinationId, pickup)
    pickup = pickup or encodeCoords(GetEntityCoords(GetPlayerPed(source)))
    local destRow = Sunset.Taxi.FindDestination(destinationId)
    if not destRow then return nil, 'Pick a destination' end
    return startRide(source, pickup, destRow.coords, destRow.label)
end)

exports.sunset_core:RegisterCallback('sunset:taxiRequestRideCoords', function(source, pickup, destination)
    if not destination or not destination.x then return nil, 'Pick a destination on the map' end
    pickup = pickup or encodeCoords(GetEntityCoords(GetPlayerPed(source)))
    return startRide(source, pickup, destination, destination.label)
end)

exports.sunset_core:RegisterCallback('sunset:taxiAcceptRide', function(source, rideId)
    if not isTaxiDriver(source) then return nil, 'You must be on duty as a taxi driver' end
    if DriverAvailable[source] == false then return nil, 'Turn on availability in the Cab app' end

    local okVehicle, vehicleErr = requireTaxiVehicle(source)
    if not okVehicle then return nil, vehicleErr end

    local char = getChar(source)
    if not char then return nil, 'No character' end
    if rideForDriver(char.id) then return nil, 'Finish your current ride first' end

    rideId = tonumber(rideId)
    local ride = Rides[rideId]
    if not ride or ride.status ~= 'pending' then return nil, 'Ride no longer available' end

    ride.status = 'accepted'
    ride.driverSource = source
    ride.driverCharId = char.id
    ride.driverName = exports.sunset_core:GetPlayerDisplayName(source)

    local passengerSrc = findSourceByCharacterId(ride.passengerCharId)
    if passengerSrc then
        TriggerClientEvent('sunset:client:notify', passengerSrc,
            ('Driver %s is on the way — $%s'):format(ride.driverName, ride.fare), 'success')
        pushTaxiUpdate(passengerSrc)
    end

    broadcastDrivers('sunset:client:taxiRideTaken', { id = ride.id })
    TriggerClientEvent('sunset:client:taxiRideAccepted', source, serializeRide(ride, source))

    if ride.dispatchCallId then
        pcall(function() exports.sunset_dispatch:AcceptCall(source, 'taxi', ride.dispatchCallId) end)
        pcall(function() exports.sunset_dispatch:UpdateCallState(source, 'taxi', ride.dispatchCallId, 'EN_ROUTE') end)
    end

    return serializeRide(ride, source)
end)

exports.sunset_core:RegisterCallback('sunset:taxiCancelRide', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end

    local ride = rideForPassenger(char.id) or rideForDriver(char.id)
    if not ride then return nil, 'No active ride' end
    if ride.status == 'in_progress' then return nil, 'Cannot cancel during trip' end

    ride.status = 'cancelled'

    local otherSrc
    if ride.passengerCharId == char.id then
        otherSrc = ride.driverSource
    else
        otherSrc = findSourceByCharacterId(ride.passengerCharId)
    end

    if otherSrc then
        TriggerClientEvent('sunset:client:notify', otherSrc, 'Ride was cancelled', 'warning')
        pushTaxiUpdate(otherSrc)
        TriggerClientEvent('sunset:client:taxiRideEnded', otherSrc)
    end

    broadcastDrivers('sunset:client:taxiRideTaken', { id = ride.id })
    return true
end)

exports.sunset_core:RegisterCallback('sunset:taxiPickupPassenger', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end

    local okVehicle, vehicleErr = requireTaxiVehicle(source)
    if not okVehicle then return nil, vehicleErr end

    local ride = rideForDriver(char.id)
    if not ride or ride.status ~= 'accepted' then return nil, 'No passenger to pick up' end

    local coords = getPlayerCoords(source)
    local pickup = ride.pickup
    if coords and pickup then
        local dist = distanceBetween(coords, pickup)
        if dist > (Sunset.Taxi.pickupRadius or 18.0) then
            return nil, 'You are too far from the pickup location'
        end
    end

    ride.status = 'in_progress'
    local passengerSrc = findSourceByCharacterId(ride.passengerCharId)
    if passengerSrc then
        TriggerClientEvent('sunset:client:notify', passengerSrc, 'You are on your way!', 'info')
        pushTaxiUpdate(passengerSrc)
    end

    startMeter(ride)
    if ride.dispatchCallId then
        pcall(function() exports.sunset_dispatch:UpdateCallState(source, 'taxi', ride.dispatchCallId, 'IN_PROGRESS') end)
    end

    TriggerClientEvent('sunset:client:taxiRideInProgress', source, serializeRide(ride, source))
    return serializeRide(ride, source)
end)

exports.sunset_core:RegisterCallback('sunset:taxiCompleteRide', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end

    local okVehicle, vehicleErr = requireTaxiVehicle(source)
    if not okVehicle then return nil, vehicleErr end

    local ride = rideForDriver(char.id)
    if not ride or ride.status ~= 'in_progress' then return nil, 'No trip in progress' end

    local coords = getPlayerCoords(source)
    local dest = ride.destination
    if coords and dest then
        local dist = distanceBetween(coords, dest)
        local radius = Sunset.Taxi.completeRadius or Sunset.Taxi.dropoffRadius or 60.0
        if dist > radius then
            return nil, 'You must reach the destination before completing the trip'
        end
    end

    local passengerSrc = findSourceByCharacterId(ride.passengerCharId)
    if not passengerSrc then
        ride.status = 'cancelled'
        return nil, 'Passenger is offline'
    end

    local amount = ride.meterFare or ride.fare or Sunset.Taxi.minFare
    stopMeter(ride.id)
    local cutRate = Sunset.Taxi.companyCut or 0.12
    local companyCut = math.floor(amount * cutRate)
    local driverPay = amount - companyCut

    if not exports.sunset_core:RemoveMoney(passengerSrc, 'cash', amount, 'taxi_ride') then
        if not exports.sunset_core:RemoveMoney(passengerSrc, 'bank', amount, 'taxi_ride') then
            return nil, 'Passenger cannot pay'
        end
    end

    exports.sunset_core:AddMoney(source, 'cash', driverPay, 'taxi_ride')
    addSociety(companyCut)
    ride.status = 'completed'

    local session = DriverSessionStats[char.id] or { rides = 0, earnings = 0 }
    session.rides = (session.rides or 0) + 1
    session.earnings = (session.earnings or 0) + driverPay
    DriverSessionStats[char.id] = session

    TriggerClientEvent('sunset:client:notify', passengerSrc, ('Trip complete — paid $%s'):format(amount), 'info')
    TriggerClientEvent('sunset:client:notify', source, ('Fare collected: $%s (you earned $%s)'):format(amount, driverPay), 'success')
    TriggerClientEvent('sunset:client:taxiRideEnded', source)
    TriggerClientEvent('sunset:client:taxiRideEnded', passengerSrc)
    pushTaxiUpdate(passengerSrc)
    pushTaxiUpdate(source)

    pcall(function()
        MySQL.insert.await([[
            INSERT INTO taxi_rides (passenger_character_id, driver_character_id, pickup, destination, fare, status, completed_at)
            VALUES (?, ?, ?, ?, ?, 'completed', NOW())
        ]], {
            ride.passengerCharId,
            ride.driverCharId,
            json.encode(ride.pickup),
            json.encode(ride.destination),
            amount,
        })
    end)

    recordTaxiActivity(source, ride, amount)
    if ride.dispatchCallId then
        pcall(function() exports.sunset_dispatch:CompleteCall(source, 'taxi', ride.dispatchCallId) end)
    end

    return true
end)

exports.sunset_core:RegisterCallback('sunset:taxiSetAvailable', function(source, available)
    if not isTaxiDriver(source) then return nil, 'Not on duty' end
    DriverAvailable[source] = available == true
    return DriverAvailable[source]
end)

exports.sunset_core:RegisterCallback('sunset:taxiTip', function(source, amount)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local ride = rideForPassenger(char.id)
    if not ride or ride.status ~= 'in_progress' then return nil, 'No trip in progress' end
    if not ride.driverCharId then return nil, 'No driver assigned' end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return nil, 'Invalid tip' end

    if not exports.sunset_core:RemoveMoney(source, 'cash', amount, 'taxi_tip') then
        if not exports.sunset_core:RemoveMoney(source, 'bank', amount, 'taxi_tip') then
            return nil, 'Not enough money'
        end
    end

    local driverSrc = ride.driverSource or findSourceByCharacterId(ride.driverCharId)
    if driverSrc then
        exports.sunset_core:AddMoney(driverSrc, 'cash', amount, 'taxi_tip')
        TriggerClientEvent('sunset:client:notify', driverSrc, ('Tip received: $%s'):format(amount), 'success')
    end
    return true
end)

AddEventHandler('playerDropped', function()
    local source = source
    DriverAvailable[source] = nil
    local char = getChar(source)
    if not char then return end

    local ride = rideForPassenger(char.id) or rideForDriver(char.id)
    if not ride then return end
    if ride.status == 'completed' or ride.status == 'cancelled' then return end

    ride.status = 'cancelled'
    local otherSrc
    if ride.passengerCharId == char.id then
        otherSrc = ride.driverSource
    else
        otherSrc = findSourceByCharacterId(ride.passengerCharId)
    end
    if otherSrc then
        TriggerClientEvent('sunset:client:notify', otherSrc, 'Ride ended — player disconnected', 'warning')
        TriggerClientEvent('sunset:client:taxiRideEnded', otherSrc)
        pushTaxiUpdate(otherSrc)
    end
    broadcastDrivers('sunset:client:taxiRideTaken', { id = ride.id })
end)

AddEventHandler('sunset:server:characterSelected', function(source)
    DriverAvailable[source] = true
end)

AddEventHandler('sunset:server:jobChanged', function(source, job)
    if job == Sunset.Taxi.factionId then
        DriverAvailable[source] = true
    else
        DriverAvailable[source] = nil
    end
end)

AddEventHandler('sunset:server:taxiDutySync', function(source, onDuty)
    if onDuty then
        DriverAvailable[source] = true
    else
        DriverAvailable[source] = nil
    end
end)

AddEventHandler('sunset:dispatch:callAccepted', function(callId, callType, providerSource)
    if callType ~= 'taxi' then return end
    local call = exports.sunset_dispatch:GetCall(callId)
    if not call or (call.metadata and call.metadata.rideId) then return end

    local char = getChar(providerSource)
    if not char or not isTaxiDriver(providerSource) then return end

    local pickup = call.coords
    local okVehicle = requireTaxiVehicle(providerSource)
    if not okVehicle then return end

    rideSeq = rideSeq + 1
    local ride = {
        id = rideSeq,
        passengerSource = call.callerSource,
        passengerCharId = call.callerCharacterId,
        passengerName = call.callerName,
        driverSource = providerSource,
        driverCharId = char.id,
        driverName = exports.sunset_core:GetPlayerDisplayName(providerSource),
        pickup = pickup,
        destination = { x = pickup.x, y = pickup.y, z = pickup.z, label = call.description or 'Service call' },
        fare = Sunset.Taxi.minFare,
        distanceKm = 0,
        status = 'accepted',
        createdAt = os.time(),
        dispatchCallId = callId,
        fromDispatch = true,
    }
    Rides[ride.id] = ride

    TriggerClientEvent('sunset:client:taxiRideAccepted', providerSource, serializeRide(ride, providerSource))
    local callerSrc = call.callerSource or findSourceByCharacterId(call.callerCharacterId)
    if callerSrc then
        TriggerClientEvent('sunset:client:notify', callerSrc,
            ('Driver %s accepted your taxi call'):format(ride.driverName), 'success')
    end
end)

