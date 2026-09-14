-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Drug Pipeline (server/main.lua)
--  Manufacture → Process → Sell. Server-authoritative.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetDrugs.Config
local HarvestCooldowns = {}
local ProcessCooldowns = {}
local SellCooldowns = {}

local function notify(source, msg, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', duration or 5000)
end

local function getCharId(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.id) or nil
end

-- ═══ STAGE 1: MANUFACTURE (harvest raw materials) ═══

exports.sunset_core:RegisterCallback('sunset:drugs:harvest', function(source, spotIndex)
    spotIndex = tonumber(spotIndex)
    if not spotIndex or not Cfg.manufacture.spots[spotIndex] then
        return nil, 'Invalid harvest spot.'
    end

    local now = GetGameTimer()
    if HarvestCooldowns[source] and now - HarvestCooldowns[source] < (Cfg.manufacture.cooldownMs or 30000) then
        return nil, 'You need to wait before harvesting again.'
    end

    -- Check proximity
    local spot = Cfg.manufacture.spots[spotIndex]
    local near = false
    pcall(function()
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            near = #(coords - spot) < 10.0
        end
    end)
    if not near then
        return nil, 'You are not at a harvest spot.'
    end

    HarvestCooldowns[source] = now

    -- Random yield
    local yield = math.random(Cfg.manufacture.yieldMin or 1, Cfg.manufacture.yieldMax or 3)
    local drugTypes = {}
    for drugType in pairs(Cfg.drugs or {}) do
        drugTypes[#drugTypes + 1] = drugType
    end
    local drugType = drugTypes[math.random(#drugTypes)]
    local drug = Cfg.drugs[drugType]

    -- Give raw material
    local ok, err = pcall(function()
        return exports.sunset_inventory:AddItem(source, drug.raw, yield)
    end)
    if not ok then
        return nil, 'Inventory full or could not add items.'
    end

    notify(source, ('Harvested %dx %s.'):format(yield, drug.label .. ' Leaf'), 'success')
    return { drugType = drugType, amount = yield, raw = drug.raw }
end)

-- ═══ STAGE 2: PROCESS (raw → product) ═══

exports.sunset_core:RegisterCallback('sunset:drugs:process', function(source, drugType)
    drugType = tostring(drugType or '')
    local drug = Cfg.drugs[drugType]
    if not drug then return nil, 'Unknown drug type.' end

    local now = GetGameTimer()
    if ProcessCooldowns[source] and now - ProcessCooldowns[source] < 5000 then
        return nil, 'Wait a moment before processing again.'
    end

    -- Check proximity to a lab
    local nearLab = false
    pcall(function()
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            for _, lab in ipairs(Cfg.process.labs or {}) do
                if #(coords - lab) < 10.0 then
                    nearLab = true
                    break
                end
            end
        end
    end)
    if not nearLab then
        return nil, 'You must be at a processing lab.'
    end

    -- Check raw materials
    local ratio = Cfg.process.ratio or 2
    local hasRaw = false
    pcall(function()
        hasRaw = exports.sunset_inventory:HasItem(source, drug.raw, ratio)
    end)
    if not hasRaw then
        return nil, ('You need %dx %s to process.'):format(ratio, drug.label .. ' Leaf')
    end

    ProcessCooldowns[source] = now

    -- Remove raw, add product
    pcall(function()
        exports.sunset_inventory:RemoveItem(source, drug.raw, ratio)
        exports.sunset_inventory:AddItem(source, drug.product, 1)
    end)

    notify(source, ('Processed %dx %s → 1x %s.'):format(ratio, drug.label .. ' Leaf', drug.label .. ' Brick'), 'success')
    return { drugType = drugType, product = drug.product }
end)

-- ═══ STAGE 3: SELL ═══

exports.sunset_core:RegisterCallback('sunset:drugs:sell', function(source, drugType, amount)
    drugType = tostring(drugType or '')
    amount = math.floor(tonumber(amount) or 1)
    local drug = Cfg.drugs[drugType]
    if not drug then return nil, 'Unknown drug type.' end
    if amount < 1 or amount > 50 then return nil, 'Invalid amount.' end

    local now = GetGameTimer()
    if SellCooldowns[source] and now - SellCooldowns[source] < (Cfg.sell.cooldownMs or 10000) then
        return nil, 'The dealer needs a moment. Wait before selling again.'
    end

    -- Check proximity to a dealer
    local nearDealer = false
    pcall(function()
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            for _, dealer in ipairs(Cfg.sell.dealers or {}) do
                if #(coords - dealer) < (Cfg.sell.sellRadius or 5.0) then
                    nearDealer = true
                    break
                end
            end
        end
    end)
    if not nearDealer then
        return nil, 'You must be near a dealer to sell.'
    end

    -- Check inventory
    local hasProduct = false
    pcall(function()
        hasProduct = exports.sunset_inventory:HasItem(source, drug.product, amount)
    end)
    if not hasProduct then
        return nil, ('You don\'t have %dx %s.'):format(amount, drug.label .. ' Brick')
    end

    SellCooldowns[source] = now

    -- Calculate price with variance
    local variance = Cfg.sell.priceVariance or { min = 0.8, max = 1.3 }
    local multiplier = variance.min + math.random() * (variance.max - variance.min)
    local price = math.floor(drug.basePrice * multiplier * amount)

    -- Remove product, add money
    pcall(function()
        exports.sunset_inventory:RemoveItem(source, drug.product, amount)
    end)
    exports.sunset_core:AddMoney(source, 'cash', price, 'drug_sale')

    notify(source, ('Sold %dx %s for $%s.'):format(amount, drug.label .. ' Brick', price), 'success')
    return { drugType = drugType, amount = amount, price = price }
end)

-- ═══ STATUS ═══

exports.sunset_core:RegisterCallback('sunset:drugs:status', function(source)
    local result = {
        drugs = {},
        spots = {},
        labs = {},
        dealers = {},
    }

    for drugType, drug in pairs(Cfg.drugs or {}) do
        local rawCount = 0
        local productCount = 0
        pcall(function()
            rawCount = exports.sunset_inventory:CountItem(source, drug.raw) or 0
            productCount = exports.sunset_inventory:CountItem(source, drug.product) or 0
        end)
        result.drugs[drugType] = {
            label = drug.label,
            raw = drug.raw,
            product = drug.product,
            rawCount = rawCount,
            productCount = productCount,
            basePrice = drug.basePrice,
        }
    end

    -- Check proximity to spots/labs/dealers
    pcall(function()
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            for i, spot in ipairs(Cfg.manufacture.spots or {}) do
                result.spots[i] = #(coords - spot) < 10.0
            end
            for i, lab in ipairs(Cfg.process.labs or {}) do
                result.labs[i] = #(coords - lab) < 10.0
            end
            for i, dealer in ipairs(Cfg.sell.dealers or {}) do
                result.dealers[i] = #(coords - dealer) < (Cfg.sell.sellRadius or 5.0)
            end
        end
    end)

    return result
end)

AddEventHandler('playerDropped', function()
    local src = source
    HarvestCooldowns[src] = nil
    ProcessCooldowns[src] = nil
    SellCooldowns[src] = nil
end)

print('^2[sunset_drugs]^7 Drug pipeline online (manufacture → process → sell)')
