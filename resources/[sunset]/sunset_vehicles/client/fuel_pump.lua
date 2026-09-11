local refueling = false
local fillingCan = false
local sessionStartFuel = 0.0
local sessionAddedLiters = 0.0
local canSessionStartLiters = 0.0
local canCurrentLiters = 0.0
local sessionStation = nil
local sessionPumpIndex = 0
local sessionPumpGlobalId = 0
local PUMP_TOOLTIP_DIST = 14.0
local sessionVeh = 0
local uiVisible = false
local isPumping = false
local pumpSpeed = 0.02
local waitForStartRelease = false
local cachedCanLiters = 0.0
local cachedCanAt = 0

local PUMP_REACH = 4.2
local PUMP_KEY_VEHICLE = 47 -- G
local PUMP_KEY_CAN = 38 -- E
local PUMP_KEY_FLOW = 22 -- SPACE
local PUMP_KEY_CHECKOUT = 191 -- ENTER / frontend accept
local cachedOwnerLabel = nil
local cachedOwnerKey = nil
local cachedOwnerAt = 0

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function getDriverVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return 0 end
    return veh
end

local function normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

local function getFuelLevel()
    return exports.sunset_vehicles:GetFuelLevel() or 0.0
end

local function setFuelLevel(veh, level)
    exports.sunset_vehicles:SetFuelLevel(veh, level)
end

local function pricePerLiter()
    return Sunset.Config.FuelPricePerLiter or 2.45
end

local function maxCanLiters()
    return Sunset.GetGasCanMaxLiters()
end

local function vehicleDisplayName(veh)
    if not veh or veh == 0 then return 'Vehicle' end
    local model = GetEntityModel(veh)
    local label = GetDisplayNameFromVehicleModel(model)
    if label and label ~= 'CARNOTFOUND' then
        return GetLabelText(label)
    end
    return 'Vehicle'
end

local function pumpGlobalId(stationIndex, pumpIndex)
    local total = 0
    for si = 1, (stationIndex or 1) - 1 do
        local station = Sunset.GasStations[si]
        if station and station.pumps then
            total = total + #station.pumps
        end
    end
    return total + (pumpIndex or 1)
end

local function pumpBrand(station)
    local label = station and station.label or ''
    if label:find('LTD', 1, true) then return 'LTD GASOLINE' end
    if label:find('Ron', 1, true) then return 'RON GAS' end
    if label:find('Xero', 1, true) then return 'XERO GAS' end
    return 'XODO FUEL INC.'
end

local function worldTooltips()
    if GetResourceState('sunset_world') ~= 'started' or not SunsetWorld or not SunsetWorld.Tooltips then
        return nil
    end
    return SunsetWorld.Tooltips
end

local function clearAllPumpTooltips()
    local tooltips = worldTooltips()
    if not tooltips then return end
    for si, station in ipairs(Sunset.GasStations or {}) do
        for pi in ipairs(station.pumps or {}) do
            tooltips.clear(('pump_%d_%d'):format(si, pi))
        end
    end
end

local function findNearestPump(coords)
    local bestStation, bestPump, bestIndex, bestStationIndex, bestDist = nil, nil, 0, 0, PUMP_REACH + 1.0
    for si, station in ipairs(Sunset.GasStations or {}) do
        for index, pump in ipairs(station.pumps or {}) do
            local px, py, pz = pump.x, pump.y, pump.z
            local dist = #(coords - vector3(px, py, pz))
            if dist < bestDist then
                bestDist = dist
                bestStation = station
                bestPump = pump
                bestIndex = index
                bestStationIndex = si
            end
        end
    end
    if bestStation then return bestStation, bestPump, bestIndex, bestStationIndex, bestDist end
    return nil, nil, 0, 0, 999.0
end

local function pumpTooltipCoords(pump)
    return vector3(pump.x, pump.y, pump.z + 1.15)
end

