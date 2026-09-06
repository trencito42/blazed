local PurchaseLocks = {}
local TestDriveCooldown = {}
local TestDrives = {}

local function isAdmin(source)
    return GetResourceState('sunset_admin') == 'started'
        and exports.sunset_admin:IsAdmin(source, 3)
end

local function nearDealership(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - Sunset.Dealership.coords) <= (Sunset.Dealership.serverRadius or 12.0)
end

local function cleanText(value, maxLength, fallback)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    value = value:gsub('[%c]', '')
    if value == '' then value = fallback or '' end
    return value:sub(1, maxLength)
end

local function cleanModel(value)
    local model = cleanText(value, 64):lower()
    if model == '' or not model:match('^[a-z0-9_]+$') then return nil end
    return model
end

local function booleanValue(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

local function generatePlate()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
    for _ = 1, 12 do
        local plate = ''
        for _ = 1, 8 do
            local idx = math.random(1, #chars)
            plate = plate .. chars:sub(idx, idx)
        end
        if not MySQL.scalar.await('SELECT 1 FROM vehicles WHERE plate = ? LIMIT 1', { plate }) then
            return plate
        end
    end
end

local function fetchCatalog(includeHidden)
    local where = includeHidden and '' or 'WHERE available = 1'
    return MySQL.query.await(([=[
        SELECT model, label, brand, category, price, stock, available, test_drive_enabled, display_order
        FROM dealership_vehicles %s
        ORDER BY display_order ASC, brand ASC, label ASC
    ]=]):format(where)) or {}
end

exports.sunset_core:RegisterCallback('sunset:dealership:getCatalog', function(source, adminMode)
    if not adminMode and not nearDealership(source) then
        return nil, 'Go to Premium Deluxe Motorsport and stand inside the orange marker.'
    end
    if adminMode and not isAdmin(source) then
        return nil, 'Dealership administration requires Admin level 3 or higher.'
    end
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and select it again.' end
    return {
        dealership = Sunset.Dealership.label,
        admin = adminMode == true,
        vehicles = fetchCatalog(adminMode == true),
        money = { cash = char.cash or 0, bank = char.bank or 0 },
        testDriveSeconds = Sunset.Dealership.testDriveSeconds or 60,
    }
end)

exports.sunset_core:RegisterCallback('sunset:dealership:testDrive', function(source, model)
    if not nearDealership(source) then
        return nil, 'Start test drives from the dealership marker.'
    end
    model = cleanModel(model)
    if not model then return nil, 'Invalid vehicle selection. Reopen the dealership.' end
    local row = MySQL.single.await(
        'SELECT model, label, test_drive_enabled FROM dealership_vehicles WHERE model = ? AND available = 1',
        { model })
    if not row then return nil, 'That vehicle is no longer available.' end
    if not booleanValue(row.test_drive_enabled) then return nil, 'Test drives are disabled for this vehicle.' end

    local now = os.time()
    local remaining = 90 - (now - (TestDriveCooldown[source] or 0))
    if remaining > 0 then return nil, ('Next test drive is available in %d seconds.'):format(remaining) end
    TestDriveCooldown[source] = now
    if TestDrives[source] and DoesEntityExist(TestDrives[source]) then DeleteEntity(TestDrives[source]) end
    local s = Sunset.Dealership.testDriveSpawn
    local vehicle = CreateVehicle(joaat(row.model), s.x, s.y, s.z, s.w or 0.0, true, true)
    if not vehicle or vehicle == 0 then
        TestDriveCooldown[source] = nil
        return nil, 'The test-drive vehicle could not be created. Try again in a clear spawn area.'
    end
    Entity(vehicle).state:set('sunsetProtectedVehicle', true, true)
    TestDrives[source] = vehicle
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetTimeout(((Sunset.Dealership.testDriveSeconds or 60) + 15) * 1000, function()
        if TestDrives[source] == vehicle then TestDrives[source] = nil end
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end)
    return {
        model = row.model,
        label = row.label,
        seconds = Sunset.Dealership.testDriveSeconds or 60,
        netId = netId,
        returnPoint = Sunset.Dealership.testDriveReturn,
    }
end)

RegisterNetEvent('sunset:dealership:endTestDrive', function(netId)
    local source = source
    local vehicle = TestDrives[source]
    if not vehicle then return end
    if tonumber(netId) and NetworkGetNetworkIdFromEntity(vehicle) ~= tonumber(netId) then return end
    TestDrives[source] = nil
    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
end)

exports.sunset_core:RegisterCallback('sunset:dealership:purchase', function(source, model, color)
    if PurchaseLocks[source] then return nil, 'Your previous purchase is still being processed.' end
    if not nearDealership(source) then return nil, 'Purchase the vehicle from the dealership marker.' end
    model = cleanModel(model)
    if not model then return nil, 'Invalid vehicle selection. Reopen the dealership.' end

    PurchaseLocks[source] = true
    local function finish(result, err)
        PurchaseLocks[source] = nil
        return result, err
    end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return finish(nil, 'Your character is not loaded. Reconnect and select it again.') end
    local row = MySQL.single.await(
        'SELECT model, label, price, stock FROM dealership_vehicles WHERE model = ? AND available = 1',
        { model })
    if not row then return finish(nil, 'That vehicle is unavailable or was removed from sale.') end

    local price = math.max(1, math.floor(tonumber(row.price) or 0))
    local account
    if (char.bank or 0) >= price then account = 'bank'
    elseif (char.cash or 0) >= price then account = 'cash'
    else
        return finish(nil, ('You need $%d. Bank: $%d, cash: $%d.'):format(
            price, char.bank or 0, char.cash or 0))
    end

    local reserved = MySQL.update.await([[
        UPDATE dealership_vehicles SET stock = stock - 1
        WHERE model = ? AND available = 1 AND stock > 0
    ]], { model })
    if not reserved or reserved < 1 then
        return finish(nil, 'This vehicle just sold out. The catalog has been refreshed.')
    end

    if not exports.sunset_core:RemoveMoney(source, account, price, 'dealership_purchase') then
        MySQL.update.await('UPDATE dealership_vehicles SET stock = stock + 1 WHERE model = ?', { model })
        return finish(nil, 'Your balance changed before checkout. No money was charged.')
    end

    local plate = generatePlate()
    if not plate then
        exports.sunset_core:AddMoney(source, account, price, 'dealership_refund')
        MySQL.update.await('UPDATE dealership_vehicles SET stock = stock + 1 WHERE model = ?', { model })
        return finish(nil, 'A unique license plate could not be generated. Your money was returned.')
    end

    local ok, vehicleId = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO vehicles (character_id, plate, model, stored, garage, fuel, engine, body)
            VALUES (?, ?, ?, 1, ?, 100, 1000, 1000)
        ]], { char.id, plate, model, Sunset.Dealership.purchaseGarage or 'legion' })
    end)
    if not ok or not vehicleId then
        exports.sunset_core:AddMoney(source, account, price, 'dealership_refund')
        MySQL.update.await('UPDATE dealership_vehicles SET stock = stock + 1 WHERE model = ?', { model })
        return finish(nil, 'The purchase could not be saved. Your money and dealership stock were restored.')
    end
    pcall(function()
        local colorId = math.max(0, math.min(160, math.floor(tonumber(color) or 0)))
        MySQL.update.await('UPDATE vehicles SET props = ?, engine = 1000, body = 1000, fuel = 100 WHERE id = ?', {
            json.encode({ color1 = colorId, color2 = colorId }), vehicleId
        })
    end)

    pcall(function()
        MySQL.update.await('UPDATE characters SET cash = ?, bank = ? WHERE id = ?',
            { char.cash or 0, char.bank or 0, char.id })
        MySQL.insert.await([[
            INSERT INTO dealership_sales (character_id, vehicle_id, model, plate, price, payment_account)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], { char.id, vehicleId, model, plate, price, account })
    end)

    return finish({ id = vehicleId, model = model, label = row.label, plate = plate, price = price })
end)

