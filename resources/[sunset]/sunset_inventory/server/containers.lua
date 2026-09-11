-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Container Storage Engine (Trunk, Glovebox, Property Safe)
-- ═══════════════════════════════════════════════════════════════

SunsetContainers = SunsetContainers or {}

local CAPACITY_LIMITS = {
    trunk = 80.0,     -- 80kg default trunk
    glovebox = 8.0,   -- 8kg glovebox
    property = 250.0, -- 250kg house safe
}

local function getItemWeight(item, count)
    local def = Sunset.Items[item]
    if not def then return 0 end
    return (def.weight or 0) * (count or 1)
end

local function calcContainerWeight(items)
    local total = 0
    for _, row in ipairs(items or {}) do
        total = total + getItemWeight(row.item, row.count)
    end
    return total
end

function SunsetContainers.GetItems(containerType, containerId)
    local rows = MySQL.query.await([[
        SELECT id, item, count, slot, metadata
        FROM container_inventory
        WHERE container_type = ? AND container_id = ?
        ORDER BY slot ASC
    ]], { containerType, containerId }) or {}

    for _, row in ipairs(rows) do
        if row.metadata and type(row.metadata) == 'string' then
            row.metadata = json.decode(row.metadata)
        end
        local def = Sunset.Items[row.item] or {}
        row.label = def.label or row.item
        row.icon = def.icon or 'backpack'
        row.weight = def.weight or 0
    end
    return rows
end

function SunsetContainers.AddItem(containerType, containerId, item, count, metadata)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false, 'Invalid count' end

    local current = SunsetContainers.GetItems(containerType, containerId)
    local maxWeight = CAPACITY_LIMITS[containerType] or 50.0
    local addedWeight = getItemWeight(item, count)

    if calcContainerWeight(current) + addedWeight > maxWeight then
        return false, ('Depozitul este plin (limita: %.1fkg).'):format(maxWeight)
    end

    local existing = nil
    for _, row in ipairs(current) do
        if row.item == item then existing = row break end
    end

    if existing then
        MySQL.update.await(
            'UPDATE container_inventory SET count = count + ? WHERE id = ?',
            { count, existing.id }
        )
    else
        local slot = #current + 1
        local metaJson = metadata and json.encode(metadata) or nil
        MySQL.insert.await(
            'INSERT INTO container_inventory (container_type, container_id, item, count, slot, metadata) VALUES (?, ?, ?, ?, ?, ?)',
            { containerType, containerId, item, count, slot, metaJson }
        )
    end
    return true
end

function SunsetContainers.RemoveItem(containerType, containerId, item, count)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false end

    local current = SunsetContainers.GetItems(containerType, containerId)
    local target = nil
    for _, row in ipairs(current) do
        if row.item == item then target = row break end
    end

    if not target or target.count < count then return false, 'Nu sunt suficiente obiecte.' end

    if target.count <= count then
        MySQL.query.await('DELETE FROM container_inventory WHERE id = ?', { target.id })
    else
        MySQL.update.await('UPDATE container_inventory SET count = count - ? WHERE id = ?', { count, target.id })
    end
    return true
end

-- Callbacks
exports.sunset_core:RegisterCallback('sunset:container:open', function(source, containerType, containerId)
    if not CAPACITY_LIMITS[containerType] then return nil, 'Tip necunoscut' end
    containerId = tostring(containerId or ''):upper():gsub('%s+', '')
    if containerId == '' then return nil, 'Identificator invalid' end

    local items = SunsetContainers.GetItems(containerType, containerId)
    local curWeight = calcContainerWeight(items)
    local maxWeight = CAPACITY_LIMITS[containerType]

    return {
        type = containerType,
        id = containerId,
        items = items,
        weight = curWeight,
        maxWeight = maxWeight,
    }
end)

exports.sunset_core:RegisterCallback('sunset:container:deposit', function(source, containerType, containerId, item, count)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return nil, 'Cantitate invalida' end
    containerId = tostring(containerId or ''):upper():gsub('%s+', '')

    if not exports.sunset_inventory:HasItem(source, item, count) then
        return nil, 'Nu ai obiectul in inventar.'
    end

    local ok, err = SunsetContainers.AddItem(containerType, containerId, item, count)
    if not ok then return nil, err end

    exports.sunset_inventory:RemoveItem(source, item, count)

    local updated = SunsetContainers.GetItems(containerType, containerId)
    return {
        ok = true,
        items = updated,
        weight = calcContainerWeight(updated),
        maxWeight = CAPACITY_LIMITS[containerType],
    }
end)

exports.sunset_core:RegisterCallback('sunset:container:withdraw', function(source, containerType, containerId, item, count)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return nil, 'Cantitate invalida' end
    containerId = tostring(containerId or ''):upper():gsub('%s+', '')

    local ok, err = SunsetContainers.RemoveItem(containerType, containerId, item, count)
    if not ok then return nil, err end

    if not exports.sunset_inventory:AddItem(source, item, count) then
        -- rollback if player inventory full
        SunsetContainers.AddItem(containerType, containerId, item, count)
        return nil, 'Inventarul tau este plin.'
    end

    local updated = SunsetContainers.GetItems(containerType, containerId)
    return {
        ok = true,
        items = updated,
        weight = calcContainerWeight(updated),
        maxWeight = CAPACITY_LIMITS[containerType],
    }
end)