local function getOwnerLabel(station)
    local key = station and (station.label or '') or ''
    local now = GetGameTimer()
    if cachedOwnerKey == key and cachedOwnerLabel and (now - cachedOwnerAt) < 8000 then
        return cachedOwnerLabel
    end

    local label = 'Stat'
    if GetResourceState('sunset_businesses') == 'started' then
        local ctx = Sunset.AwaitCallback('sunset:getGasBusinessContext')
        if ctx and ctx.business then
            local biz = ctx.business
            if biz.ownerName and biz.ownerName ~= '' then
                label = biz.ownerName
            elseif biz.ownerCharacterId then
                label = ('Jucător #%d'):format(biz.ownerCharacterId)
            elseif biz.forSale then
                label = 'De vânzare'
            end
        end
    end

    cachedOwnerKey = key
    cachedOwnerLabel = label
    cachedOwnerAt = now
    return label
end

local function buildUiPayload(mode, extra)
    extra = extra or {}
    local stationRef = sessionStation or extra.stationRef
    local stationLabel = stationRef and (stationRef.label or 'Gas Station') or (extra.station or 'Gas Station')
    local payload = {
        mode = mode,
        station = stationLabel,
        ownerName = extra.ownerName or getOwnerLabel(stationRef),
        fuelType = fillingCan and 'Gas Can Fill' or 'Premium Gasoline 99',
        pricePerLiter = pricePerLiter(),
        sessionLiters = extra.sessionLiters or sessionAddedLiters or 0,
        cost = extra.cost or 0,
        tankPct = extra.tankPct or 0,
        interactive = mode == 'pumping',
        canPump = extra.canPump ~= false,
        pumping = isPumping,
        pumpLabel = extra.pumpLabel,
    }

    if fillingCan then
        local maxLiters = maxCanLiters()
        payload.vehicleName = 'Gas Can'
        payload.tankPct = maxLiters > 0 and ((canCurrentLiters or 0) / maxLiters) * 100.0 or 0
    elseif sessionVeh ~= 0 and DoesEntityExist(sessionVeh) then
        local class = GetVehicleClass(sessionVeh)
        local current = getFuelLevel()
        payload.vehicleName = vehicleDisplayName(sessionVeh)
        payload.tankPct = current
    else
        payload.vehicleName = extra.vehicleName or 'Vehicle'
        payload.tankPct = extra.tankPct or 0
    end

    return payload
end

local function showPumpUi(mode, extra)
    uiVisible = true
    exports.sunset_ui:Send('fuelPumpShow', buildUiPayload(mode, extra))
end

local function updatePumpUi(mode, extra)
    if not uiVisible then return end
    exports.sunset_ui:Send('fuelPumpUpdate', buildUiPayload(mode, extra))
end

local function hidePumpUi()
    uiVisible = false
    exports.sunset_ui:Send('fuelPumpHide', {})
end

local function getCachedCanLiters()
    local now = GetGameTimer()
    if now - cachedCanAt > 1200 then
        cachedCanLiters = Sunset.AwaitCallback('sunset:getGasCanLiters') or 0
        cachedCanAt = now
    end
    return cachedCanLiters
end

local function syncPumpTooltips(playerPos, nearestStation, nearestPump, nearestSi, nearestPi, nearestDist)
    local tooltips = worldTooltips()
    if not tooltips then return end
    local veh = getDriverVehicle()
    local onFoot = not IsPedInAnyVehicle(PlayerPedId(), false)

    for si, station in ipairs(Sunset.GasStations or {}) do
        for pi, pump in ipairs(station.pumps or {}) do
            local id = ('pump_%d_%d'):format(si, pi)
            local dist = #(playerPos - vector3(pump.x, pump.y, pump.z))
            if dist <= PUMP_TOOLTIP_DIST then
                local globalId = pumpGlobalId(si, pi)
                local isActive = si == nearestSi and pi == nearestPi and dist <= PUMP_REACH
                local key = 'G'
                local desc = 'Pompă Activă'
                if isActive then
                    if veh ~= 0 then
                        desc = 'Alimentați Vehiculul'
                    elseif onFoot then
                        key = 'E'
                        desc = 'Umple Bidonul'
                    end
                end
                local ownerHint = ''
                if isActive then
                    ownerHint = getOwnerLabel(station)
                    if ownerHint and ownerHint ~= '' then
                        ownerHint = ' · ' .. ownerHint
                    end
                end
                tooltips.set(id, {
                    coords = pumpTooltipCoords(pump),
                    badge = pumpBrand(station),
                    badgeClass = 'gas',
                    bodyClass = 'gas',
                    icon = 'ph-gas-pump',
                    title = ('Pompă Benzina #%02d'):format(globalId),
                    desc = desc .. ownerHint,
                    key = isActive and key or '',
                })
            else
                tooltips.clear(id)
            end
        end
    end
