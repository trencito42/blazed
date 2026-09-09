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

local ROD_UPGRADES = {
    { requires = nil,             gives = 'fishing_rod_1', cost = 200,  minLevel = 1 },
    { requires = 'fishing_rod_1', gives = 'fishing_rod_2', cost = 500,  minLevel = 2 },
    { requires = 'fishing_rod_2', gives = 'fishing_rod_3', cost = 1200, minLevel = 3 },
    { requires = 'fishing_rod_3', gives = 'fishing_rod_4', cost = 2500, minLevel = 4 },
    { requires = 'fishing_rod_4', gives = 'fishing_rod_5', cost = 5000, minLevel = 5 },
}

-- ── Vinde tot pestele la 24/7 ────────────────────────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:sellFish247', function(source)
    local total = 0
    local sold  = {}

    for fishItem, priceRange in pairs(FISH_PRICES) do
        local count = exports.sunset_inventory:CountItem(source, fishItem) or 0
        if count > 0 then
            local value  = math.random(priceRange.min, priceRange.max)
            local earned = value * count
            total = total + earned
            local name = fishItem:gsub('fish_', ''):gsub('^%l', string.upper)
            sold[#sold + 1] = ('%dx %s = $%d'):format(count, name, earned)
            exports.sunset_inventory:RemoveItem(source, fishItem, count)
        end
    end

    if total == 0 then
        return nil, 'Nu ai niciun peste in inventar.'
    end

    exports.sunset_core:AddMoney(source, total)
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

    local ok = exports.sunset_core:RemoveMoney(source, upgrade.cost)
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
