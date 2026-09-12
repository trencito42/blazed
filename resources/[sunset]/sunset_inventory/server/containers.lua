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

-- [AUDIT P2-05] Access validation: trunk/glovebox/property containers used to accept
-- ANY containerType/containerId from the client, allowing remote looting of other
-- players' trunks/houses by iterating plates. Now every callback proves physical
-- access: the vehicle with that plate must exist server-side within range (or the
-- caller must be inside it); property safes require owner/active-renter status.
local VEHICLE_CONTAINER_DIST = 6.0

local function findVehicleByPlate(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        local vPlate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', ''):upper()
        if vPlate == plate then return veh end
    end
    return nil
end

local function canAccessContainer(source, containerType, containerId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false, 'Character not loaded.' end

    if containerType == 'trunk' or containerType == 'glovebox' then
        local ped = GetPlayerPed(source)
        if not ped or ped == 0 then return false, 'Your character is not in the world.' end
        local veh = findVehicleByPlate(containerId)
        if not veh then return false, 'The vehicle is not near you.' end
        -- Inside this vehicle, or standing next to it
        if GetVehiclePedIsIn(ped, false) == veh then return true end
        if #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= VEHICLE_CONTAINER_DIST then return true end
        return false, 'You are too far from the vehicle.'
    elseif containerType == 'property' then
        local propId = tonumber(containerId)
        if not propId then return false, 'Invalid container identifier' end
        local allowed = MySQL.scalar.await([[
            SELECT 1 FROM properties
            WHERE id = ? AND owner_character_id = ?
            UNION
            SELECT 1 FROM property_rentals
            WHERE property_id = ? AND character_id = ? AND active = 1
            LIMIT 1
        ]], { propId, char.id, propId, char.id })
        if allowed then return true end
        return false, 'You do not have access to this property.'
    end

    return false, 'Unknown container type'
end

-- Callbacks
exports.sunset_core:RegisterCallback('sunset:container:open', function(source, containerType, containerId)
    if not CAPACITY_LIMITS[containerType] then return nil, 'Unknown container type' end
    containerId = tostring(containerId or ''):upper():gsub('%s+', '')
    if containerId == '' then return nil, 'Invalid container identifier' end
    if not exports.sunset_core:RateLimit(source, 'container:' .. containerType, 500) then return nil end

    local accessOk, accessErr = canAccessContainer(source, containerType, containerId)
    if not accessOk then return nil, accessErr end

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
    if count < 1 then return nil, 'Invalid amount' end
    containerId = tostring(containerId or ''):upper():gsub('%s+', '')
    if not CAPACITY_LIMITS[containerType] or containerId == '' then return nil, 'Invalid container identifier' end
    if not exports.sunset_core:RateLimit(source, 'container:' .. containerType, 500) then return nil end

    local accessOk, accessErr = canAccessContainer(source, containerType, containerId)
    if not accessOk then return nil, accessErr end

    if type(item) ~= 'string' or not Sunset.Items[item] then return nil, 'Invalid item' end

    if not exports.sunset_inventory:HasItem(source, item, count) then
        return nil, 'You do not have that item in your inventory.'
    end

    -- [AUDIT P5-03] Remove from the player FIRST and verify success before the
    -- container is credited. The old order duplicated items whenever RemoveItem
    -- failed (trade lock, concurrent consume race) because its result was ignored.
    -- [AUDIT P5-12] Preserve item metadata (stolen flags, gas can liters) on
    -- deposit so containers cannot be used to launder metadata.
    local meta
    for _, row in ipairs(exports.sunset_inventory:GetInventory(source) or {}) do
        if row.item == item and row.metadata and next(row.metadata) then
            meta = row.metadata
            break
        end
    end
    if not exports.sunset_inventory:RemoveItem(source, item, count) then
        return nil, 'The item could not be moved out of your inventory.'
    end

    local ok, err = SunsetContainers.AddItem(containerType, containerId, item, count, meta)
    if not ok then
        -- rollback: give the items back
        exports.sunset_inventory:AddItem(source, item, count, nil, meta)
        return nil, err
    end

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
    if count < 1 then return nil, 'Invalid amount' end
    containerId = tostring(containerId or ''):upper():gsub('%s+', '')
    if not CAPACITY_LIMITS[containerType] or containerId == '' then return nil, 'Invalid container identifier' end
    if not exports.sunset_core:RateLimit(source, 'container:' .. containerType, 500) then return nil end

    local accessOk, accessErr = canAccessContainer(source, containerType, containerId)
    if not accessOk then return nil, accessErr end

    -- [AUDIT P5-12] Preserve item metadata (gas can liters, robbery/stolen data)
    -- across withdraw; it used to be silently stripped.
    local meta
    for _, row in ipairs(SunsetContainers.GetItems(containerType, containerId)) do
        if row.item == item and row.metadata and next(row.metadata or {}) then
            meta = row.metadata
            break
        end
    end

    local ok, err = SunsetContainers.RemoveItem(containerType, containerId, item, count)
    if not ok then return nil, err end

    if not exports.sunset_inventory:AddItem(source, item, count, nil, meta) then
        -- rollback if player inventory full
        SunsetContainers.AddItem(containerType, containerId, item, count, meta)
        return nil, 'Your inventory is full.'
    end

    local updated = SunsetContainers.GetItems(containerType, containerId)
    return {
        ok = true,
        items = updated,
        weight = calcContainerWeight(updated),
        maxWeight = CAPACITY_LIMITS[containerType],
    }
end)