end

local function cancelRefuel()
    if sessionVeh ~= 0 and DoesEntityExist(sessionVeh) then
        setFuelLevel(sessionVeh, sessionStartFuel)
    end
    refueling = false
    fillingCan = false
    isPumping = false
    sessionStation = nil
    sessionVeh = 0
    sessionAddedLiters = 0
    hidePumpUi()
end

local function finishRefuel(veh)
    refueling = false
    isPumping = false
    local endFuel = getFuelLevel()
    sessionVeh = 0

    if endFuel <= sessionStartFuel + 0.05 or sessionAddedLiters <= 0.05 then
        hidePumpUi()
        notify('Refueling cancelled', 'warning')
        setFuelLevel(veh, sessionStartFuel)
        return
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(veh))
    local result, err = Sunset.AwaitCallback('sunset:refuelVehiclePartial', sessionStartFuel, endFuel, plate)
    if not result then
        hidePumpUi()
        setFuelLevel(veh, sessionStartFuel)
        notify(err or 'Payment failed', 'error')
        return
    end

    setFuelLevel(veh, result.newFuel or endFuel)
    local finalFuel = result.newFuel or endFuel
    updatePumpUi('complete', {
        sessionLiters = sessionAddedLiters,
        cost = result.cost or math.floor(sessionAddedLiters * pricePerLiter() * 100) / 100,
        tankPct = finalFuel,
    })
    notify(('Refueled %.1f L — paid $%s'):format(sessionAddedLiters, result.cost or 0), 'success')
    sessionAddedLiters = 0
    Wait(900)
    hidePumpUi()
end

local function finishCanFill()
    fillingCan = false
    isPumping = false
    local endLiters = canCurrentLiters

    if endLiters <= canSessionStartLiters + 0.05 or sessionAddedLiters <= 0.05 then
        hidePumpUi()
        notify('Gas can fill cancelled', 'warning')
        return
    end

    local result, err = Sunset.AwaitCallback('sunset:fillGasCan', endLiters)
    if not result then
        hidePumpUi()
        notify(err or 'Payment failed', 'error')
        return
    end

    local maxLiters = result.maxLiters or maxCanLiters()
    updatePumpUi('complete', {
        sessionLiters = sessionAddedLiters,
        cost = result.cost or math.floor(sessionAddedLiters * pricePerLiter() * 100) / 100,
        tankPct = maxLiters > 0 and ((result.liters or endLiters) / maxLiters) * 100.0 or 0,
    })
    notify(('Gas can: %.0f/%.0f L — paid $%s'):format(result.liters or endLiters, maxLiters, result.cost or 0), 'success')
    sessionAddedLiters = 0
    Wait(900)
    hidePumpUi()
end

local function tryCheckout()
    if not (refueling or fillingCan) then return end
    if isPumping then return end
    if sessionAddedLiters <= 0.05 then return end
    if refueling then
        local veh = sessionVeh
        if veh ~= 0 and DoesEntityExist(veh) then
            finishRefuel(veh)
        else
            cancelRefuel()
        end
    elseif fillingCan then
        finishCanFill()
    end
end

