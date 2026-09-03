local refueling = false
local fillingCan = false
local sessionStartFuel = 0.0
local canSessionStartLiters = 0.0
local canCurrentLiters = 0.0
local sessionStation = nil
local sessionVeh = 0
local pumpHintShown = false
local canHintShown = false
local waitForUseRelease = false
local waitForCanRelease = false

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

local function pricePerPercent()
    return Sunset.Config.FuelPricePerPercent or 1.75
end

local function pricePerLiter()
    return Sunset.Config.FuelPricePerLiter or 2.92
end

local function maxCanLiters()
    return Sunset.GetGasCanMaxLiters()
end

local function canFillRateLiters()
    local maxLiters = maxCanLiters()
    return (Sunset.Config.FuelFillRatePerSec or 0.22) / 100.0 * maxLiters
end

local function fillRate()
    return Sunset.Config.FuelFillRatePerSec or 0.22
end

local function pumpReach()
    return Sunset.Config.FuelPumpReach or 4.2
end

local function findNearestPump(coords)
    local bestStation, bestPump, bestDist = nil, nil, pumpReach() + 1.0

    for _, station in ipairs(Sunset.GasStations or {}) do
        for _, pump in ipairs(station.pumps or {}) do
            local px, py, pz = pump.x, pump.y, pump.z
            local dist = #(coords - vector3(px, py, pz))
            if dist < bestDist then
                bestDist = dist
                bestStation = station
                bestPump = pump
            end
        end
    end

    if bestStation then return bestStation, bestPump end
    return nil, nil
end

local function findNearestPumpForVehicle()
    local veh = getDriverVehicle()
    if veh == 0 then return nil, nil end
    return findNearestPump(GetEntityCoords(veh))
end

local function findNearestPumpOnFoot()
    if IsPedInAnyVehicle(PlayerPedId(), false) then return nil, nil end
    return findNearestPump(GetEntityCoords(PlayerPedId()))
end

local function showPumpUi(station, startFuel, tankLabel)
    exports.sunset_ui:Send('fuelPumpShow', {
        station = station.label or 'Gas Station',
        pricePerLiter = fillingCan and pricePerLiter() or pricePerPercent(),
        startFuel = startFuel,
        fuel = startFuel,
        liters = 0,
        cost = 0,
        tankLabel = tankLabel,
    })
end

local function updatePumpUi(station, fuel, liters, cost, tankLabel)
    exports.sunset_ui:Send('fuelPumpUpdate', {
        station = station and station.label or 'Gas Station',
        fuel = fuel,
        liters = liters,
        cost = cost,
        pricePerLiter = fillingCan and pricePerLiter() or pricePerPercent(),
        tankLabel = tankLabel,
    })
end

local function hidePumpUi()
    exports.sunset_ui:Send('fuelPumpHide', {})
end

local function cancelRefuel()
    if sessionVeh ~= 0 and DoesEntityExist(sessionVeh) then
        setFuelLevel(sessionVeh, sessionStartFuel)
    end
    refueling = false
    sessionStation = nil
    sessionVeh = 0
    hidePumpUi()
end

local function finishRefuel(veh, startFuel, endFuel, station)
    refueling = false
    sessionVeh = 0
    hidePumpUi()

    if endFuel <= startFuel + 0.05 then
        notify('Refueling cancelled', 'warning')
        setFuelLevel(veh, startFuel)
        return
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(veh))
    local result, err = Sunset.AwaitCallback('sunset:refuelVehiclePartial', startFuel, endFuel, plate)
    if not result then
        setFuelLevel(veh, startFuel)
        notify(err or 'Payment failed', 'error')
        return
    end

    setFuelLevel(veh, result.newFuel or endFuel)
    notify(('Refueled +%d%% — paid $%s (tank %d%%)'):format(
        math.floor((result.newFuel or endFuel) - startFuel),
        result.cost or 0,
        math.floor(result.newFuel or endFuel)
    ), 'success')
end

local function startRefuel(station)
    local veh = getDriverVehicle()
    if veh == 0 then return end

    local current = getFuelLevel()
    if current >= 99.9 then
        notify('Tank is already full', 'info')
        return
    end

    refueling = true
    waitForUseRelease = true
    sessionStartFuel = current
    sessionStation = station
    sessionVeh = veh
    showPumpUi(station, current)
    SetVehicleEngineOn(veh, false, true, true)
end

local function finishCanFill(endLiters)
    fillingCan = false
    hidePumpUi()

    if endLiters <= canSessionStartLiters + 0.05 then
        notify('Gas can fill cancelled', 'warning')
        return
    end

    local result, err = Sunset.AwaitCallback('sunset:fillGasCan', endLiters)
    if not result then
        notify(err or 'Payment failed', 'error')
        return
    end

    local maxLiters = result.maxLiters or maxCanLiters()
    notify(('Gas can: %.0f/%.0f L — paid $%s'):format(
        result.liters or endLiters, maxLiters, result.cost or 0), 'success')
end

