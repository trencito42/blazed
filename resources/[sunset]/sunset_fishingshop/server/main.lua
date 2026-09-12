-- ============================================================
--  sunset_fishingshop  ·  server/main.lua
--  Callbacks: vinde peste la 24/7 + upgrade undita la NPC
-- ============================================================

local FISH_PRICES = {
    fresh_fish     = { min = 30,  max = 60   },
    fish_common    = { min = 40,  max = 80   },
    fish_uncommon  = { min = 90,  max = 150  },
    fish_rare      = { min = 170, max = 280  },
    fish_epic      = { min = 320, max = 550  },
    fish_legendary = { min = 650, max = 1200 },
}

local FISH_LABELS = {
    fresh_fish     = 'Fresh Fish',
    fish_common    = 'Common Fish',
    fish_uncommon  = 'Uncommon Fish',
    fish_rare      = 'Rare Fish',
    fish_epic      = 'Epic Fish',
    fish_legendary = 'Legendary Fish',
}

local BAIT_SHOP_ITEMS = {
    { item = 'bait_worm',    label = 'Worm Bait',    price = 50,  description = '60% catch chance', icon = 'bait_worm'    },
    { item = 'bait_lure',    label = 'Lure Bait',    price = 120, description = '75% catch chance', icon = 'bait_lure'    },
    { item = 'bait_premium', label = 'Premium Bait', price = 250, description = '90% catch chance', icon = 'bait_premium' },
}

local BILLY_RAY_COORDS = vector3(-1593.23, 5207.74, 3.31)
local BILLY_RAY_HIRE_DIST = 3.0

