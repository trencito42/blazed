local Inventories = {}
local LICENSE_EXEMPT_WEAPONS = {
    WEAPON_UNARMED = true, WEAPON_KNIFE = true, WEAPON_SWITCHBLADE = true,
    WEAPON_BAT = true, WEAPON_CROWBAR = true, WEAPON_FLASHLIGHT = true,
    WEAPON_NIGHTSTICK = true, WEAPON_HAMMER = true, WEAPON_GOLFCLUB = true,
    WEAPON_BOTTLE = true, WEAPON_DAGGER = true, WEAPON_HATCHET = true,
    WEAPON_KNUCKLE = true, WEAPON_MACHETE = true, WEAPON_WRENCH = true,
    WEAPON_POOLCUE = true, WEAPON_BATTLEAXE = true, WEAPON_STONE_HATCHET = true,
    WEAPON_FIREEXTINGUISHER = true, WEAPON_PETROLCAN = true, WEAPON_HAZARDCAN = true,
    WEAPON_FERTILIZERCAN = true, WEAPON_BALL = true, WEAPON_SNOWBALL = true,
    GADGET_PARACHUTE = true,
}

local function emitClient(eventName, target, ...)
    target = tonumber(target)
    if type(eventName) ~= 'string' or eventName == '' or not target or target < 1 then return false end
    TriggerClientEvent(eventName, target, ...)
    return true
end

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

local function inventoryView(items)
    local view = {}
    for _, row in ipairs(items or {}) do
        local def = Sunset.Items[row.item] or {}
        view[#view + 1] = {
            id = row.id,
            item = row.item,
            count = row.count,
            slot = row.slot,
            metadata = row.metadata,
            label = def.label or row.item,
            usable = def.usable == true,
            icon = def.icon,
            weight = def.weight or 0,
        }
    end
    return view
end

local function sendInventoryUpdate(source, items)
    local char = exports.sunset_core:GetCharacter(source)
    emitClient('sunset:client:inventoryUpdate', source, inventoryView(items), calcWeight(items), (char and tonumber(char.cash)) or 0)
end

local function ensureStarterItems(characterId)
    local granted = false
    local ok = MySQL.startTransaction(function()
        local row = MySQL.single.await('SELECT metadata FROM characters WHERE id = ? FOR UPDATE', { characterId })
        if not row then error('character_missing') end
        local decodeOk, meta = pcall(json.decode, row.metadata or '{}')
        if not decodeOk or type(meta) ~= 'table' then meta = {} end
        local count = tonumber(MySQL.scalar.await(
            'SELECT COUNT(*) FROM character_inventory WHERE character_id = ? FOR UPDATE', { characterId }
        )) or 0
        if count > 0 or meta.starter_items_granted then return end

        local starter = { { 'water', 2, 1 }, { 'bread', 2, 2 }, { 'id_card', 1, 3 }, { 'phone', 1, 4 } }
        for _, entry in ipairs(starter) do
            MySQL.insert.await(
                'INSERT INTO character_inventory (character_id, item, count, slot) VALUES (?, ?, ?, ?)',
                { characterId, entry[1], entry[2], entry[3] }
            )
        end
        meta.starter_items_granted = true
        MySQL.update.await('UPDATE characters SET metadata = ? WHERE id = ?', { json.encode(meta), characterId })
        granted = true
    end)
    return ok == true and granted
end

local function loadInventory(characterId)
    if ensureStarterItems(characterId) then
        Inventories[characterId] = nil
    end
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

function AddItem(source, item, count, slot, metadata)
    local char = exports.sunset_core:GetCharacter(source)
    if not char or not Sunset.Items[item] then return false end
    local itemDef = Sunset.Items[item]
    local meleeWeapon = itemDef.weapon and LICENSE_EXEMPT_WEAPONS[string.upper(itemDef.weapon)]
    if itemDef.weapon and not meleeWeapon then
        if GetResourceState('sunset_licenses') ~= 'started' then return false end
        local allowed = exports.sunset_licenses:HasLicense(source, 'weapon')
        if not allowed then return false end
    end
    count = math.floor(count or 1)
    if count < 1 then return false end

    local inv = GetInventory(source)
    local newWeight = calcWeight(inv) + getItemWeight(item, count)
    if newWeight > Sunset.Config.MaxWeight then return false end

    if not metadata and item == 'gas_can' then
        metadata = { liters = 0 }
    elseif not metadata and itemDef.weapon then
        -- Weapons are unique inventory objects, never stackable commodities.
        metadata = {
            serial = ('LS-%06d-%06d'):format(tonumber(char.id) or 0, math.random(0, 999999)),
        }
    end

    for _, row in ipairs(inv) do
        if row.item == item and (not slot or row.slot == slot) and not metadata then
            local changed = MySQL.update.await(
                'UPDATE character_inventory SET count = count + ? WHERE id = ? AND character_id = ?',
                { count, row.id, char.id }
            )
            if not changed or changed < 1 then
                loadInventory(char.id)
                return false
            end
            inv = loadInventory(char.id)
            sendInventoryUpdate(source, inv)
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

    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO character_inventory (character_id, item, count, slot, metadata) VALUES (?, ?, ?, ?, ?)',
        { char.id, item, count, freeSlot, metadata and json.encode(metadata) or nil }
    )
    if not ok or not id then
        loadInventory(char.id)
        return false
    end
    inv = loadInventory(char.id)
    sendInventoryUpdate(source, inv)
    return true
