local Inventories = {}

local function getItemWeight(item, count)
    local def = Sunset.Items[item]
    if not def then return 0 end
    return (def.weight or 0) * (count or 1)
end

local function calcWeight(items)
    local total = 0
    for _, row in ipairs(items) do
        total = total + getItemWeight(row.item, row.count)
    end
    return total
end

local function loadInventory(characterId)
    local rows = MySQL.query.await(
        'SELECT id, item, count, slot, metadata FROM character_inventory WHERE character_id = ? ORDER BY slot',
        { characterId }
    ) or {}
    for _, row in ipairs(rows) do
        if row.metadata and type(row.metadata) == 'string' then
            row.metadata = json.decode(row.metadata)
        end
    end
    Inventories[characterId] = rows
    return rows
end

function GetInventory(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    if not Inventories[char.id] then loadInventory(char.id) end
    return Inventories[char.id]
end

function AddItem(source, item, count, slot)
    local char = exports.sunset_core:GetCharacter(source)
    if not char or not Sunset.Items[item] then return false end
    count = math.floor(count or 1)
    if count < 1 then return false end

    local inv = GetInventory(source)
    local newWeight = calcWeight(inv) + getItemWeight(item, count)
    if newWeight > Sunset.Config.MaxWeight then return false end

    for _, row in ipairs(inv) do
        if row.item == item and (not slot or row.slot == slot) then
            row.count = row.count + count
            MySQL.update.await('UPDATE character_inventory SET count = ? WHERE id = ?', { row.count, row.id })
            TriggerClientEvent('sunset:client:inventoryUpdate', source, inv, calcWeight(inv))
            return true
        end
    end

    local freeSlot = slot
    if not freeSlot then
        local used = {}
        for _, row in ipairs(inv) do used[row.slot] = true end
        for i = 1, Sunset.Config.MaxSlots do
            if not used[i] then freeSlot = i break end
        end
    end
    if not freeSlot then return false end

    local id = MySQL.insert.await(
        'INSERT INTO character_inventory (character_id, item, count, slot) VALUES (?, ?, ?, ?)',
        { char.id, item, count, freeSlot }
    )
    inv[#inv + 1] = { id = id, item = item, count = count, slot = freeSlot, metadata = nil }
    TriggerClientEvent('sunset:client:inventoryUpdate', source, inv, calcWeight(inv))
    return true
end

function RemoveItem(source, item, count)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end
    count = math.floor(count or 1)
    local inv = GetInventory(source)

    for i, row in ipairs(inv) do
        if row.item == item then
            if row.count < count then return false end
            row.count = row.count - count
            if row.count <= 0 then
                MySQL.update.await('DELETE FROM character_inventory WHERE id = ?', { row.id })
                table.remove(inv, i)
            else
                MySQL.update.await('UPDATE character_inventory SET count = ? WHERE id = ?', { row.count, row.id })
            end
            TriggerClientEvent('sunset:client:inventoryUpdate', source, inv, calcWeight(inv))
            return true
        end
    end
    return false
end

function HasItem(source, item, count)
    count = count or 1
    local inv = GetInventory(source)
    for _, row in ipairs(inv) do
        if row.item == item and row.count >= count then return true end
    end
    return false
end

function UseItem(source, item)
    local def = Sunset.Items[item]
    if not def or not def.usable then return false end
    if not RemoveItem(source, item, 1) then return false end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end

    if def.hunger then char.hunger = math.min(100, (char.hunger or 100) + def.hunger) end
    if def.thirst then char.thirst = math.min(100, (char.thirst or 100) + def.thirst) end
    if def.stress then char.stress = math.max(0, math.min(100, (char.stress or 0) + def.stress)) end
    if def.heal then
        TriggerClientEvent('sunset:client:heal', source, def.heal)
    end

    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

exports('GetInventory', GetInventory)
exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('HasItem', HasItem)
exports('UseItem', UseItem)

exports.sunset_core:RegisterCallback('sunset:getInventory', function(source)
    local inv = GetInventory(source)
    return { items = inv, weight = calcWeight(inv), maxWeight = Sunset.Config.MaxWeight }
end)

exports.sunset_core:RegisterCallback('sunset:useItem', function(source, item)
    if UseItem(source, item) then return true end
    return nil, 'Cannot use item'
end)

AddEventHandler('sunset:server:characterSelected', function(source, charId)
    loadInventory(charId)
end)

RegisterNetEvent('sunset:server:inventoryLoaded', function()
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end
    local inv = loadInventory(char.id)
    TriggerClientEvent('sunset:client:inventoryUpdate', source, inv, calcWeight(inv))
end)

AddEventHandler('playerDropped', function()
    local char = exports.sunset_core:GetCharacter(source)
    if char then Inventories[char.id] = nil end
end)
