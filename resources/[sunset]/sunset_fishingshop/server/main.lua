-- ============================================================
--  sunset_fishingshop  ·  server/main.lua
--  Callbacks: vinde peste la 24/7 + upgrade undita la NPC
-- ============================================================

-- Valorile de vanzare pentru fiecare tip de peste
local FISH_PRICES = {
    fresh_fish    = { min = 30,  max = 60  },  -- legacy
    fish_common   = { min = 40,  max = 80  },
    fish_uncommon = { min = 90,  max = 150 },
    fish_rare     = { min = 170, max = 280 },
    fish_epic     = { min = 320, max = 550 },
    fish_legendary = { min = 650, max = 1200 },
}

-- Upgrade secvential: { requires, gives, cost, minLevel }
local ROD_UPGRADES = {
    { requires = nil,           gives = 'fishing_rod_1', cost = 200,  minLevel = 1 },
    { requires = 'fishing_rod_1', gives = 'fishing_rod_2', cost = 500,  minLevel = 2 },
    { requires = 'fishing_rod_2', gives = 'fishing_rod_3', cost = 1200, minLevel = 3 },
    { requires = 'fishing_rod_3', gives = 'fishing_rod_4', cost = 2500, minLevel = 4 },
    { requires = 'fishing_rod_4', gives = 'fishing_rod_5', cost = 5000, minLevel = 5 },
}

-- ── Sell fish la 24/7 ────────────────────────────────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:sellFish247', function(source, cb)
    local total = 0
    local sold  = {}

    for fishItem, priceRange in pairs(FISH_PRICES) do
        local count = exports.sunset_inventory:CountItem(source, fishItem)
        if count and count > 0 then
            local value = math.random(priceRange.min, priceRange.max)
            local earned = value * count
            total = total + earned
            sold[#sold + 1] = ('%dx %s = $%d'):format(count, fishItem:gsub('_', ' '):gsub('^%l', string.upper), earned)
            exports.sunset_inventory:RemoveItem(source, fishItem, count)
        end
    end

    if total == 0 then
        return cb(false, 'Nu ai niciun peste in inventar.')
    end

    exports.sunset_core:AddMoney(source, total)
    local summary = table.concat(sold, ', ')
    cb(true, ('Ai vandut pestele! +$%d cash (%s)'):format(total, summary))
end)

-- ── Upgrade undita la Billy Ray ───────────────────────────────
exports.sunset_core:RegisterCallback('sunset:fishingshop:upgradeRod', function(source, cb)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return cb(false, 'Eroare: personaj negasit.') end

    -- Nivelul de pescuit
    local fishLevel = tonumber(MySQL.scalar.await(
        'SELECT level FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'fisherman' }
    )) or 1

    -- Determina ce undita are acum jucatorul
    local currentRod = nil
    for _, tier in ipairs({ 'fishing_rod_5', 'fishing_rod_4', 'fishing_rod_3', 'fishing_rod_2', 'fishing_rod_1' }) do
        if exports.sunset_inventory:CountItem(source, tier) > 0 then
            currentRod = tier
            break
        end
    end

    -- Gaseste upgrade-ul potrivit
    local upgrade = nil
    for _, u in ipairs(ROD_UPGRADES) do
        if u.requires == currentRod then
            upgrade = u
            break
        end
    end

    if not upgrade then
        return cb(false, 'Ai deja cea mai buna undita (Mk5)!')
    end

    if fishLevel < upgrade.minLevel then
        return cb(false, ('Ai nevoie de Fisherman nivel %d pentru aceasta undita. (nivel actual: %d)'):format(upgrade.minLevel, fishLevel))
    end

    local money = exports.sunset_core:GetCharacter(source)
    local balance = exports.sunset_economy and exports.sunset_economy.GetMoney
        and exports.sunset_economy.GetMoney(source)
        or (exports.sunset_core:GetCharacter(source) or {}).cash or 0

    -- Verifica bani
    local ok = exports.sunset_core:RemoveMoney(source, upgrade.cost)
    if not ok then
        return cb(false, ('Nu ai destui bani. Cost upgrade: $%d'):format(upgrade.cost))
    end

    -- Scoate undita veche (daca exista) si da undita noua
    if upgrade.requires then
        exports.sunset_inventory:RemoveItem(source, upgrade.requires, 1)
    end
    exports.sunset_inventory:AddItem(source, upgrade.gives, 1)

    local rodName = upgrade.gives:gsub('fishing_rod_', 'Mk')
    cb(true, ('Undita upgradata la %s! (-$%d)'):format(rodName, upgrade.cost))
end)