end

function RemoveItem(source, item, count)
    if type(IsInventoryTradeLocked) == 'function' and IsInventoryTradeLocked(source) then return false end
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end
    count = math.floor(count or 1)
    local inv = GetInventory(source)

    for i, row in ipairs(inv) do
        if row.item == item then
            if row.count < count then return false end
            local changed = MySQL.update.await(
                'UPDATE character_inventory SET count = count - ? WHERE id = ? AND character_id = ? AND item = ? AND count >= ?',
                { count, row.id, char.id, item, count }
            )
            if not changed or changed < 1 then
                loadInventory(char.id)
                return false
            end
            MySQL.update.await('DELETE FROM character_inventory WHERE id = ? AND character_id = ? AND count <= 0', { row.id, char.id })
            inv = loadInventory(char.id)
            sendInventoryUpdate(source, inv)
            return true
        end
    end
    return false
end

-- Remove one exact persisted row. This is required for metadata-bearing items:
-- removing only by item name can consume a different instance than the one shown.
function RemoveItemById(source, rowId, item, count)
    if type(IsInventoryTradeLocked) == 'function' and IsInventoryTradeLocked(source) then return false end
    local char = exports.sunset_core:GetCharacter(source)
    rowId = tonumber(rowId)
    count = math.floor(tonumber(count) or 1)
    item = tostring(item or '')
    if not char or not rowId or rowId < 1 or count < 1 or item == '' then return false end

    local inv = GetInventory(source)
    local index, row
    for i, entry in ipairs(inv) do
        if tonumber(entry.id) == rowId and entry.item == item then
            index, row = i, entry
            break
        end
    end
    if not row or (tonumber(row.count) or 0) < count then return false end

    local changed = MySQL.update.await(
        'UPDATE character_inventory SET count = count - ? WHERE id = ? AND character_id = ? AND item = ? AND count >= ?',
        { count, rowId, char.id, item, count }
    )
    if not changed or changed < 1 then
        loadInventory(char.id)
        return false
    end

    row.count = row.count - count
    if row.count <= 0 then
        MySQL.update.await('DELETE FROM character_inventory WHERE id = ? AND character_id = ? AND count <= 0', { rowId, char.id })
        table.remove(inv, index)
    end
    sendInventoryUpdate(source, inv)
    return true
end