local function startRefuel(station, pumpIndex, stationIndex)
    local veh = getDriverVehicle()
    if veh == 0 then return end

    local class = GetVehicleClass(veh)
    if class == 13 or (Sunset.GetVehicleTankCapacityLiters(class) or 0) <= 0 then
        notify('This vehicle does not use fuel', 'info')
        return
    end

    local current = getFuelLevel()
    if current >= 99.9 then
        notify('Tank is already full', 'info')
        return
    end

    refueling = true
    fillingCan = false
    waitForStartRelease = true
    sessionStartFuel = current
    sessionStation = station
    sessionPumpIndex = pumpIndex or 1
    sessionPumpGlobalId = pumpGlobalId(stationIndex or 1, pumpIndex or 1)
    sessionVeh = veh
    sessionAddedLiters = 0
    isPumping = false
    pumpSpeed = 0.02
    showPumpUi('pumping', {
        tankPct = current,
        sessionLiters = 0,
        cost = 0,
        pumpLabel = ('Pompă #%02d'):format(sessionPumpGlobalId),
    })
    SetVehicleEngineOn(veh, false, true, true)
end

local function startCanFill(station, pumpIndex, stationIndex)
    local currentLiters = Sunset.AwaitCallback('sunset:getGasCanLiters') or 0
    local maxLiters = maxCanLiters()
    if currentLiters >= maxLiters - 0.05 then
        notify('Gas can is already full', 'info')
        return
    end

    fillingCan = true
    refueling = false
    waitForStartRelease = true
    canSessionStartLiters = currentLiters
    canCurrentLiters = currentLiters
    sessionStation = station
    sessionPumpIndex = pumpIndex or 1
    sessionPumpGlobalId = pumpGlobalId(stationIndex or 1, pumpIndex or 1)
    sessionAddedLiters = 0
    isPumping = false
    pumpSpeed = 0.02
    local pct = maxLiters > 0 and (currentLiters / maxLiters) * 100.0 or 0
    showPumpUi('pumping', {
        tankPct = pct,
        sessionLiters = 0,
        cost = 0,
        pumpLabel = ('Pompă #%02d'):format(sessionPumpGlobalId),
    })
end

local function pumpTick()
    if not isPumping then return end

    local minSpeed, maxSpeed, acceleration = 0.02, 0.5, 0.01
    pumpSpeed = math.min(maxSpeed, pumpSpeed + acceleration)

    if refueling then
        local veh = sessionVeh
        if veh == 0 or not DoesEntityExist(veh) then
            cancelRefuel()
            return
        end
        local class = GetVehicleClass(veh)
        local tankCap = Sunset.GetVehicleTankCapacityLiters(class)
        if tankCap <= 0 then return end

        local current = getFuelLevel()
        if current >= 99.95 then
            setFuelLevel(veh, 100.0)
            isPumping = false
            updatePumpUi('pumping', {
                sessionLiters = sessionAddedLiters,
                cost = math.floor(sessionAddedLiters * pricePerLiter() * 100) / 100,
                tankPct = 100.0,
                canPump = false,
                pumping = false,
            })
            return
        end

        sessionAddedLiters = sessionAddedLiters + pumpSpeed
        local addedPct = (pumpSpeed / tankCap) * 100.0
        local nextFuel = math.min(100.0, current + addedPct)
        setFuelLevel(veh, nextFuel)
        updatePumpUi('pumping', {
            sessionLiters = sessionAddedLiters,
            cost = math.floor(sessionAddedLiters * pricePerLiter() * 100) / 100,
            tankPct = nextFuel,
            pumping = true,
        })
    elseif fillingCan then
        local maxLiters = maxCanLiters()
        canCurrentLiters = math.min(maxLiters, canCurrentLiters + pumpSpeed)
        sessionAddedLiters = canCurrentLiters - canSessionStartLiters
        local pct = maxLiters > 0 and (canCurrentLiters / maxLiters) * 100.0 or 0
        updatePumpUi('pumping', {
            sessionLiters = sessionAddedLiters,
            cost = math.floor(sessionAddedLiters * pricePerLiter() * 100) / 100,
            tankPct = pct,
            pumping = true,
        })
        if canCurrentLiters >= maxLiters - 0.05 then
            canCurrentLiters = maxLiters
            isPumping = false
            updatePumpUi('pumping', {
                sessionLiters = sessionAddedLiters,
                cost = math.floor(sessionAddedLiters * pricePerLiter() * 100) / 100,
                tankPct = 100.0,
                canPump = false,
                pumping = false,
            })
        end
    end
end