local function getCharCash(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return 0 end
    return tonumber(char.cash) or tonumber(char.money) or 0
end

local function decodeMetadata(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, value = pcall(json.decode, raw)
    return ok and type(value) == 'table' and value or nil
end

local function fishUnitValue(fishItem, metadata)
    local range = FISH_PRICES[fishItem]
    local cap = range and range.max or 0
    local meta = decodeMetadata(metadata)
    if meta then
        local value = tonumber(meta.value)
        if value and value > 0 then
            -- [AUDIT P2-09] Clamp to the configured price range: metadata travels
            -- through trades verbatim, so an attacker-influenced value must never
            -- pay above the legitimate maximum.
            return math.min(math.floor(value), cap)
        end
        local kg = tonumber(meta.fishKg)
        if kg and kg > 0 then return math.min(math.floor(kg * 10), cap) end
    end
    if not range then return 0 end
    return math.floor((range.min + range.max) / 2)
end

-- [AUDIT P2-09] Fish sale proximity: must be at a 24/7 store (or Billy Ray).
local FISH_SELL_DIST = 12.0
local function nearFishBuyer(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    if #(pos - BILLY_RAY_COORDS) <= FISH_SELL_DIST then return true end
    for _, store in ipairs(Sunset.TwentyFourSevenStores or {}) do
        if #(pos - store.coords) <= FISH_SELL_DIST then return true end
    end
    return false
end

local function nearBillyRay(source, maxDist)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - BILLY_RAY_COORDS) <= (maxDist or BILLY_RAY_HIRE_DIST)
end

exports.sunset_core:RegisterCallback('sunset:fishingshop:getBillyRayMenu', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Character not found.' end
    local job, grade = Sunset.GetCharacterJob(char)
    return { job = job or 'unemployed', job_grade = grade or 0 }
end)

exports.sunset_core:RegisterCallback('sunset:fishingshop:hireFisherman', function(source)
    if not nearBillyRay(source) then
        return nil, 'You need to be near Billy Ray.'
    end
    if GetResourceState('sunset_jobs') ~= 'started' then
        return nil, 'The job system is currently unavailable.'
    end
    local hres = exports.sunset_jobs:HireCivilianJob(source, 'fisherman')
    if type(hres) == 'table' and hres.ok then
        return true
    end
    local err = type(hres) == 'table' and hres.err
    if type(err) == 'string' and err:find('already work', 1, true) then
        local char = exports.sunset_core:GetCharacter(source)
        if char then
            TriggerClientEvent('sunset:client:updateCharacter', source, {
                job = char.job,
                job_grade = char.job_grade or 0,
            })
        end
        return true, 'already'
    end
    if type(err) == 'string' then
        if err:find('character is not loaded', 1, true) then
            err = 'Character not loaded. Reconnect and reselect your character.'
        elseif err:find('Could not assign', 1, true) then
            err = 'Could not assign job — reconnect or contact staff.'
        elseif err:find('not a valid civilian job', 1, true) then
            err = 'Invalid job. Contact staff.'
        end
    end
    return nil, err or 'Hiring failed. Please try again.'
end)

local ROD_UPGRADES = {
    { requires = nil,             gives = 'fishing_rod_1', cost = 200,  minLevel = 1 },
    { requires = 'fishing_rod_1', gives = 'fishing_rod_2', cost = 500,  minLevel = 2 },
    { requires = 'fishing_rod_2', gives = 'fishing_rod_3', cost = 1200, minLevel = 3 },
    { requires = 'fishing_rod_3', gives = 'fishing_rod_4', cost = 2500, minLevel = 4 },
    { requires = 'fishing_rod_4', gives = 'fishing_rod_5', cost = 5000, minLevel = 5 },
}

-- ── Fetch bait shop items (pentru fishing shop UI) ───────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:getBaitShop', function(source)
    return { items = BAIT_SHOP_ITEMS, cash = getCharCash(source) }
end)

-- ── Fetch fish inventory (pentru sell UI) ─────────────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:getFishInventory', function(source)
    local grouped = {}
    for _, row in ipairs(exports.sunset_inventory:GetInventory(source) or {}) do
        if FISH_PRICES[row.item] then
            local count = math.max(0, tonumber(row.count) or 0)
            if count > 0 then
                local unitValue = fishUnitValue(row.item, row.metadata)
                local bucket = grouped[row.item]
                if not bucket then
                    bucket = {
                        item = row.item,
                        label = FISH_LABELS[row.item] or row.item,
                        icon = row.item,
                        count = 0,
                        totalValue = 0,
                    }
                    grouped[row.item] = bucket
                end
                bucket.count = bucket.count + count
                bucket.totalValue = bucket.totalValue + (unitValue * count)
            end
        end
    end

    local items = {}
    for _, bucket in pairs(grouped) do
        bucket.unitValue = bucket.count > 0 and math.floor(bucket.totalValue / bucket.count) or 0
        items[#items + 1] = bucket
    end
    table.sort(items, function(a, b) return a.item < b.item end)
    return { items = items, cash = getCharCash(source) }
end)

-- ── Cumpara momeala din cos (fishing shop UI) ─────────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:buyCart', function(source, cart)
    if not cart or type(cart) ~= 'table' or #cart == 0 then
        return nil, 'Cart is empty.'
    end
    local priceMap = {}
    for _, b in ipairs(BAIT_SHOP_ITEMS) do priceMap[b.item] = b.price end

    local total = 0
    for _, entry in ipairs(cart) do
        local price = priceMap[entry.item]
        if not price then return nil, 'Item invalid: ' .. tostring(entry.item) end
        local amount = math.max(1, math.min(math.floor(tonumber(entry.amount) or 1), 500))
        total = total + price * amount
    end

    local ok = exports.sunset_core:RemoveMoney(source, 'cash', total, 'bait_shop')
    if not ok then
        return nil, ('Not enough cash. Required: $%d'):format(total)
    end

    for _, entry in ipairs(cart) do
        local amount = math.max(1, math.min(math.floor(tonumber(entry.amount) or 1), 500))
        exports.sunset_inventory:AddItem(source, entry.item, amount)
    end
    return { total = total }
end)

