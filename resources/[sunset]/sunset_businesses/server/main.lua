local function character(source)
    return exports.sunset_core:GetCharacter(source)
end

local function isAdmin(source)
    if GetResourceState('sunset_admin') ~= 'started' then return false end
    return exports.sunset_admin:IsAdmin(source, SunsetBusinesses.AdminLevel or 3)
end

local function slugify(text)
    return tostring(text or 'business'):lower():gsub('[^a-z0-9]+', '_'):gsub('^_+', ''):gsub('_+$', '')
end

local function nearby(source, coords, radius)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (radius or SunsetBusinesses.PurchaseRadius or 3.5)
end

local function rowToView(row)
    if not row then return nil end
    return {
        id = tonumber(row.id),
        shopKey = row.shop_key,
        businessType = row.business_type or 'shop',
        catalogKey = row.catalog_key,
        label = row.label,
        price = tonumber(row.price) or 0,
        profitPercent = tonumber(row.profit_percent) or (SunsetBusinesses.DefaultProfitPercent or 70),
        balance = tonumber(row.balance) or 0,
        ownerCharacterId = row.owner_character_id and tonumber(row.owner_character_id) or nil,
        ownerName = row.owner_name,
        forSale = row.for_sale == 1 or row.for_sale == true,
        enabled = row.enabled == 1 or row.enabled == true,
        coords = {
            x = tonumber(row.coords_x) or 0,
            y = tonumber(row.coords_y) or 0,
            z = tonumber(row.coords_z) or 0,
        },
    }
end

local function fetchRow(businessId)
    return MySQL.single.await([[
        SELECT b.*, CONCAT_WS(' ', c.firstname, c.lastname) AS owner_name
        FROM player_businesses b
        LEFT JOIN characters c ON c.id = b.owner_character_id
        WHERE b.id = ?
    ]], { tonumber(businessId) })
end

local function bootstrapLocations()
    for catalogKey, shop in pairs(Sunset.Shops or {}) do
        if shop.coords then
            MySQL.insert.await([[
                INSERT INTO player_businesses
                    (shop_key, business_type, label, catalog_key, price, coords_x, coords_y, coords_z, profit_percent, for_sale, enabled)
                VALUES (?, 'shop', ?, ?, ?, ?, ?, ?, ?, 1, 1)
                ON DUPLICATE KEY UPDATE
                    business_type = VALUES(business_type),
                    label = VALUES(label),
                    catalog_key = VALUES(catalog_key),
                    coords_x = VALUES(coords_x),
                    coords_y = VALUES(coords_y),
                    coords_z = VALUES(coords_z)
            ]], {
                'shop_' .. catalogKey,
                shop.label or catalogKey,
                catalogKey,
                tonumber(SunsetBusinesses.DefaultShopPrice) or 175000,
                shop.coords.x, shop.coords.y, shop.coords.z,
                tonumber(SunsetBusinesses.DefaultProfitPercent) or 70,
            })
        end
    end

    for _, station in ipairs(Sunset.GasStations or {}) do
        if station.coords then
            local shopKey = 'gas_' .. slugify(station.label)
            MySQL.insert.await([[
                INSERT INTO player_businesses
                    (shop_key, business_type, label, catalog_key, price, coords_x, coords_y, coords_z, profit_percent, for_sale, enabled)
                VALUES (?, 'gas', ?, '', ?, ?, ?, ?, ?, 1, 1)
                ON DUPLICATE KEY UPDATE
                    business_type = VALUES(business_type),
                    label = VALUES(label),
                    coords_x = VALUES(coords_x),
                    coords_y = VALUES(coords_y),
                    coords_z = VALUES(coords_z)
            ]], {
                shopKey,
                station.label or 'Gas Station',
                tonumber(SunsetBusinesses.DefaultGasPrice) or 275000,
                station.coords.x, station.coords.y, station.coords.z,
                tonumber(SunsetBusinesses.DefaultProfitPercent) or 70,
            })
        end
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    bootstrapLocations()
end)

local function findNearestBusiness(coords, businessType, maxDistance)
    maxDistance = maxDistance or 18.0
    local rows = MySQL.query.await(
        'SELECT * FROM player_businesses WHERE enabled = 1 AND business_type = ?',
        { businessType }
    ) or {}
    local best, bestDist
    for _, row in ipairs(rows) do
        local pos = vector3(tonumber(row.coords_x) or 0, tonumber(row.coords_y) or 0, tonumber(row.coords_z) or 0)
        local dist = #(coords - pos)
        if dist <= maxDistance and (not bestDist or dist < bestDist) then
            best = row
            bestDist = dist
        end
    end
    return best