local function auditAdmin(source, action, model, payload)
    local char = exports.sunset_core:GetCharacter(source)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO dealership_admin_log (admin_name, character_id, action, model, payload)
            VALUES (?, ?, ?, ?, ?)
        ]], { GetPlayerName(source) or ('player_' .. source), char and char.id or nil,
            action, model, payload and json.encode(payload) or nil })
    end)
end

exports.sunset_core:RegisterCallback('sunset:dealership:adminSave', function(source, data)
    if not isAdmin(source) then return nil, 'Dealership administration requires Admin level 3 or higher.' end
    if type(data) ~= 'table' then return nil, 'The vehicle form is invalid.' end
    local model = cleanModel(data.model)
    if not model then return nil, 'Model must contain only letters, numbers, or underscore.' end
    local label = cleanText(data.label, 80, model)
    local brand = cleanText(data.brand, 48, 'Other')
    local category = cleanText(data.category, 32, 'other'):lower()
    local price = math.floor(tonumber(data.price) or -1)
    local stock = math.floor(tonumber(data.stock) or -1)
    local displayOrder = math.max(0, math.min(9999, math.floor(tonumber(data.displayOrder) or 100)))
    if price < 1 or price > 2000000000 then return nil, 'Price must be between $1 and $2,000,000,000.' end
    if stock < 0 or stock > 1000000 then return nil, 'Stock must be between 0 and 1,000,000.' end

    MySQL.insert.await([[
        INSERT INTO dealership_vehicles
            (model, label, brand, category, price, stock, available, test_drive_enabled, display_order)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), brand = VALUES(brand),
            category = VALUES(category), price = VALUES(price), stock = VALUES(stock),
            available = VALUES(available), test_drive_enabled = VALUES(test_drive_enabled),
            display_order = VALUES(display_order)
    ]], { model, label, brand, category, price, stock,
        booleanValue(data.available) and 1 or 0,
        booleanValue(data.testDriveEnabled) and 1 or 0, displayOrder })
    auditAdmin(source, 'save', model, data)
    return { vehicles = fetchCatalog(true) }
end)

exports.sunset_core:RegisterCallback('sunset:dealership:adminDelete', function(source, model)
    if not isAdmin(source) then return nil, 'Dealership administration requires Admin level 3 or higher.' end
    model = cleanModel(model)
    if not model then return nil, 'Invalid vehicle model.' end
    local changed = MySQL.update.await('DELETE FROM dealership_vehicles WHERE model = ?', { model })
    if not changed or changed < 1 then return nil, 'That dealership vehicle no longer exists.' end
    auditAdmin(source, 'delete', model)
    return { vehicles = fetchCatalog(true) }
end)

AddEventHandler('playerDropped', function()
    PurchaseLocks[source] = nil
    TestDriveCooldown[source] = nil
    local vehicle = TestDrives[source]
    TestDrives[source] = nil
    if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
end)