function RemoveRobberyItems(source, robberyId)
    local char = exports.sunset_core:GetCharacter(source)
    robberyId = tostring(robberyId or '')
    if not char or robberyId == '' then return 0 end
    local inv = GetInventory(source)
    local ids = {}
    for _, row in ipairs(inv) do
        local metadata = row.metadata
        if type(metadata) == 'string' then
            local ok, decoded = pcall(json.decode, metadata)
            metadata = ok and decoded or nil
        end
        if type(metadata) == 'table' and metadata.stolen == true and tostring(metadata.robbery or '') == robberyId then
            ids[#ids + 1] = tonumber(row.id)
        end
    end
    if #ids == 0 then return 0 end

    local removed = 0
    for _, id in ipairs(ids) do
        local changed = MySQL.update.await('DELETE FROM character_inventory WHERE id = ? AND character_id = ?', { id, char.id })
        removed = removed + (tonumber(changed) or 0)
    end
    loadInventory(char.id)
    sendInventoryUpdate(source, Inventories[char.id])
    return removed
end

function ReloadInventory(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end
    local inv = loadInventory(char.id)
    sendInventoryUpdate(source, inv)
    return true
end

function HasItem(source, item, count)
    count = count or 1
    local inv = GetInventory(source)
    for _, row in ipairs(inv) do
        if row.item == item and row.count >= count then return true end
    end
    return false
end

local function findInventoryRow(source, item)
    local inv = GetInventory(source)
    for _, row in ipairs(inv) do
        if row.item == item then return row end
    end
    return nil
end

local function getGasCanMaxLiters()
    local def = Sunset.Items and Sunset.Items.gas_can
    return (def and def.maxLiters) or 20
end

local function getGasCanLiters(row)
    if not row then return 0 end
    local maxLiters = getGasCanMaxLiters()
    if row.metadata and row.metadata.liters ~= nil then
        return math.max(0, math.min(maxLiters, tonumber(row.metadata.liters) or 0))
    end
    -- Legacy: metadata.fuel was 0–100% of can capacity
    if row.metadata and row.metadata.fuel ~= nil then
        local pct = math.max(0, math.min(100, tonumber(row.metadata.fuel) or 0))
        return (pct / 100.0) * maxLiters
    end
    return 0
end

function SetItemMetadata(source, item, metadata)
    local row = findInventoryRow(source, item)
    if not row then return false end
    row.metadata = metadata or {}
    MySQL.update.await('UPDATE character_inventory SET metadata = ? WHERE id = ?', {
        json.encode(row.metadata), row.id,
    })
    local inv = GetInventory(source)
    sendInventoryUpdate(source, inv)
    return true
end

function CountItem(source, item)
    local total = 0
    for _, row in ipairs(GetInventory(source)) do
        if row.item == item then total = total + (tonumber(row.count) or 0) end
    end
    return total
end

function TakeAllItems(source, item)
    local char = exports.sunset_core:GetCharacter(source)
    if not char or type(item) ~= 'string' then return nil end
    local inv = GetInventory(source)
    local removed = {}
    for _, row in ipairs(inv) do
        if row.item == item then removed[#removed + 1] = row end
    end
    if #removed == 0 then return {} end
    MySQL.update.await('DELETE FROM character_inventory WHERE character_id = ? AND item = ?', { char.id, item })
    for i = #inv, 1, -1 do
        if inv[i].item == item then table.remove(inv, i) end
    end
    sendInventoryUpdate(source, inv)
    return removed
end

function UseItem(source, item)
    if type(IsInventoryTradeLocked) == 'function' and IsInventoryTradeLocked(source) then
        return false, 'Cancel or complete your active trade before using items.'
    end
    if type(item) ~= 'string' or item == '' then
        return false, 'The selected inventory item is invalid. Close and reopen the inventory.'
    end
    local def = Sunset.Items[item]
    if not def then return false, 'This item is no longer configured. Close and reopen the inventory.' end
    if not HasItem(source, item, 1) then
        return false, ('You no longer have %s. Close and reopen the inventory.'):format(def.label or item)
    end
    if not def.usable then
        return false, ('%s cannot be used directly from the inventory.'):format(def.label or item)
    end

    if item == 'gas_can' then
        emitClient('sunset:client:inventoryForceClose', source)
        emitClient('sunset:client:useGasCan', source)
        return true
    end

    if def.ammoRounds and type(def.ammoWeapons) == 'table' then
        if GetResourceState('sunset_licenses') ~= 'started' then
            return false, 'The license service is unavailable. The ammunition was not consumed.'
        end
        if not exports.sunset_licenses:HasLicense(source, 'weapon') then
            return false, 'Your Firearm License is missing or expired. The ammunition was not consumed.'
        end
        local compatible = {}
        for _, weaponName in ipairs(def.ammoWeapons) do compatible[string.upper(weaponName)] = true end
        local ownsCompatibleWeapon = false
        for _, row in ipairs(GetInventory(source)) do
            local rowDef = Sunset.Items[row.item]
            if rowDef and rowDef.weapon and compatible[string.upper(rowDef.weapon)] then
                ownsCompatibleWeapon = true
                break
            end
        end
        if not ownsCompatibleWeapon then
            return false, ('You do not own a weapon compatible with %s. The box was not consumed.'):format(def.label or item)
        end
        if not RemoveItem(source, item, 1) then
            return false, 'Your ammunition changed before it could be loaded. Reopen the inventory.'
        end
        emitClient('sunset:client:addWeaponAmmo', source, def.ammoWeapons, def.ammoRounds)
        return true
    end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false, 'Your character is not loaded. Reconnect and try again.' end
    if not def.hunger and not def.thirst and not def.stress and not def.heal then
        return false, ('%s does not have a usable action configured yet. The item was not consumed.'):format(
            def.label or item)
    end
    if not RemoveItem(source, item, 1) then
        return false, ('Could not consume %s because your inventory changed. Reopen it and try again.'):format(
            def.label or item)
    end

    if def.hunger then char.hunger = math.min(100, (char.hunger or 100) + def.hunger) end
    if def.thirst then char.thirst = math.min(100, (char.thirst or 100) + def.thirst) end
    if def.stress then char.stress = math.max(0, math.min(100, (char.stress or 0) + def.stress)) end
    if def.heal then
        emitClient('sunset:client:heal', source, def.heal)
    end

    emitClient('sunset:client:updateCharacter', source, char)
    return true
end

function TryAddItem(source, item, count, slot, metadata)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then
        return false, 'That player has not loaded a character yet.'
    end
    if not Sunset.Items[item] then
        return false, ('"%s" is not a registered item. Check items.lua or /help for valid item ids.'):format(tostring(item or '?'))
    end
    count = math.floor(count or 1)
    if count < 1 then
        return false, 'Item count must be at least 1.'
    end

    local inv = GetInventory(source)
    local currentWeight = calcWeight(inv)
    local addedWeight = getItemWeight(item, count)
    if currentWeight + addedWeight > Sunset.Config.MaxWeight then
        return false, ('Inventory too heavy: %.1f/%.1f kg — cannot add %.1f kg of %s.'):format(
            currentWeight, Sunset.Config.MaxWeight, addedWeight, item)
    end

    metadata = metadata or (item == 'gas_can' and { liters = 0 } or nil)
    if not metadata then
        for _, row in ipairs(inv) do
            if row.item == item and (not slot or row.slot == slot) then
                if AddItem(source, item, count, slot, metadata) then
                    return true
                end
                return false, 'Could not stack the item — try again.'
            end
        end
    end

    local used = {}
    for _, row in ipairs(inv) do used[row.slot] = true end
    local freeSlot = slot
    if not freeSlot then
        for i = 1, Sunset.Config.MaxSlots do
            if not used[i] then freeSlot = i break end
        end
    end
    if not freeSlot then
        return false, ('Inventory full: no free slots (%d max).'):format(Sunset.Config.MaxSlots)
    end

    if AddItem(source, item, count, slot, metadata) then
        return true
    end
    return false, 'Could not add the item — database or inventory sync failed.'
end

exports('GetInventory', GetInventory)
exports('AddItem', AddItem)
exports('TryAddItem', TryAddItem)
exports('RemoveItem', RemoveItem)
exports('RemoveItemById', RemoveItemById)
exports('RemoveRobberyItems', RemoveRobberyItems)
exports('ReloadInventory', ReloadInventory)
exports('HasItem', HasItem)
exports('UseItem', UseItem)
exports('SetItemMetadata', SetItemMetadata)
exports('CountItem', CountItem)
exports('TakeAllItems', TakeAllItems)
exports('GetGasCanLiters', function(source)
    return getGasCanLiters(findInventoryRow(source, 'gas_can'))
end)

exports.sunset_core:RegisterCallback('sunset:getInventory', function(source)
    local inv = GetInventory(source)
    local char = exports.sunset_core:GetCharacter(source)
    local nearbyPlayers = {}
    local sourcePed = GetPlayerPed(source)
    if sourcePed and sourcePed ~= 0 then
        local origin = GetEntityCoords(sourcePed)
        for _, playerId in ipairs(GetPlayers()) do
            local target = tonumber(playerId)
            if target and target ~= source then
                local targetPed = GetPlayerPed(target)
                if targetPed and targetPed ~= 0 then
                    local distance = #(origin - GetEntityCoords(targetPed))
                    if distance <= 3.0 then
                        local targetChar = exports.sunset_core:GetCharacter(target)
                        if targetChar then
                            nearbyPlayers[#nearbyPlayers + 1] = {
                                id = target,
                                name = targetChar.name or targetChar.firstname or GetPlayerName(target),
                                distance = math.floor(distance * 10 + 0.5) / 10,
                            }
                        end
                    end
                end
            end
        end
    end
    table.sort(nearbyPlayers, function(a, b) return a.distance < b.distance end)
    return {
        items = inventoryView(inv),
        weight = calcWeight(inv),
        maxWeight = Sunset.Config.MaxWeight,
        cash = (char and tonumber(char.cash)) or 0,
        nearbyPlayers = nearbyPlayers,
    }
end)

exports.sunset_core:RegisterCallback('sunset:useItem', function(source, item)
    local used, reason = UseItem(source, item)
    if used then return true end
    return nil, reason or 'This item cannot be used right now. It was not consumed.'
end)

exports.sunset_core:RegisterCallback('sunset:getGasCanLiters', function(source)
    return getGasCanLiters(findInventoryRow(source, 'gas_can'))
end)

exports.sunset_core:RegisterCallback('sunset:inventoryHasItem', function(source, item)
    return HasItem(source, item, 1)
end)

exports.sunset_core:RegisterCallback('sunset:inventory:moveSlot', function(source, data)
    if type(IsInventoryTradeLocked) == 'function' and IsInventoryTradeLocked(source) then
        return nil, 'Cannot rearrange inventory during an active trade.'
    end
    local fromSlot = tonumber(type(data) == 'table' and data.fromSlot)
    local toSlot = tonumber(type(data) == 'table' and data.toSlot)
    if not fromSlot or not toSlot or fromSlot < 1 or toSlot < 1 or fromSlot == toSlot then
        return nil, 'Invalid inventory slot.'
    end
    if fromSlot > Sunset.Config.MaxSlots or toSlot > Sunset.Config.MaxSlots then
        return nil, 'Invalid inventory slot.'
    end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Your character is not loaded.' end
    local inv = GetInventory(source)
    local fromRow
    local toRow
    for _, row in ipairs(inv) do
        if tonumber(row.slot) == fromSlot then fromRow = row end
        if tonumber(row.slot) == toSlot then toRow = row end
    end
    if not fromRow then return nil, 'That inventory slot is empty.' end

    local transactionOk
    if toRow then
        -- Stack identical items that have no unique metadata (e.g. bread, water, ammo)
        if fromRow.item == toRow.item and not fromRow.metadata and not toRow.metadata then
            transactionOk = MySQL.startTransaction(function()
                local locked = MySQL.query.await(
                    'SELECT id FROM character_inventory WHERE character_id = ? AND id IN (?, ?) FOR UPDATE',
                    { char.id, fromRow.id, toRow.id }) or {}
                if #locked ~= 2 then error('inventory_changed') end
                local changed = MySQL.update.await(
                    'UPDATE character_inventory SET count = count + ? WHERE id = ? AND character_id = ?',
                    { fromRow.count, toRow.id, char.id })
                if changed ~= 1 then error('stack_failed') end
                MySQL.update.await('DELETE FROM character_inventory WHERE id = ? AND character_id = ?', { fromRow.id, char.id })
            end)
        else
            -- A temporary out-of-range slot makes the swap compatible with the
            -- unique (character_id, slot) invariant.
            transactionOk = MySQL.startTransaction(function()
                local locked = MySQL.query.await(
                    'SELECT id FROM character_inventory WHERE character_id = ? AND id IN (?, ?) FOR UPDATE',
                    { char.id, fromRow.id, toRow.id }) or {}
                if #locked ~= 2 then error('inventory_changed') end
                if MySQL.update.await('UPDATE character_inventory SET slot = 65535 WHERE id = ? AND character_id = ?', { fromRow.id, char.id }) ~= 1 then error('swap_failed') end
                if MySQL.update.await('UPDATE character_inventory SET slot = ? WHERE id = ? AND character_id = ?', { fromSlot, toRow.id, char.id }) ~= 1 then error('swap_failed') end
                if MySQL.update.await('UPDATE character_inventory SET slot = ? WHERE id = ? AND character_id = ?', { toSlot, fromRow.id, char.id }) ~= 1 then error('swap_failed') end
            end)
        end
    else
        transactionOk = MySQL.update.await(
            'UPDATE character_inventory SET slot = ? WHERE id = ? AND character_id = ? AND slot = ?',
            { toSlot, fromRow.id, char.id, fromSlot }) == 1
    end
    if not transactionOk then
        loadInventory(char.id)
        return nil, 'Your inventory changed while moving that item. It was refreshed; try again.'
    end
    inv = loadInventory(char.id)
    sendInventoryUpdate(source, inv)
    return true
end)

AddEventHandler('sunset:server:characterSelected', function(source, charId)
    local char = exports.sunset_core:GetCharacter(source)
    charId = tonumber(charId) or (char and tonumber(char.id))
    if not charId then return end
    loadInventory(charId)
end)

RegisterNetEvent('sunset:server:inventoryLoaded', function()
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end
    local inv = loadInventory(char.id)
    sendInventoryUpdate(source, inv)
end)

AddEventHandler('playerDropped', function()
    local char = exports.sunset_core:GetCharacter(source)
    if char then Inventories[char.id] = nil end
end)