end

function RecordSale(businessId, grossAmount)
    businessId = tonumber(businessId)
    grossAmount = math.floor(tonumber(grossAmount) or 0)
    if not businessId or grossAmount <= 0 then return end

    local row = MySQL.single.await(
        'SELECT id, owner_character_id, profit_percent FROM player_businesses WHERE id = ? AND enabled = 1',
        { businessId }
    )
    if not row or not row.owner_character_id then return end

    local percent = math.max(0, math.min(100, tonumber(row.profit_percent) or (SunsetBusinesses.DefaultProfitPercent or 70)))
    local share = math.floor(grossAmount * percent / 100)
    if share < 1 then return end

    MySQL.update.await('UPDATE player_businesses SET balance = balance + ? WHERE id = ?', { share, businessId })
end
exports('RecordSale', RecordSale)

function RecordSaleAtCoords(coords, businessType, grossAmount)
    if type(coords) ~= 'vector3' then
        coords = vector3(tonumber(coords.x) or 0, tonumber(coords.y) or 0, tonumber(coords.z) or 0)
    end
    local radius = businessType == 'gas' and 25.0 or 18.0
    local row = findNearestBusiness(coords, businessType, radius)
    if row then RecordSale(row.id, grossAmount) end
end
exports('RecordSaleAtCoords', RecordSaleAtCoords)

function GetBusinessRow(businessId)
    businessId = tonumber(businessId)
    if not businessId then return nil end
    return rowToView(fetchRow(businessId))
end
exports('GetBusinessRow', GetBusinessRow)

function GetOwnedBusinesses(source)
    local char = character(source)
    if not char then return {} end
    local rows = MySQL.query.await([[
        SELECT b.*, CONCAT_WS(' ', c.firstname, c.lastname) AS owner_name
        FROM player_businesses b
        LEFT JOIN characters c ON c.id = b.owner_character_id
        WHERE b.owner_character_id = ? AND b.enabled = 1
        ORDER BY b.label ASC
    ]], { char.id }) or {}
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = rowToView(row) end
    return out
end
exports('GetOwnedBusinesses', GetOwnedBusinesses)

function TransferOwnership(businessId, fromCharId, toCharId)
    businessId = tonumber(businessId)
    fromCharId = tonumber(fromCharId)
    toCharId = tonumber(toCharId)
    if not businessId or not fromCharId or not toCharId then return false, 'Invalid business transfer.' end
    local changed = MySQL.update.await(
        'UPDATE player_businesses SET owner_character_id = ?, for_sale = 0 WHERE id = ? AND owner_character_id = ?',
        { toCharId, businessId, fromCharId }
    )
    if not changed or changed < 1 then return false, 'Business ownership could not be transferred.' end
    TriggerClientEvent('sunset:client:businessesChanged', -1)
    return true
end
exports('TransferOwnership', TransferOwnership)
exports('GetMaxOwnedPerCharacter', function()
    return tonumber(SunsetBusinesses.MaxOwnedPerCharacter) or 0
end)

