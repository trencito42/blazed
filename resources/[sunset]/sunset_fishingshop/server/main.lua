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

local function nearBillyRay(source, maxDist)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - BILLY_RAY_COORDS) <= (maxDist or BILLY_RAY_HIRE_DIST)
end

exports.sunset_core:RegisterCallback('sunset:fishingshop:getBillyRayMenu', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Personaj negasit.' end
    local job, grade = Sunset.GetCharacterJob(char)
    return { job = job or 'unemployed', job_grade = grade or 0 }
end)

exports.sunset_core:RegisterCallback('sunset:fishingshop:hireFisherman', function(source)
    if not nearBillyRay(source) then
        return nil, 'Trebuie sa fii langa Billy Ray.'
    end
    if GetResourceState('sunset_jobs') ~= 'started' then
        return nil, 'Sistemul de joburi nu este disponibil.'
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
            err = 'Personajul nu e incarcat. Reconecteaza-te si selecteaza-l din nou.'
        elseif err:find('Could not assign', 1, true) then
            err = 'Nu am putut seta jobul — reconecteaza-te sau contacteaza staff.'
        elseif err:find('not a valid civilian job', 1, true) then
            err = 'Job invalid. Contacteaza staff.'
        end
    end
    return nil, err or 'Angajarea a esuat. Incearca din nou.'
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
    local items = {}
    for fishItem, priceRange in pairs(FISH_PRICES) do
        local count = exports.sunset_inventory:CountItem(source, fishItem) or 0
        if count > 0 then
            local midValue = math.floor((priceRange.min + priceRange.max) / 2)
            items[#items + 1] = {
                item       = fishItem,
                label      = FISH_LABELS[fishItem] or fishItem,
                icon       = fishItem,
                count      = count,
                unitValue  = midValue,
                totalValue = midValue * count,
            }
        end
    end
    return { items = items, cash = getCharCash(source) }
end)

-- ── Cumpara momeala din cos (fishing shop UI) ─────────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:buyCart', function(source, cart)
    if not cart or type(cart) ~= 'table' or #cart == 0 then
        return nil, 'Cos gol.'
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
        return nil, ('Nu ai destui bani. Necesar: $%d'):format(total)
    end

    for _, entry in ipairs(cart) do
        local amount = math.max(1, math.min(math.floor(tonumber(entry.amount) or 1), 500))
        exports.sunset_inventory:AddItem(source, entry.item, amount)
    end
    return { total = total }
end)

-- ── Vinde peste selectat din cos (fishing shop UI) ────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:sellCart', function(source, cart)
    if not cart or type(cart) ~= 'table' or #cart == 0 then
        return nil, 'Cos de vanzare gol.'
    end
    local total = 0
    local sold  = {}
    for _, entry in ipairs(cart) do
        local fishItem = entry.item
        if not FISH_PRICES[fishItem] then return nil, 'Item invalid: ' .. tostring(fishItem) end
        local inInv = exports.sunset_inventory:CountItem(source, fishItem) or 0
        local amount = math.max(1, math.min(math.floor(tonumber(entry.amount) or 1), inInv))
        if amount <= 0 then return nil, ('Nu ai destui %s.'):format(FISH_LABELS[fishItem] or fishItem) end
        local value = math.floor((FISH_PRICES[fishItem].min + FISH_PRICES[fishItem].max) / 2)
        -- Remove one at a time to handle fish split across multiple inventory rows
        local actuallyRemoved = 0
        for _ = 1, amount do
            if exports.sunset_inventory:RemoveItem(source, fishItem, 1) then
                actuallyRemoved = actuallyRemoved + 1
            else
                break
            end
        end
        if actuallyRemoved == 0 then return nil, ('Nu ai %s in inventar.'):format(FISH_LABELS[fishItem] or fishItem) end
        local earned = value * actuallyRemoved
        total = total + earned
        sold[#sold + 1] = ('%dx %s = $%d'):format(actuallyRemoved, FISH_LABELS[fishItem] or fishItem, earned)
    end
    if total == 0 then return nil, 'Nimic vandut.' end
    exports.sunset_core:AddMoney(source, 'cash', total, 'fish_sell_247')
    return ('Vandut! +$%d (%s)'):format(total, table.concat(sold, ', '))
end)

-- ── Vinde tot pestele la 24/7 (legacy — pastrat pentru compatibilitate) ──
exports.sunset_core:RegisterCallback('sunset:fishingshop:sellFish247', function(source)
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
        return nil, 'Nu ai niciun peste in inventar.'
    end

    exports.sunset_core:AddMoney(source, 'cash', total, 'fish_sell_legacy')
    return ('Ai vandut pestele! +$%d cash (%s)'):format(total, table.concat(sold, ', '))
end)

-- ── Upgrade undita la Billy Ray ───────────────────────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:upgradeRod', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Personaj negasit.' end

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
        return nil, 'Ai deja undita maxima (Mk5)!'
    end

    if fishLevel < upgrade.minLevel then
        return nil, ('Ai nevoie de Fisherman nivel %d. (nivel actual: %d)'):format(upgrade.minLevel, fishLevel)
    end

    local ok = exports.sunset_core:RemoveMoney(source, 'cash', upgrade.cost, 'rod_upgrade')
    if not ok then
        return nil, ('Nu ai destui bani. Cost upgrade: $%d'):format(upgrade.cost)
    end

    if upgrade.requires then
        exports.sunset_inventory:RemoveItem(source, upgrade.requires, 1)
    end
    exports.sunset_inventory:AddItem(source, upgrade.gives, 1)

    local mk = upgrade.gives:gsub('fishing_rod_', 'Mk')
    return ('Undita upgradata la %s! (-$%d)'):format(mk, upgrade.cost)
end)