CreateThread(function()
    while true do
        if refueling or fillingCan then
            if isPumping then pumpTick() end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

CreateThread(function()
    while true do
        if refueling or fillingCan or IsNuiFocused() then
            Wait(400)
        else
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local veh = getDriverVehicle()
            local station, pump, pumpIndex, stationIndex, dist = findNearestPump(pos)
            syncPumpTooltips(pos, station, pump, stationIndex, pumpIndex, dist)

            if station and pump and dist <= PUMP_REACH then
                local globalId = pumpGlobalId(stationIndex, pumpIndex)
                if veh ~= 0 then
                    local current = getFuelLevel()
                    if not uiVisible then
                        showPumpUi('ready', {
                            station = station.label,
                            stationRef = station,
                            vehicleName = vehicleDisplayName(veh),
                            tankPct = current,
                            sessionLiters = 0,
                            cost = 0,
                            pumpLabel = ('Pompă #%02d'):format(globalId),
                        })
                    end

                    if not IsControlPressed(0, PUMP_KEY_VEHICLE) then
                        waitForStartRelease = false
                    elseif not waitForStartRelease and current < 99.9 then
                        startRefuel(station, pumpIndex, stationIndex)
                    end
                elseif not IsPedInAnyVehicle(ped, false) then
                    local currentLiters = getCachedCanLiters()
                    local maxLiters = maxCanLiters()
                    if not uiVisible then
                        showPumpUi('ready', {
                            station = station.label,
                            stationRef = station,
                            vehicleName = 'Gas Can',
                            tankPct = maxLiters > 0 and (currentLiters / maxLiters) * 100.0 or 0,
                            sessionLiters = 0,
                            cost = 0,
                            pumpLabel = ('Pompă #%02d'):format(globalId),
                        })
                    end

                    if not IsControlPressed(0, PUMP_KEY_CAN) then
                        waitForStartRelease = false
                    elseif not waitForStartRelease then
                        local hasCan = Sunset.AwaitCallback('sunset:inventoryHasItem', 'gas_can')
                        if hasCan then
                            startCanFill(station, pumpIndex, stationIndex)
                        else
                            notify('Buy a gas can at a 24/7 store first', 'error')
                            waitForStartRelease = true
                        end
                    end
                end
                Wait(0)
            else
                if uiVisible and not refueling and not fillingCan then hidePumpUi() end
                Wait(350)
            end
        end
    end
end)

CreateThread(function()
    while true do
        if refueling or fillingCan then
            if IsControlPressed(0, PUMP_KEY_FLOW) then
                if not isPumping then
                    isPumping = true
                    pumpSpeed = 0.02
                end
            else
                if isPumping then
                    isPumping = false
                    updatePumpUi('pumping', {
                        sessionLiters = sessionAddedLiters,
                        cost = math.floor(sessionAddedLiters * pricePerLiter() * 100) / 100,
                        pumping = false,
                    })
                end
            end

            if sessionAddedLiters > 0.05 and not isPumping then
                if IsControlJustPressed(0, PUMP_KEY_CHECKOUT)
                    or IsDisabledControlJustPressed(0, PUMP_KEY_CHECKOUT)
                    or IsControlJustPressed(0, 201)
                    or IsDisabledControlJustPressed(0, 201) then
                    tryCheckout()
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('sunset:nui:fuelPumpCheckout', function()
    tryCheckout()
end)

AddEventHandler('sunset:nui:fuelPumpPumpStart', function()
    if refueling or fillingCan then
        isPumping = true
        pumpSpeed = 0.02
        updatePumpUi('pumping', { pumping = true })
    end
end)

AddEventHandler('sunset:nui:fuelPumpPumpStop', function()
    if refueling or fillingCan then
        isPumping = false
        updatePumpUi('pumping', {
            sessionLiters = sessionAddedLiters,
            cost = math.floor(sessionAddedLiters * pricePerLiter() * 100) / 100,
            pumping = false,
        })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearAllPumpTooltips()
    if refueling then cancelRefuel() elseif fillingCan then fillingCan = false hidePumpUi() else hidePumpUi() end
end)