local function businessListForPlayer(source)
    local char = character(source)
    local rows = MySQL.query.await([[
        SELECT b.*, CONCAT_WS(' ', c.firstname, c.lastname) AS owner_name
        FROM player_businesses b
        LEFT JOIN characters c ON c.id = b.owner_character_id
        WHERE b.enabled = 1
        ORDER BY b.business_type ASC, b.label ASC
    ]]) or {}
    local list = {}
    for _, row in ipairs(rows) do
        local view = rowToView(row)
        view.owned = view.ownerCharacterId ~= nil
        view.mine = char and view.ownerCharacterId == tonumber(char.id)
        list[#list + 1] = view
    end
    return list
end

exports.sunset_core:RegisterCallback('sunset:getBusinesses', function(source)
    return businessListForPlayer(source)
end)

exports.sunset_core:RegisterCallback('sunset:getStoreContext', function(source)
    local char = character(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    local row = findNearestBusiness(coords, 'shop', 4.0)
    local shopId = 'twentyfour7'
    local shopLabel = '24/7 Store'
    if row and row.catalog_key and Sunset.Shops[row.catalog_key] then
        shopId = row.catalog_key
        shopLabel = row.label or Sunset.Shops[shopId].label or shopLabel
    elseif Sunset.Shops.twentyfour7 then
        shopLabel = Sunset.Shops.twentyfour7.label or shopLabel
    end

    local business = nil
    if row then
        local view = rowToView(row)
        view.owned = view.ownerCharacterId ~= nil
        view.mine = char and view.ownerCharacterId == tonumber(char.id)
        business = view
        if view.label then shopLabel = view.label end
    end

    return {
        shopId = shopId,
        shopLabel = shopLabel,
        business = business,
    }
end)

exports.sunset_core:RegisterCallback('sunset:getBusinessForShop', function(source, shopId)
    local shop = Sunset.Shops[shopId]
    if not shop or not shop.coords then return nil end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local row = findNearestBusiness(GetEntityCoords(ped), 'shop', 15.0)
    if not row or row.catalog_key ~= shopId then return nil end
    return tonumber(row.id)
end)

exports.sunset_core:RegisterCallback('sunset:buyBusiness', function(source, businessId)
    local char = character(source)
    if not char then return nil, 'Character not loaded.' end
    local row = MySQL.single.await('SELECT * FROM player_businesses WHERE id = ? AND enabled = 1', { tonumber(businessId) })
    if not row then return nil, 'Business not found.' end
    if row.owner_character_id then return nil, 'This business already has an owner.' end
    if row.for_sale ~= 1 and row.for_sale ~= true then return nil, 'This business is not for sale.' end
    local coords = vector3(tonumber(row.coords_x) or 0, tonumber(row.coords_y) or 0, tonumber(row.coords_z) or 0)
    if not nearby(source, coords) then return nil, 'Stand at the business entrance to buy it.' end

    local maxOwned = tonumber(SunsetBusinesses.MaxOwnedPerCharacter) or 0
    if maxOwned > 0 then
        local count = tonumber(MySQL.scalar.await(
            'SELECT COUNT(*) FROM player_businesses WHERE owner_character_id = ?',
            { char.id }
        )) or 0
        if count >= maxOwned then
            return nil, ('You can own at most %d businesses.'):format(maxOwned)
        end
    end

    local price = tonumber(row.price) or 0
    if exports.sunset_core:GetMoney(source, 'bank') < price and exports.sunset_core:GetMoney(source, 'cash') < price then
        return nil, ('You need $%s in bank or cash to buy this business.'):format(price)
    end

    local claimed = MySQL.update.await(
        'UPDATE player_businesses SET owner_character_id = ?, for_sale = 0 WHERE id = ? AND owner_character_id IS NULL',
        { char.id, row.id }
    )
    if claimed ~= 1 then return nil, 'Another player bought this business first.' end

    local paid = exports.sunset_core:RemoveMoney(source, 'bank', price, 'business_purchase')
        or exports.sunset_core:RemoveMoney(source, 'cash', price, 'business_purchase')
    if not paid then
        MySQL.update.await(
            'UPDATE player_businesses SET owner_character_id = NULL, for_sale = 1 WHERE id = ? AND owner_character_id = ?',
            { row.id, char.id }
        )
        return nil, 'Payment failed; the purchase was rolled back.'
    end

    TriggerClientEvent('sunset:client:businessesChanged', -1)
    return true, ('You bought %s for $%s.'):format(row.label, price)
end)

local function ownerDashboard(source)
    local char = character(source)
    if not char then return nil, 'Character not loaded.' end
    local owned = GetOwnedBusinesses(source)
    local totalBalance = 0
    for _, row in ipairs(owned) do totalBalance = totalBalance + (row.balance or 0) end
    return {
        mode = 'owner',
        businesses = owned,
        totalBalance = totalBalance,
        defaultProfitPercent = SunsetBusinesses.DefaultProfitPercent or 70,
    }
end

local function adminDashboard(source, selectedId)
    if not isAdmin(source) then return nil, 'Admin access required.' end
    local businesses = businessListForPlayer(source)
    local selected = nil
    selectedId = tonumber(selectedId)
    if selectedId then
        for _, row in ipairs(businesses) do
            if row.id == selectedId then selected = row break end
        end
    end
    if not selected and businesses[1] then selected = businesses[1] end
    return {
        mode = 'admin',
        businesses = businesses,
        selected = selected,
        defaultProfitPercent = SunsetBusinesses.DefaultProfitPercent or 70,
        permissions = { admin = true },
    }
end

exports.sunset_core:RegisterCallback('sunset:businessOwnerDashboard', function(source)
    return ownerDashboard(source)
end)

exports.sunset_core:RegisterCallback('sunset:businessAdminDashboard', function(source, selectedId)
    return adminDashboard(source, selectedId)
end)

local function refreshAfterManage(source, mode, selectedId)
    if mode == 'admin' then return adminDashboard(source, selectedId) end
    return ownerDashboard(source)
end

exports.sunset_core:RegisterCallback('sunset:businessManage', function(source, payload)
    payload = type(payload) == 'table' and payload or {}
    local action = payload.action
    local businessId = tonumber(payload.businessId)
    local mode = payload.mode == 'admin' and 'admin' or 'owner'

    if action == 'withdraw' then
        local char = character(source)
        if not char then return nil, 'Character not loaded.' end
        local row = MySQL.single.await(
            'SELECT id, balance, owner_character_id FROM player_businesses WHERE id = ? AND enabled = 1',
            { businessId }
        )
        if not row or tonumber(row.owner_character_id) ~= tonumber(char.id) then
            return nil, 'You do not own this business.'
        end
        local amount = math.floor(tonumber(row.balance) or 0)
        if amount <= 0 then return nil, 'No profit to withdraw yet.' end
        local changed = MySQL.update.await(
            'UPDATE player_businesses SET balance = 0 WHERE id = ? AND owner_character_id = ? AND balance >= ?',
            { businessId, char.id, amount }
        )
        if changed ~= 1 then return nil, 'Withdraw failed.' end
        if not exports.sunset_core:AddMoney(source, 'bank', amount, 'business_withdraw') then
            MySQL.update.await('UPDATE player_businesses SET balance = balance + ? WHERE id = ?', { amount, businessId })
            return nil, 'Could not deposit to your bank.'
        end
        TriggerClientEvent('sunset:client:businessesChanged', -1)
        return refreshAfterManage(source, 'owner'), ('Withdrew $%s to your bank.'):format(amount)
    end

    if action == 'select' then
        if not isAdmin(source) then return nil, 'Admin access required.' end
        return adminDashboard(source, businessId)
    end

    if mode == 'admin' then
        if not isAdmin(source) then return nil, 'Admin access required.' end
        if action == 'update' then
            local label = tostring(payload.label or ''):sub(1, 128)
            local price = math.max(0, math.floor(tonumber(payload.price) or 0))
            local profitPercent = math.max(0, math.min(100, math.floor(tonumber(payload.profitPercent) or 70)))
            local forSale = payload.forSale == true or payload.forSale == 1 or payload.forSale == '1'
            local enabled = payload.enabled ~= false and payload.enabled ~= 0 and payload.enabled ~= '0'
            if label == '' then return nil, 'Label is required.' end
            MySQL.update.await([[
                UPDATE player_businesses
                SET label = ?, price = ?, profit_percent = ?, for_sale = ?, enabled = ?
                WHERE id = ?
            ]], {
                label, price, profitPercent, forSale and 1 or 0, enabled and 1 or 0, businessId,
            })
            TriggerClientEvent('sunset:client:businessesChanged', -1)
            return refreshAfterManage(source, 'admin', businessId), 'Business updated.'
        elseif action == 'clearOwner' then
            MySQL.update.await(
                'UPDATE player_businesses SET owner_character_id = NULL, for_sale = 1 WHERE id = ?',
                { businessId }
            )
            TriggerClientEvent('sunset:client:businessesChanged', -1)
            return refreshAfterManage(source, 'admin', businessId), 'Owner cleared; business is for sale again.'
        elseif action == 'teleport' then
            local row = fetchRow(businessId)
            if not row then return nil, 'Business not found.' end
            TriggerClientEvent('sunset:client:businessTeleport', source, {
                x = tonumber(row.coords_x) or 0,
                y = tonumber(row.coords_y) or 0,
                z = tonumber(row.coords_z) or 0,
            })
            return refreshAfterManage(source, 'admin', businessId), 'Teleported to business.'
        end
        return nil, 'Unknown admin action.'
    end

    return nil, 'Unknown action.'
end)
