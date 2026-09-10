local function generatePlate()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local idx = math.random(1, #chars)
        plate = plate .. chars:sub(idx, idx)
    end
    return plate
end

local StoreRate = {}
local StateSyncRate = {}
local ParkRate = {}

local function normalizePlate(plate)
    return type(plate) == 'string' and plate:gsub('%s+', ''):upper() or ''
end

local function decodeProps(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, value = pcall(json.decode, raw)
    return ok and type(value) == 'table' and value or {}
end

local function buildVehicleEcuInfo(props)
    props = type(props) == 'table' and props or {}
    if SunsetTuning and SunsetTuning.BuildVehicleInfo then
        return SunsetTuning.BuildVehicleInfo(props.ecu)
    end
    if props.ecu then
        return {
            tuned = true,
            stock = false,
            summary = 'ECU customizat',
            chips = { 'TUNED' },
            lines = {},
            tune = props.ecu,
        }
    end
    return {
        tuned = false,
        stock = true,
        summary = 'Mapa ECU stock',
        chips = { 'STOCK' },
        lines = { { label = 'ECU', value = 'Factory map' } },
        tune = nil,
    }
end

CreateThread(function()
    Wait(500)
    pcall(function()
        MySQL.query.await([[
            ALTER TABLE `vehicles`
                ADD COLUMN IF NOT EXISTS `insurance_points` INT NOT NULL DEFAULT 5 AFTER `garage`,
                ADD COLUMN IF NOT EXISTS `insurance_level` INT NOT NULL DEFAULT 1 AFTER `insurance_points`,
                ADD COLUMN IF NOT EXISTS `destroyed` TINYINT(1) NOT NULL DEFAULT 0 AFTER `insurance_level`,
                ADD COLUMN IF NOT EXISTS `insurance_cost` INT NOT NULL DEFAULT 250 AFTER `destroyed`;
        ]])
    end)
end)

local ModelPriceCache = {}

local function getVehicleBasePrice(model)
    model = tostring(model or ''):lower():gsub('%s+', '')
    if model == '' then return 25000 end
    if ModelPriceCache[model] then return ModelPriceCache[model] end
    local row = MySQL.single.await('SELECT price FROM dealership_vehicles WHERE LOWER(model) = ? LIMIT 1', { model })
    local price = row and tonumber(row.price) or 25000
    ModelPriceCache[model] = price
    return price
end

local function calculateVehicleInsuranceCost(model, savedCost)
    if savedCost and tonumber(savedCost) and tonumber(savedCost) > 0 then
        return tonumber(savedCost)
    end
    local carPrice = getVehicleBasePrice(model)
    local baseInsurance = math.max(250, math.min(15000, math.floor(carPrice * 0.015)))
    return baseInsurance
end

local function enrichVehicleRow(row)
    if type(row) ~= 'table' then return row end
    local props = decodeProps(row.props)
    row.props = nil
    row.odometer = tonumber(props.odometer)
    row.ecuInfo = buildVehicleEcuInfo(props)
    if row.ecuInfo and row.ecuInfo.tune then
        row.ecu = row.ecuInfo.tune
    end

    local model = (row.model or ''):lower()
    local insuranceCost = calculateVehicleInsuranceCost(model, row.insurance_cost)
    row.insuranceCost = insuranceCost
    row.insurancePoints = math.max(0, tonumber(row.insurance_points) or 5)
    row.insuranceLevel = math.max(1, math.min(11, tonumber(row.insurance_level) or 1))
    row.destroyed = (row.destroyed == 1 or row.destroyed == true or row.destroyed == '1')
    row.claimCost = math.floor(insuranceCost * row.insuranceLevel)
    row.renewCost = math.floor(insuranceCost * 3)
    return row
end

local function enrichVehicleList(rows)
    if type(rows) ~= 'table' then return {} end
    for i = 1, #rows do
        rows[i] = enrichVehicleRow(rows[i])
    end
    return rows
end

exports('EnrichVehicleRow', enrichVehicleRow)
exports('EnrichVehicleList', enrichVehicleList)
exports('BuildVehicleEcuInfo', buildVehicleEcuInfo)

local function plateTextMatches(a, b)
    a = normalizePlate(a)
    b = normalizePlate(b)
    if a == '' or b == '' then return false end
    return a == b
end

local function findOwnedVehicle(charId, plate)
    local rows = MySQL.query.await(
        'SELECT id, plate FROM vehicles WHERE character_id = ?',
        { charId }
    ) or {}
    for _, row in ipairs(rows) do
        if plateTextMatches(row.plate, plate) then
            return row
        end
    end
    return nil
end

local function findDrivenVehicle(source, plate)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local playerCoords = GetEntityCoords(ped)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if normalizePlate(GetVehicleNumberPlateText(vehicle)) == plate then
            local coords = GetEntityCoords(vehicle)
            if #(playerCoords - coords) <= 12.0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                return vehicle
            end
        end
    end
    return nil
end

local function findVehicleEntityByPlate(plate)
    plate = normalizePlate(plate)
    if plate == '' then return nil end
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and normalizePlate(GetVehicleNumberPlateText(vehicle)) == plate then
            return vehicle
        end
    end
    return nil
end

local function hasParkedPosition(veh)
    return veh
        and veh.parked_x ~= nil
        and veh.parked_y ~= nil
        and veh.parked_z ~= nil
        and tonumber(veh.parked_x) ~= nil
        and tonumber(veh.parked_y) ~= nil
        and tonumber(veh.parked_z) ~= nil
end

local function buildSpawnOpts(veh)
    local garage = Sunset.Garages[veh.garage or 'legion'] or Sunset.Garages.legion
    if not garage or not garage.spawn then return nil end

    if hasParkedPosition(veh) then
        return {
            x = tonumber(veh.parked_x),
            y = tonumber(veh.parked_y),
            z = tonumber(veh.parked_z),
            w = tonumber(veh.parked_h) or 0.0,
        }
    end

    local spawn = garage.spawn
    return {
        x = spawn.x,
        y = spawn.y,
        z = spawn.z,
        w = spawn.w or 0.0,
    }
end

exports.sunset_core:RegisterCallback('sunset:getVehicles', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    local rows = MySQL.query.await(
        'SELECT id, plate, model, fuel, engine, body, stored, garage, parked_x, parked_y, parked_z, parked_h, props, insurance_points, insurance_level, destroyed, insurance_cost FROM vehicles WHERE character_id = ?',
        { char.id }
    ) or {}
    return enrichVehicleList(rows)
end)

local function normalizeStored(val)
    if val == true or val == 1 or val == '1' then return 1 end
    if val == false or val == 0 or val == '0' then return 0 end
    local n = tonumber(val)
    if n == 1 then return 1 end
    if n == 0 then return 0 end
    return 1
end

exports.sunset_core:RegisterCallback('sunset:spawnVehicle', function(source, vehicleId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return nil, 'Invalid vehicle' end

    local veh = MySQL.single.await(
        'SELECT * FROM vehicles WHERE id = ? AND character_id = ?',
        { vehicleId, char.id }
    )
    if not veh then return nil, 'Vehicle not found' end

    if veh.destroyed == 1 or veh.destroyed == true or veh.destroyed == '1' then
        return nil, 'Acest vehicul este distrus! Revendică asigurarea din meniul garajului (/v).'
    end

    local stored = normalizeStored(veh.stored)
    local outPlates = {}

    if stored == 1 then
        outPlates = {}
        MySQL.update.await('UPDATE vehicles SET stored = 0 WHERE id = ?', { veh.id })
    elseif stored == 0 then
        outPlates = { { plate = veh.plate } }
    else
        return nil, 'Vehicle not available'
    end

    local spawnOpts = buildSpawnOpts(veh)
    if not spawnOpts then
        return nil, 'Garage spawn not configured'
    end

    TriggerClientEvent('sunset:client:cleanupOwnedVehicles', source, outPlates)
    TriggerClientEvent('sunset:client:spawnOwnedVehicle', source, veh, spawnOpts)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:getVehicleById', function(source, vehicleId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil end
    return enrichVehicleRow(MySQL.single.await(
        'SELECT id, plate, model, fuel, engine, body, stored, garage, parked_x, parked_y, parked_z, parked_h, props, insurance_points, insurance_level, destroyed, insurance_cost FROM vehicles WHERE id = ? AND character_id = ?',
        { vehicleId, char.id }
    ))
end)

exports.sunset_core:RegisterCallback('sunset:storeVehicle', function(source, garageId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    TriggerClientEvent('sunset:client:storeVehicleRequest', source, garageId or 'legion')
    return true
end)

local function storeOwnedVehicle(source, netId, plate, props, fuelLevel, garageId, parked)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local now = GetGameTimer()
    if now - (StoreRate[source] or 0) < 1500 then return nil, 'Please wait before storing again' end
    StoreRate[source] = now

    plate = normalizePlate(plate)
    if plate == '' or #plate > 8 or type(props) ~= 'table' then return nil, 'Invalid vehicle data' end

    local owned = MySQL.single.await(
        'SELECT id, props, fuel, engine, body FROM vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND character_id = ?',
        { plate, char.id }
    )
    if not owned then return nil, 'This vehicle is not owned by your character' end

    local storedProps = decodeProps(owned.props)
    for key, value in pairs(storedProps) do
        if props[key] == nil then props[key] = value end
    end
    local previousOdometer = math.max(0, tonumber(storedProps.odometer) or 0)
    props.odometer = math.max(previousOdometer, tonumber(props.odometer) or previousOdometer)
    local encodedProps = json.encode(props)
    if #encodedProps > 32768 then return nil, 'Vehicle data is too large' end

    local vehicle = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle)
        or normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then
        vehicle = findVehicleEntityByPlate(plate)
    end

    local playerPed = GetPlayerPed(source)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if driver ~= 0 and driver ~= playerPed then
            return nil, 'Vehiculul este condus în acest moment de altcineva'
        end
    end

    local engine = (vehicle and vehicle ~= 0 and DoesEntityExist(vehicle))
        and math.max(-4000, math.min(1000, GetVehicleEngineHealth(vehicle)))
        or (tonumber(owned.engine) or 1000.0)

    local body = (vehicle and vehicle ~= 0 and DoesEntityExist(vehicle))
        and math.max(0, math.min(1000, GetVehicleBodyHealth(vehicle)))
        or (tonumber(owned.body) or 1000.0)

    if fuelLevel == nil or tonumber(fuelLevel) == nil then
        fuelLevel = tonumber(owned.fuel) or 100.0
    else
        fuelLevel = math.max(0, math.min(100, tonumber(fuelLevel) or 100.0))
    end

    local px, py, pz, ph = nil, nil, nil, nil
    if type(parked) == 'table' and parked.x then
        px = tonumber(parked.x)
        py = tonumber(parked.y)
        pz = tonumber(parked.z)
        ph = tonumber(parked.h) or tonumber(parked.w)
    elseif vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local coords = GetEntityCoords(vehicle)
        px = coords.x
        py = coords.y
        pz = coords.z
        ph = GetEntityHeading(vehicle)
    end

    local changed = MySQL.update.await([[
        UPDATE vehicles SET stored = 1, garage = ?, props = ?, fuel = ?, engine = ?, body = ?,
            parked_x = ?, parked_y = ?, parked_z = ?, parked_h = ?
        WHERE id = ? AND character_id = ?
    ]], {
        garageId or 'legion',
        encodedProps,
        fuelLevel,
        engine,
        body,
        px, py, pz, ph,
        owned.id,
        char.id,
    })
    if not changed or changed < 1 then return nil, 'Vehicle could not be stored' end
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
    TriggerClientEvent('sunset:client:cleanupOwnedVehicles', -1, { { plate = plate } })
    return true
end

exports.sunset_core:RegisterCallback('sunset:storeOwnedVehicle', function(source, netId, plate, props, fuelLevel, garageId, parked)
    return storeOwnedVehicle(source, netId, plate, props, fuelLevel, garageId, parked)
end)

RegisterNetEvent('sunset:server:vehicleDestroyed', function(netId, plate)
    local src = source
    local char = exports.sunset_core:GetCharacter(src)
    if not char then return end

    plate = normalizePlate(plate)
    if plate == '' then return end

    local veh = MySQL.single.await(
        'SELECT id, model, insurance_points, insurance_level, insurance_cost, destroyed FROM vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND character_id = ?',
        { plate, char.id }
    )
    if not veh then return end

    if veh.destroyed == 1 or veh.destroyed == true or veh.destroyed == '1' then
        return
    end

    local currentLevel = math.max(1, math.min(11, tonumber(veh.insurance_level) or 1))
    local nextLevel = math.min(11, currentLevel + 1)
    local currentPoints = math.max(0, tonumber(veh.insurance_points) or 0)
    local nextPoints = math.max(0, currentPoints - 1)
    local baseCost = calculateVehicleInsuranceCost(veh.model, veh.insurance_cost)
    local claimCost = math.floor(baseCost * nextLevel)

    MySQL.update.await([[
        UPDATE vehicles
        SET destroyed = 1,
            stored = 0,
            insurance_points = ?,
            insurance_level = ?,
            engine = -4000.0
        WHERE id = ?
    ]], { nextPoints, nextLevel, veh.id })

    local vehicle = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        vehicle = findVehicleEntityByPlate(plate)
    end

    TriggerClientEvent('sunset:client:notify', src,
        ('Vehiculul tău [%s] a fost distrus! Asigurare: nivel %d/11 (Taxă: $%s) · Puncte rămase: %d. Deschide /v pentru recuperare.'):format(
            plate, nextLevel, claimCost, nextPoints
        ),
        'error'
    )

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetTimeout(12000, function()
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
            TriggerClientEvent('sunset:client:cleanupOwnedVehicles', -1, { { plate = plate } })
        end)
    end
end)

exports.sunset_core:RegisterCallback('sunset:claimVehicleInsurance', function(source, vehicleId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Nu ești conectat cu un caracter' end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return nil, 'Vehicul invalid' end

    local veh = MySQL.single.await(
        'SELECT id, model, plate, destroyed, insurance_points, insurance_level, insurance_cost, garage FROM vehicles WHERE id = ? AND character_id = ?',
        { vehicleId, char.id }
    )
    if not veh then return nil, 'Vehiculul nu a fost găsit' end

    local isDestroyed = (veh.destroyed == 1 or veh.destroyed == true or veh.destroyed == '1')
    if not isDestroyed then
        return nil, 'Acest vehicul nu este distrus. Îl poți scoate direct din garaj.'
    end

    local points = math.max(0, tonumber(veh.insurance_points) or 0)
    if points <= 0 then
        return nil, 'Nu mai ai puncte de asigurare! Reînnoiește asigurarea mai întâi.'
    end

    local baseCost = calculateVehicleInsuranceCost(veh.model, veh.insurance_cost)
    local level = math.max(1, math.min(11, tonumber(veh.insurance_level) or 1))
    local claimCost = math.floor(baseCost * level)

    local paidAccount = nil
    if exports.sunset_core:RemoveMoney(source, 'bank', claimCost, 'vehicle_insurance_claim') then
        paidAccount = 'bancă'
    elseif exports.sunset_core:RemoveMoney(source, 'cash', claimCost, 'vehicle_insurance_claim') then
        paidAccount = 'numerar'
    else
        return nil, ('Fonduri insuficiente. Ai nevoie de $%s (Bancă sau Cash).'):format(claimCost)
    end

    local plate = normalizePlate(veh.plate)
    local entity = findVehicleEntityByPlate(plate)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    TriggerClientEvent('sunset:client:cleanupOwnedVehicles', -1, { { plate = plate } })

    MySQL.update.await([[
        UPDATE vehicles
        SET stored = 1, destroyed = 0, engine = 1000.0, body = 1000.0, fuel = 100.0,
            parked_x = NULL, parked_y = NULL, parked_z = NULL, parked_h = NULL
        WHERE id = ? AND character_id = ?
    ]], { veh.id, char.id })

    TriggerClientEvent('sunset:client:notify', source,
        ('Asigurare revendicată cu succes pentru $%s (%s)! Vehiculul tău a fost reparat complet și te așteaptă în garaj.'):format(claimCost, paidAccount),
        'success'
    )

    return { ok = true, claimCost = claimCost }
end)

RegisterNetEvent('sunset:vehicles:adminRepairDatabase', function(plate)
    local src = source
    local char = exports.sunset_core:GetCharacter(src)
    if not char then return end
    plate = normalizePlate(plate)
    if plate == '' then return end

    MySQL.update.await([[
        UPDATE vehicles
        SET destroyed = 0, engine = 1000.0, body = 1000.0, fuel = 100.0
        WHERE REPLACE(UPPER(plate), " ", "") = ? AND character_id = ?
    ]], { plate, char.id })
end)


exports.sunset_core:RegisterCallback('sunset:renewVehicleInsurance', function(source, vehicleId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Nu ești conectat cu un caracter' end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return nil, 'Vehicul invalid' end

    local veh = MySQL.single.await(
        'SELECT id, model, plate, insurance_points, insurance_level, insurance_cost FROM vehicles WHERE id = ? AND character_id = ?',
        { vehicleId, char.id }
    )
    if not veh then return nil, 'Vehiculul nu a fost găsit' end

    local baseCost = calculateVehicleInsuranceCost(veh.model, veh.insurance_cost)
    local renewCost = math.floor(baseCost * 3)

    local paidAccount = nil
    if exports.sunset_core:RemoveMoney(source, 'bank', renewCost, 'vehicle_insurance_renew') then
        paidAccount = 'bancă'
    elseif exports.sunset_core:RemoveMoney(source, 'cash', renewCost, 'vehicle_insurance_renew') then
        paidAccount = 'numerar'
    else
        return nil, ('Fonduri insuficiente. Ai nevoie de $%s pentru reînnoirea a 5 puncte de asigurare.'):format(renewCost)
    end

    MySQL.update.await([[
        UPDATE vehicles
        SET insurance_points = insurance_points + 5
        WHERE id = ? AND character_id = ?
    ]], { veh.id, char.id })

    TriggerClientEvent('sunset:client:notify', source,
        ('Ai achiziționat +5 puncte de asigurare pentru $%s (%s)!'):format(renewCost, paidAccount),
        'success'
    )

    return { ok = true, renewCost = renewCost }
end)

exports.sunset_core:RegisterCallback('sunset:getDrivenOwnedVehicleState', function(source, netId, plate)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid vehicle plate' end

    local vehicle = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    local ped = GetPlayerPed(source)
    if vehicle == 0 or not DoesEntityExist(vehicle) or ped == 0
        or GetPedInVehicleSeat(vehicle, -1) ~= ped
        or normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then
        return nil, 'You must be driving the vehicle'
    end

    return MySQL.single.await(
        'SELECT id, props, fuel, engine, body FROM vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND character_id = ? AND stored = 0',
        { plate, char.id }
    )
end)

exports.sunset_core:RegisterCallback('sunset:syncOwnedVehicleState', function(source, netId, plate, reportedFuel, reportedOdometer)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end
    local now = GetGameTimer()
    if now - (StateSyncRate[source] or 0) < 10000 then return true end
    StateSyncRate[source] = now

    plate = normalizePlate(plate)
    local row = MySQL.single.await(
        'SELECT id, fuel, props FROM vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND character_id = ? AND stored = 0',
        { plate, char.id }
    )
    if not row then return nil, 'Owned vehicle not active' end
    local vehicle = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    local ped = GetPlayerPed(source)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not ped or ped == 0
        or GetPedInVehicleSeat(vehicle, -1) ~= ped or normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then
        return nil, 'Vehicle state rejected'
    end

    -- Driving may only consume fuel here. Refuelling has separate paid callbacks.
    local previousFuel = math.max(0, math.min(100, tonumber(row.fuel) or 100))
    local fuelValue = math.max(0, math.min(previousFuel + 0.5, tonumber(reportedFuel) or previousFuel))
    local engine = math.max(-4000, math.min(1000, GetVehicleEngineHealth(vehicle)))
    local body = math.max(0, math.min(1000, GetVehicleBodyHealth(vehicle)))
    local props = decodeProps(row.props)
    local previousOdometer = math.max(0, tonumber(props.odometer) or 0)
    local requestedOdometer = math.max(previousOdometer, tonumber(reportedOdometer) or previousOdometer)
    -- With a 30-second client interval, 8 km is already over 900 km/h.
    props.odometer = math.min(requestedOdometer, previousOdometer + 8.0)
    MySQL.update.await('UPDATE vehicles SET fuel = ?, engine = ?, body = ?, props = ? WHERE id = ? AND character_id = ?',
        { fuelValue, engine, body, json.encode(props), row.id, char.id })
    return true
end)

AddEventHandler('playerDropped', function()
    StoreRate[source] = nil
    StateSyncRate[source] = nil
    ParkRate[source] = nil
end)

local function isNearGasStation(playerCoords, maxDist)
    maxDist = maxDist or 30.0
    if not Sunset or not Sunset.GasStations then return false end
    for _, station in ipairs(Sunset.GasStations) do
        if station.coords and #(playerCoords - station.coords) <= maxDist then
            return true
        end
        if station.pumps then
            for _, pump in ipairs(station.pumps) do
                local pCoords = vector3(pump.x, pump.y, pump.z)
                if #(playerCoords - pCoords) <= 15.0 then
                    return true
                end
            end
        end
    end
    return false
end

exports.sunset_core:RegisterCallback('sunset:refuelVehiclePartial', function(source, fromFuel, toFuel, plate)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'Invalid player ped' end
    if not isNearGasStation(GetEntityCoords(ped)) then
        return nil, 'You must be at a gas station pump to refuel'
    end

    fromFuel = tonumber(fromFuel) or 0
    toFuel = tonumber(toFuel) or 0
    if toFuel <= fromFuel + 0.05 then return nil, 'Nothing to pay for' end
    if toFuel > 100 then toFuel = 100 end

    local added = toFuel - fromFuel
    local pricePer = Sunset.Config.FuelPricePerPercent or 1.75
    local cost = math.ceil(added * pricePer)
    if cost < 1 then return nil, 'Amount too small' end

    if not exports.sunset_core:RemoveMoney(source, 'cash', cost, 'fuel') then
        if not exports.sunset_core:RemoveMoney(source, 'bank', cost, 'fuel') then
            return nil, ('Not enough money ($%s needed)'):format(cost)
        end
    end

    plate = (plate or ''):gsub('%s+', ''):upper()
    if plate ~= '' then
        pcall(function()
            MySQL.update.await(
                'UPDATE vehicles SET fuel = ? WHERE plate = ? AND character_id = ?',
                { toFuel, plate, char.id }
            )
        end)
    end

    if GetResourceState('sunset_businesses') == 'started' then
        exports.sunset_businesses:RecordSaleAtCoords(GetEntityCoords(ped), 'gas', cost)
    end

    return { newFuel = toFuel, cost = cost, liters = added }
end)

exports.sunset_core:RegisterCallback('sunset:fillGasCan', function(source, targetLiters)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'Invalid player ped' end
    if not isNearGasStation(GetEntityCoords(ped)) then
        return nil, 'You must be at a gas station pump to fill a gas can'
    end

    if not exports.sunset_inventory:HasItem(source, 'gas_can', 1) then
        return nil, 'You need a gas can'
    end

    local maxLiters = Sunset.GetGasCanMaxLiters()
    local current = exports.sunset_inventory:GetGasCanLiters(source) or 0
    targetLiters = math.max(current, math.min(maxLiters, tonumber(targetLiters) or maxLiters))
    local added = targetLiters - current
    if added <= 0.05 then return nil, 'Gas can is already full' end

    local pricePer = Sunset.Config.FuelPricePerLiter or 2.92
    local cost = math.ceil(added * pricePer)
    if not exports.sunset_core:RemoveMoney(source, 'cash', cost, 'gas_can_fill') then
        if not exports.sunset_core:RemoveMoney(source, 'bank', cost, 'gas_can_fill') then
            return nil, ('Not enough money ($%s needed)'):format(cost)
        end
    end

    if not exports.sunset_inventory:SetItemMetadata(source, 'gas_can', { liters = targetLiters }) then
        exports.sunset_core:AddMoney(source, 'cash', cost, 'gas_can_refund')
        return nil, 'Could not fill gas can'
    end

    if GetResourceState('sunset_businesses') == 'started' then
        exports.sunset_businesses:RecordSaleAtCoords(GetEntityCoords(ped), 'gas', cost)
    end

    return { liters = targetLiters, maxLiters = maxLiters, cost = cost, added = added }
end)

exports.sunset_core:RegisterCallback('sunset:useGasCanOnVehicle', function(source, plate, tankLiters, vehicleClass)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end
    if not exports.sunset_inventory:HasItem(source, 'gas_can', 1) then
        return nil, 'You need a gas can'
    end

    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid vehicle' end

    local owned = findOwnedVehicle(char.id, plate)
    if not owned then return nil, 'This is not your vehicle' end

    local canLiters = exports.sunset_inventory:GetGasCanLiters(source) or 0
    local maxCanLiters = Sunset.GetGasCanMaxLiters()
    if canLiters <= 0.05 then return nil, 'Gas can is empty — fill it at a pump' end

    vehicleClass = tonumber(vehicleClass) or 1
    local tankCapacity = Sunset.GetVehicleTankCapacityLiters(vehicleClass)
    if tankCapacity <= 0 then return nil, 'This vehicle has no fuel tank' end

    local currentTankLiters = math.max(0, math.min(tankCapacity, tonumber(tankLiters) or 0))
    if currentTankLiters >= tankCapacity - 0.05 then
        return nil, 'Vehicle tank is already full'
    end

    local roomLiters = tankCapacity - currentTankLiters
    local transferLiters = math.min(canLiters, roomLiters)
    if transferLiters <= 0.05 then return nil, 'Vehicle tank is already full' end

    local fromTankLiters = currentTankLiters
    local newTankLiters = currentTankLiters + transferLiters
    local newCanLiters = canLiters - transferLiters
    local vehicleFuelPercent = Sunset.TankLitersToPercent(newTankLiters, vehicleClass)

    pcall(function()
        MySQL.update.await(
            'UPDATE vehicles SET fuel = ? WHERE id = ? AND character_id = ?',
            { vehicleFuelPercent, owned.id, char.id }
        )
    end)

    if newCanLiters <= 0.1 then
        exports.sunset_inventory:RemoveItem(source, 'gas_can', 1)
    else
        exports.sunset_inventory:SetItemMetadata(source, 'gas_can', { liters = newCanLiters })
    end

    return {
        vehicleFuel = vehicleFuelPercent,
        fromTankLiters = fromTankLiters,
        tankLiters = newTankLiters,
        tankCapacity = tankCapacity,
        transferredLiters = transferLiters,
        canLiters = newCanLiters,
        maxCanLiters = maxCanLiters,
    }
end)

local VehicleKeys = {}

local function plateKey(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

exports.sunset_core:RegisterCallback('sunset:hasVehicleKeys', function(source, plate)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end
    plate = plateKey(plate)
    local row = MySQL.single.await('SELECT character_id FROM vehicles WHERE REPLACE(plate, " ", "") = ?', { plate })
    if row and tonumber(row.character_id) == tonumber(char.id) then return true end
    return VehicleKeys[plate] and VehicleKeys[plate][char.id] == true
end)

exports.sunset_core:RegisterCallback('sunset:giveVehicleKeys', function(source, targetId, plate)
    local char = exports.sunset_core:GetCharacter(source)
    local target = exports.sunset_core:GetCharacter(tonumber(targetId))
    if not char or not target then return nil, 'Player not found' end
    plate = plateKey(plate)
    local row = MySQL.single.await('SELECT character_id FROM vehicles WHERE REPLACE(plate, " ", "") = ?', { plate })
    if not row or tonumber(row.character_id) ~= tonumber(char.id) then
        return nil, 'You do not own this vehicle'
    end
    VehicleKeys[plate] = VehicleKeys[plate] or {}
    VehicleKeys[plate][target.id] = true
    TriggerClientEvent('sunset:client:notify', tonumber(targetId), 'You received vehicle keys', 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:takeVehicleKeys', function(source, targetId, plate)
    local char = exports.sunset_core:GetCharacter(source)
    local target = exports.sunset_core:GetCharacter(tonumber(targetId))
    if not char or not target then return nil, 'Player not found' end
    plate = plateKey(plate)
    local row = MySQL.single.await('SELECT character_id FROM vehicles WHERE REPLACE(plate, " ", "") = ?', { plate })
    if not row or tonumber(row.character_id) ~= tonumber(char.id) then
        return nil, 'You do not own this vehicle'
    end
    if VehicleKeys[plate] then VehicleKeys[plate][target.id] = nil end
    TriggerClientEvent('sunset:client:notify', tonumber(targetId), 'Your vehicle keys were taken', 'warning')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:parkOwnedVehicle', function(source, netId, plate, reportedProps, reportedFuel)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end
    local now = GetGameTimer()
    if now - (ParkRate[source] or 0) < 1500 then return nil, 'Please wait before parking again' end
    ParkRate[source] = now

    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid vehicle plate' end
    local row = MySQL.single.await(
        'SELECT id, props, fuel FROM vehicles WHERE character_id = ? AND REPLACE(UPPER(plate), " ", "") = ?',
        { char.id, plate }
    )
    if not row then return nil, 'This is not your vehicle' end

    local ped = GetPlayerPed(source)
    local vehicle = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        vehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    end
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil, 'Sit in the driver seat of your vehicle to park it.'
    end
    if normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then
        return nil, 'The vehicle you are driving does not match this ownership record.'
    end

    local pos = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local props = decodeProps(row.props)
    if type(reportedProps) == 'table' then
        local previousOdometer = math.max(0, tonumber(props.odometer) or 0)
        local requestedOdometer = math.max(previousOdometer, tonumber(reportedProps.odometer) or previousOdometer)
        props.odometer = math.min(requestedOdometer, previousOdometer + 8.0)
    end
    local encodedProps = json.encode(props)
    if #encodedProps > 32768 then return nil, 'Vehicle data is too large' end

    -- Parking cannot repair or refuel a vehicle; those have separate paid,
    -- server-authoritative paths.
    local previousFuel = math.max(0, math.min(100, tonumber(row.fuel) or 100))
    local fuelValue = math.max(0, math.min(previousFuel + 0.5, tonumber(reportedFuel) or previousFuel))
    local engine = math.max(-4000, math.min(1000, GetVehicleEngineHealth(vehicle)))
    local body = math.max(0, math.min(1000, GetVehicleBodyHealth(vehicle)))
    local changed = MySQL.update.await([[
        UPDATE vehicles SET stored = 0, props = ?, fuel = ?, engine = ?, body = ?,
            parked_x = ?, parked_y = ?, parked_z = ?, parked_h = ?
        WHERE id = ? AND character_id = ?
    ]], { encodedProps, fuelValue, engine, body, pos.x, pos.y, pos.z, heading, row.id, char.id })
    if not changed or changed < 1 then return nil, 'The parking position could not be saved' end
    return { ok = true, x = pos.x, y = pos.y, z = pos.z, heading = heading }
end)

local function notifyPlayer(source, message, kind)
    if source == 0 then
        print(('[givecar] %s'):format(message))
        return
    end
    exports.sunset_core:CommandReply(source, message, kind or 'info')
end

local function runGiveCar(source, args)
    if source ~= 0 and not exports.sunset_admin:IsAdmin(source, 3) then
        exports.sunset_core:CommandDenyAdmin(source, 'givecar')
        return
    end

    local target = tonumber(args[1])
    local model = string.lower((args[2] or 'sultan'):gsub('%s+', ''))
    if not target then
        notifyPlayer(source, 'Usage: /givecar [player id] [model]', 'error')
        return
    end

    if not GetPlayerName(target) then
        notifyPlayer(source, ('Player #%d is not online. Check F10 for current server IDs.'):format(target), 'error')
        return
    end

    local char = exports.sunset_core:GetCharacter(target)
    if not char then
        exports.sunset_core:CommandNoCharacter(source, target)
        return
    end

    local vehicleId
    for _ = 1, 8 do
        local plate = generatePlate()
        local ok, result = pcall(function()
            return MySQL.insert.await(
                'INSERT INTO vehicles (character_id, plate, model, stored, garage) VALUES (?, ?, ?, 1, ?)',
                { char.id, plate, model, 'legion' }
            )
        end)
        if ok and result then
            vehicleId = result
            break
        end
    end

    if not vehicleId then
        local name = exports.sunset_core:GetPlayerDisplayName(target) or GetPlayerName(target) or '?'
        notifyPlayer(source,
            ('Could not store %s in Legion garage for %s (#%d) — database insert failed after 8 plate attempts.'):format(
                model, name, target), 'error')
        return
    end

    local targetName = exports.sunset_core:GetPlayerDisplayName(target)
    TriggerClientEvent('sunset:client:notify', target, ('You received a vehicle: %s'):format(model), 'success')
    notifyPlayer(
        source,
        ('Gave %s to %s (#%d) — stored in Legion garage'):format(model, targetName, target),
        'success'
    )
end

RegisterCommand('givecar', function(source, args)
    runGiveCar(source, args)
end, false)

function ExecutePlayerCommand(source, name, args)
    if string.lower(tostring(name or '')) ~= 'givecar' then return false end
    runGiveCar(source, args or {})
    return true
end

exports('ExecutePlayerCommand', ExecutePlayerCommand)

function TransferVehicleOwnership(vehicleId, fromCharId, toCharId)
    vehicleId = tonumber(vehicleId)
    fromCharId = tonumber(fromCharId)
    toCharId = tonumber(toCharId)
    if not vehicleId or not fromCharId or not toCharId then
        return false, 'Invalid vehicle transfer.'
    end

    local row = MySQL.single.await(
        'SELECT id, plate, stored, destroyed FROM vehicles WHERE id = ? AND character_id = ?',
        { vehicleId, fromCharId }
    )
    if not row then return false, 'Seller no longer owns this vehicle.' end
    if row.destroyed == 1 or row.destroyed == true or row.destroyed == '1' then
        return false, 'Destroyed vehicles cannot be traded.'
    end
    if normalizeStored(row.stored) ~= 1 then
        return false, 'Only garage-stored vehicles can be traded.'
    end

    local entity = findVehicleEntityByPlate(row.plate)
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    local changed = MySQL.update.await(
        'UPDATE vehicles SET character_id = ?, stored = 1 WHERE id = ? AND character_id = ?',
        { toCharId, vehicleId, fromCharId }
    )
    if changed ~= 1 then return false, 'Vehicle transfer failed.' end
    return true
end
exports('TransferVehicleOwnership', TransferVehicleOwnership)