-- ── Vinde peste selectat din cos (fishing shop UI) ────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:sellCart', function(source, cart)
    if not nearFishBuyer(source) then
        return nil, 'You need to be at a 24/7 store or Billy Ray to sell fish.'
    end
    if not cart or type(cart) ~= 'table' or #cart == 0 then
        return nil, 'Sell cart is empty.'
    end
    local total = 0
    local sold  = {}
    for _, entry in ipairs(cart) do
        local fishItem = entry.item
        if not FISH_PRICES[fishItem] then return nil, 'Item invalid: ' .. tostring(fishItem) end
        local inInv = exports.sunset_inventory:CountItem(source, fishItem) or 0
        local amount = math.max(1, math.min(math.floor(tonumber(entry.amount) or 1), inInv))
        if amount <= 0 then return nil, ('Not enough %s in inventory.'):format(FISH_LABELS[fishItem] or fishItem) end

        local actuallyRemoved = 0
        local earned = 0
        for _ = 1, amount do
            local inv = exports.sunset_inventory:GetInventory(source) or {}
            local row
            for _, candidate in ipairs(inv) do
                if candidate.item == fishItem and (tonumber(candidate.count) or 0) > 0 then
                    row = candidate
                    break
                end
            end
            if not row then break end

            local value = fishUnitValue(fishItem, row.metadata)
            if exports.sunset_inventory:RemoveItem(source, fishItem, 1) then
                actuallyRemoved = actuallyRemoved + 1
                earned = earned + value
            else
                break
            end
        end
        if actuallyRemoved == 0 then return nil, ('No %s found in inventory.'):format(FISH_LABELS[fishItem] or fishItem) end
        total = total + earned
        sold[#sold + 1] = ('%dx %s = $%d'):format(actuallyRemoved, FISH_LABELS[fishItem] or fishItem, earned)
    end
    if total == 0 then return nil, 'Nothing sold.' end
    exports.sunset_core:AddMoney(source, 'cash', total, 'fish_sell_247')
    if GetResourceState('sunset_businesses') == 'started' then
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            exports.sunset_businesses:RecordSaleAtCoords(GetEntityCoords(ped), 'shop', total, 'twentyfour7')
        end
    end
    return ('Sold! +$%d (%s)'):format(total, table.concat(sold, ', '))
end)

-- ── Vinde tot pestele la 24/7 (legacy — pastrat pentru compatibilitate) ──
exports.sunset_core:RegisterCallback('sunset:fishingshop:sellFish247', function(source)
    if not nearFishBuyer(source) then
        return nil, 'You need to be at a 24/7 store or Billy Ray to sell fish.'
    end
    local total = 0
    local sold  = {}

    for fishItem, priceRange in pairs(FISH_PRICES) do
        local count = exports.sunset_inventory:CountItem(source, fishItem) or 0
        if count > 0 then
            local value  = math.random(priceRange.min, priceRange.max)
            local removed = 0
            for _ = 1, count do
                if exports.sunset_inventory:RemoveItem(source, fishItem, 1) then removed = removed + 1 else break end
            end
            if removed > 0 then
                local earned = value * removed
                total = total + earned
                local name = fishItem:gsub('fish_', ''):gsub('^%l', string.upper)
                sold[#sold + 1] = ('%dx %s = $%d'):format(removed, name, earned)
            end
        end
    end

    if total == 0 then
        return nil, 'You have no fish in your inventory.'
    end

    exports.sunset_core:AddMoney(source, 'cash', total, 'fish_sell_legacy')
    if GetResourceState('sunset_businesses') == 'started' then
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            exports.sunset_businesses:RecordSaleAtCoords(GetEntityCoords(ped), 'shop', total, 'twentyfour7')
        end
    end
    return ('Fish sold! +$%d cash (%s)'):format(total, table.concat(sold, ', '))
end)

-- ── Upgrade undita la Billy Ray ───────────────────────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:upgradeRod', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Character not found.' end

    local fishLevel = tonumber(MySQL.scalar.await(
        'SELECT level FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'fisherman' }
    )) or 1  -- default nivel 1 daca nu exista inregistrare

    -- Ce undita are jucatorul acum (cea mai buna)
    local currentRod = nil
    for _, tier in ipairs({ 'fishing_rod_5', 'fishing_rod_4', 'fishing_rod_3', 'fishing_rod_2', 'fishing_rod_1' }) do
        if (exports.sunset_inventory:CountItem(source, tier) or 0) > 0 then
            currentRod = tier
            break
        end
    end

    -- Gaseste next upgrade
    local upgrade = nil
    for _, u in ipairs(ROD_UPGRADES) do
        if u.requires == currentRod then
            upgrade = u
            break
        end
    end

    if not upgrade then
        return nil, 'You already have the maximum rod (Mk5)!'
    end

    if fishLevel < upgrade.minLevel then
        return nil, ('You need Fisherman level %d to upgrade. (current level: %d)'):format(upgrade.minLevel, fishLevel)
    end

    local ok = exports.sunset_core:RemoveMoney(source, 'cash', upgrade.cost, 'rod_upgrade')
    if not ok then
        return nil, ('Not enough cash. Upgrade cost: $%d'):format(upgrade.cost)
    end

    if upgrade.requires then
        exports.sunset_inventory:RemoveItem(source, upgrade.requires, 1)
    end
    exports.sunset_inventory:AddItem(source, upgrade.gives, 1)

    local mk = upgrade.gives:gsub('fishing_rod_', 'Mk')
    return ('Rod upgraded to %s! (-$%d)'):format(mk, upgrade.cost)
end)
