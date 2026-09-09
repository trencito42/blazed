-- ============================================================
--  sunset_carjack  ·  server/main.lua
--  Handles lockpick attempt + chop-shop sale
-- ============================================================

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

-- Lockpick skill level for a player (stored in job_progress as job_id = 'lockpicking')
local function getLockpickLevel(source)
    local char = getChar(source)
    if not char then return 1 end
    local row = MySQL.single.await(
        'SELECT level FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'lockpicking' }
    )
    return (row and tonumber(row.level)) or 1
end

-- Add XP to lockpicking skill
local function addLockpickXP(source, amount)
    local char = getChar(source)
    if not char then return end
    local row = MySQL.single.await(
        'SELECT xp, level FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, 'lockpicking' }
    )
    local xp    = ((row and row.xp)    or 0) + amount
    local level = ((row and row.level) or 1)
    local function xpForLevel(l) return math.max(100, l * 100) end
    while xp >= xpForLevel(level) do
        xp = xp - xpForLevel(level)
        level = level + 1
    end
    if row then
        MySQL.update.await(
            'UPDATE job_progress SET xp = ?, level = ? WHERE character_id = ? AND job_id = ?',
            { xp, level, char.id, 'lockpicking' }
        )
    else
        MySQL.insert.await(
            'INSERT INTO job_progress (character_id, job_id, xp, level, completed_tasks, total_earned) VALUES (?, ?, ?, ?, 0, 0)',
            { char.id, 'lockpicking', xp, level }
        )
    end
end

-- ── Lockpick attempt ────────────────────────────────────────
exports.sunset_core:RegisterCallback('sunset:carjack:tryLockpick', function(source)
    local char = getChar(source)
    if not char then return false, 'Character not loaded.' end

    -- Need lockpick in inventory
    local hasItem = exports.sunset_inventory:HasItem(source, 'lockpick', 1)
    if not hasItem then return false, 'You need a lockpick.' end

    -- Consume lockpick regardless of outcome (single use)
    exports.sunset_inventory:RemoveItem(source, 'lockpick', 1)

    -- Success chance: 35% base + 5% per level, max 95%
    local level   = getLockpickLevel(source)
    local chance  = math.min(95, 35 + (level - 1) * 5)
    local success = math.random(1, 100) <= chance

    if success then
        addLockpickXP(source, 30)
        return true
    else
        -- Small XP on fail so players still progress
        addLockpickXP(source, 8)
        return false, ('Lockpick broke! (%.0f%% chance — level up Lockpicking to improve)'):format(chance)
    end
end)

-- ── Chop-shop sale ──────────────────────────────────────────
-- Vehicle payout: 18% of dealership price, or $600-$1800 for unlisted cars
local function getVehiclePrice(model)
    local row = MySQL.single.await(
        'SELECT price FROM dealership_vehicles WHERE model = ? AND available = 1 LIMIT 1',
        { tostring(model):lower() }
    )
    if row and tonumber(row.price) and tonumber(row.price) > 0 then
        return math.floor(tonumber(row.price) * 0.18)
    end
    -- Unlisted / random spawn: fixed range based on hash parity (feels random but consistent per model)
    local hash = joaat and joaat(tostring(model)) or 0
    return 600 + (hash % 1201) -- $600 – $1800
end

exports.sunset_core:RegisterCallback('sunset:carjack:sell', function(source, data)
    local char = getChar(source)
    if not char then return false, 'Character not loaded.' end

    local model  = tostring(type(data) == 'table' and data.model or ''):lower()
    local netId  = tonumber(type(data) == 'table' and data.netId)
    if model == '' or not netId then return false, 'Invalid vehicle data.' end

    local payout = getVehiclePrice(model)
    exports.sunset_core:AddMoney(source, 'cash', payout, 'carjack_sale')

    -- Give some lockpicking XP for a successful delivery
    addLockpickXP(source, 50)

    -- Log it
    print(('[carjack] %s sold %s for $%d'):format(GetPlayerName(source), model, payout))

    return true, payout
end)