local function startCanFill(station)
    local currentLiters = Sunset.AwaitCallback('sunset:getGasCanLiters') or 0
    local maxLiters = maxCanLiters()
    if currentLiters >= maxLiters - 0.05 then
        notify('Gas can is already full', 'info')
        return
    end

    fillingCan = true
    waitForCanRelease = true
    canSessionStartLiters = currentLiters
    canCurrentLiters = currentLiters
    sessionStation = station
    local pct = maxLiters > 0 and (currentLiters / maxLiters) * 100.0 or 0
    showPumpUi(station, pct, ('%.1f/%.0f L'):format(currentLiters, maxLiters))
end

CreateThread(function()
    while true do
        local veh = getDriverVehicle()
        if veh ~= 0 and not refueling and not fillingCan and not IsNuiFocused() then
            local station, pump = findNearestPumpForVehicle()
            if station and pump then
                DrawMarker(1, pump.x, pump.y, pump.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.4, 1.4, 0.6, 46, 204, 113, 160, false, false, 2, false, nil, nil, false)

                if not pumpHintShown then
                    pumpHintShown = true
                    if GetResourceState('ox_lib') == 'started' then
                        exports.ox_lib:showTextUI('Hold [E] at pump — release to stop', { position = 'bottom-center' })
                    end
                end

                if not IsControlPressed(0, 38) then
                    waitForUseRelease = false
                elseif not waitForUseRelease then
                    startRefuel(station)
                end
                Wait(0)
            else
                if pumpHintShown then
                    pumpHintShown = false
                    if GetResourceState('ox_lib') == 'started' then
                        exports.ox_lib:hideTextUI()
                    end
                end
                Wait(350)
            end
        elseif refueling or fillingCan then
            Wait(0)
        else
            if pumpHintShown then
                pumpHintShown = false
                if GetResourceState('ox_lib') == 'started' then
                    exports.ox_lib:hideTextUI()
                end
            end
            Wait(450)
        end
    end
end)

CreateThread(function()
    while true do
        if not refueling and not fillingCan and not IsNuiFocused() and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local station, pump = findNearestPumpOnFoot()
            if station and pump then
                DrawMarker(1, pump.x, pump.y, pump.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.4, 1.4, 0.6, 255, 180, 0, 160, false, false, 2, false, nil, nil, false)

                if not canHintShown then
                    canHintShown = true
                    if GetResourceState('ox_lib') == 'started' then
                        exports.ox_lib:showTextUI('Hold [E] with gas can — release to stop', { position = 'bottom-center' })
                    end
                end

                if not IsControlPressed(0, 38) then
                    waitForCanRelease = false
                elseif not waitForCanRelease then
                    local hasCan = Sunset.AwaitCallback('sunset:inventoryHasItem', 'gas_can')
                    if hasCan then
                        startCanFill(station)
                    else
                        notify('Buy a gas can at a 24/7 store first', 'error')
                        waitForCanRelease = true
                    end
                end
                Wait(0)
            else
                if canHintShown then
                    canHintShown = false
                    if GetResourceState('ox_lib') == 'started' then
                        exports.ox_lib:hideTextUI()
                    end
                end
                Wait(350)
            end
        else
            if canHintShown then
                canHintShown = false
                if GetResourceState('ox_lib') == 'started' then
                    exports.ox_lib:hideTextUI()
                end
            end
            Wait(450)
        end
    end
end)

CreateThread(function()
    while true do
        if refueling then
            local veh = getDriverVehicle()
            if veh == 0 or veh ~= sessionVeh then
                cancelRefuel()
            elseif not IsControlPressed(0, 38) then
                finishRefuel(veh, sessionStartFuel, getFuelLevel(), sessionStation)
            else
                local current = getFuelLevel()
                if current >= 99.95 then
                    setFuelLevel(veh, 100.0)
                    finishRefuel(veh, sessionStartFuel, 100.0, sessionStation)
                else
                    local dt = GetFrameTime()
                    local added = fillRate() * dt
                    local nextFuel = math.min(100.0, current + added)
                    setFuelLevel(veh, nextFuel)
                    local liters = nextFuel - sessionStartFuel
                    local cost = math.floor(liters * pricePerPercent() * 100) / 100
                    updatePumpUi(sessionStation, nextFuel, liters, cost)
                end
            end
            Wait(0)
        elseif fillingCan then
            if IsPedInAnyVehicle(PlayerPedId(), false) then
                fillingCan = false
                hidePumpUi()
            elseif not IsControlPressed(0, 38) then
                finishCanFill(canCurrentLiters)
            else
                local dt = GetFrameTime()
                local maxLiters = maxCanLiters()
                local added = canFillRateLiters() * dt
                canCurrentLiters = math.min(maxLiters, canCurrentLiters + added)
                local sessionAdded = canCurrentLiters - canSessionStartLiters
                local cost = math.floor(sessionAdded * pricePerLiter() * 100) / 100
                local pct = maxLiters > 0 and (canCurrentLiters / maxLiters) * 100.0 or 0
                updatePumpUi(sessionStation, pct, sessionAdded, cost,
                    ('%.1f/%.0f L'):format(canCurrentLiters, maxLiters))
                if canCurrentLiters >= maxLiters - 0.05 then
                    canCurrentLiters = maxLiters
                    finishCanFill(maxLiters)
                end
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if refueling then
        cancelRefuel()
    elseif fillingCan then
        fillingCan = false
        hidePumpUi()
    else
        hidePumpUi()
    end
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:hideTextUI()
    end
end)
