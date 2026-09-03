local refueling = false
local sessionStartFuel = 0.0
local sessionStation = nil
local sessionVeh = 0
local pumpHintShown = false

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

local function fillRate()
    return Sunset.Config.FuelFillRatePerSec or 0.22
end

local function pumpReach()
    return Sunset.Config.FuelPumpReach or 4.2
end

local function findNearestPump()
    local veh = getDriverVehicle()
    if veh == 0 then return nil, nil end
    local coords = GetEntityCoords(veh)
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

local function showPumpUi(station, startFuel)
    exports.sunset_ui:Send('fuelPumpShow', {
        station = station.label or 'Gas Station',
        pricePerLiter = pricePerPercent(),
        startFuel = startFuel,
        fuel = startFuel,
        liters = 0,
        cost = 0,
    })
end

local function updatePumpUi(station, fuel, liters, cost)
    exports.sunset_ui:Send('fuelPumpUpdate', {
        station = station and station.label or 'Gas Station',
        fuel = fuel,
        liters = liters,
        cost = cost,
        pricePerLiter = pricePerPercent(),
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
    sessionStartFuel = current
    sessionStation = station
    sessionVeh = veh
    showPumpUi(station, current)
    SetVehicleEngineOn(veh, false, true, true)
end

CreateThread(function()
    while true do
        local veh = getDriverVehicle()
        if veh ~= 0 and not refueling and not IsNuiFocused() then
            local station, pump = findNearestPump()
            if station and pump then
                DrawMarker(1, pump.x, pump.y, pump.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.4, 1.4, 0.6, 46, 204, 113, 160, false, false, 2, false, nil, nil, false)

                if not pumpHintShown then
                    pumpHintShown = true
                    if GetResourceState('ox_lib') == 'started' then
                        exports.ox_lib:showTextUI('Hold [E] at pump — release to stop', { position = 'bottom-center' })
                    end
                end

                if IsControlPressed(0, 38) then
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
        elseif refueling then
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
        else
            Wait(200)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if refueling then cancelRefuel() else hidePumpUi() end
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:hideTextUI()
    end
end)
