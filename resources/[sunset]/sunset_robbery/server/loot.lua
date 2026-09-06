RobberyLoot = {}

local function weightedPick(pool)
    local total = 0
    for _, row in ipairs(pool) do
        total = total + (tonumber(row.rarity) or 1)
    end
    if total <= 0 then return pool[1] end
    local roll = math.random() * total
    local acc = 0
    for _, row in ipairs(pool) do
        acc = acc + (tonumber(row.rarity) or 1)
        if roll <= acc then return row end
    end
    return pool[#pool]
end

function RobberyLoot.generateDisplay(tableId, count)
    local pool = SunsetRobbery.LootTables[tableId] or SunsetRobbery.LootTables.watches
    local items = {}
    local used = {}
    count = math.max(1, math.min(12, tonumber(count) or 6))
    for i = 1, count do
        local pick = weightedPick(pool)
        local uid = ('%s_%d_%d'):format(pick.id, i, math.random(1000, 9999))
        items[#items + 1] = {
            uid = uid,
            item = pick.id,
            label = pick.label,
            tier = pick.tier,
            weight = pick.weight or 1,
            baseValue = pick.baseValue or 500,
            family = pick.family or 'watch',
            taken = false,
            skill = pick.tier == 'EPIC' or pick.tier == 'VERY_RARE',
        }
        used[uid] = true
    end
    return items
end

function RobberyLoot.offerFor(item)
    local family = item.family or 'watch'
    local demand = (SunsetRobbery.Fence.demand or {})[family] or 1.0
    local variance = SunsetRobbery.SellVariance or { min = 0.75, max = 0.85 }
    local factor = variance.min + (math.random() * (variance.max - variance.min))
    local street = math.floor((item.baseValue or 500) * (0.92 + math.random() * 0.16))
    local offer = math.max(50, math.floor(street * factor * demand))
    return street, offer
end
