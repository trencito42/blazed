local HOTBAR_SLOTS = 5

local function getCharMeta(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil end
    local row = MySQL.single.await('SELECT metadata FROM characters WHERE id = ?', { char.id })
    local meta = row and row.metadata and json.decode(row.metadata) or {}
    if type(meta) ~= 'table' then meta = {} end
    return char, meta
end

local function saveMeta(characterId, meta)
    -- [AUDIT P5-10] Only write the quickslots key via JSON_SET. The previous
    -- whole-blob rewrite could erase rob_points changed between read and write.
    MySQL.update.await(
        "UPDATE characters SET metadata = JSON_SET(COALESCE(NULLIF(metadata,''),'{}'), '$.quickslots', CAST(? AS JSON)) WHERE id = ?",
        { json.encode(meta.quickslots or {}), characterId })
end

local function weaponLabel(weapon)
    if not weapon or weapon == '' then return 'Weapon' end
    return weapon:gsub('^WEAPON_', ''):gsub('_', ' ')
end

local function findInventoryRow(inv, rowId)
    rowId = tonumber(rowId)
    if not rowId then return nil end
    for _, row in ipairs(inv or {}) do
        if tonumber(row.id) == rowId then return row end
    end
    return nil
end

local function getRawQuickslots(source)
    local _, meta = getCharMeta(source)
    if not meta then return {} end
    if type(meta.quickslots) ~= 'table' then return {} end
    return meta.quickslots
end

local function resolveBinding(binding, inv)
    if type(binding) ~= 'table' or not binding.kind then return nil end

    if binding.kind == 'item' then
        local row = findInventoryRow(inv, binding.rowId)
        if not row then return nil end
        local def = Sunset.Items[row.item] or {}
        return {
            kind = 'item',
            rowId = row.id,
            item = row.item,
            label = def.label or row.item,
            icon = def.icon,
            count = row.count,
            usable = def.usable == true,
            weapon = def.weapon,
            equipProp = def.equipProp ~= nil,
        }
    end

    if binding.kind == 'duty_weapon' then
        local weapon = binding.weapon
        if type(weapon) ~= 'string' or weapon == '' then return nil end
        return {
            kind = 'duty_weapon',
            weapon = weapon,
            label = binding.label or weaponLabel(weapon),
            icon = 'weapon_trigger',
        }
    end

    if binding.kind == 'emote' then
        local name = binding.name
        if type(name) ~= 'string' or name == '' then return nil end
        return {
            kind = 'emote',
            name = name,
            label = binding.label or name,
            icon = 'emote',
        }
    end

    return nil
end

function BuildHotbarView(source, sanitize)
    local inv = GetInventory(source)
    local raw = getRawQuickslots(source)

    if sanitize then
        local dirty = false
        for i = 1, HOTBAR_SLOTS do
            local key = tostring(i)
            local binding = raw[key] or raw[i]
            if binding and not resolveBinding(binding, inv) then
                raw[key] = nil
                raw[i] = nil
                dirty = true
            end
        end
        if dirty then
            local char, meta = getCharMeta(source)
            if char then
                meta.quickslots = raw
                saveMeta(char.id, meta)
            end
        end
    end

    local slots = {}
    for i = 1, HOTBAR_SLOTS do
        local key = tostring(i)
        local binding = raw[key] or raw[i]
        slots[key] = resolveBinding(binding, inv)
    end

    return slots
end

local function assignQuickslot(source, slot, binding)
    local char, meta = getCharMeta(source)
    if not char then return nil, 'Your character is not loaded.' end
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > HOTBAR_SLOTS then
        return nil, 'Invalid quick slot.'
    end

    meta.quickslots = type(meta.quickslots) == 'table' and meta.quickslots or {}
    local key = tostring(slot)

    if not binding then
        meta.quickslots[key] = nil
        saveMeta(char.id, meta)
        return { slots = BuildHotbarView(source, true) }
    end

    if binding.kind == 'item' then
        local inv = GetInventory(source)
        local row = findInventoryRow(inv, binding.rowId)
        if not row then return nil, 'That inventory item is no longer available.' end
        meta.quickslots[key] = { kind = 'item', rowId = row.id }
    elseif binding.kind == 'duty_weapon' then
        local weapon = binding.weapon
        if type(weapon) ~= 'string' or weapon == '' then
            return nil, 'Invalid duty weapon.'
        end
        meta.quickslots[key] = {
            kind = 'duty_weapon',
            weapon = weapon,
            label = binding.label or weaponLabel(weapon),
        }
    elseif binding.kind == 'emote' then
        local name = binding.name
        if type(name) ~= 'string' or name == '' then
            return nil, 'Invalid emote.'
        end
        meta.quickslots[key] = {
            kind = 'emote',
            name = name,
            label = binding.label or name,
        }
    else
        return nil, 'Unsupported quick slot type.'
    end

    saveMeta(char.id, meta)
    return { slots = BuildHotbarView(source, true) }
end

exports.sunset_core:RegisterCallback('sunset:hotbar:get', function(source)
    return { slots = BuildHotbarView(source, false) }
end)

exports.sunset_core:RegisterCallback('sunset:hotbar:assign', function(source, data)
    data = type(data) == 'table' and data or {}
    local slot = tonumber(data.slot)
    if data.clear == true then
        return assignQuickslot(source, slot, nil)
    end
    return assignQuickslot(source, slot, {
        kind = data.kind,
        rowId = data.rowId,
        weapon = data.weapon,
        label = data.label,
        name = data.name,
    })
end)

exports.sunset_core:RegisterCallback('sunset:hotbar:use', function(source, data)
    data = type(data) == 'table' and data or {}
    local slot = tonumber(data.slot)
    local consume = data.consume == true
    if not slot or slot < 1 or slot > HOTBAR_SLOTS then
        return nil, 'Invalid quick slot.'
    end

    local raw = getRawQuickslots(source)
    local binding = raw[tostring(slot)] or raw[slot]
    if not binding then return { action = 'empty' } end

    local inv = GetInventory(source)
    local resolved = resolveBinding(binding, inv)
    if not resolved then
        return nil, 'That quick slot item is no longer available.'
    end

    if resolved.kind == 'item' then
        local def = Sunset.Items[resolved.item] or {}
        if def.usable then
            if not consume then
                return {
                    action = 'equip_usable',
                    slot = slot,
                    item = resolved.item,
                    label = def.label or resolved.item,
                }
            end
            local used, reason = UseItem(source, resolved.item)
            if not used then return nil, reason or 'Cannot use this item.' end
            return { action = 'used_item', slot = slot, slots = BuildHotbarView(source, true) }
        end
        if def.weapon then
            return { action = 'equip_weapon', slot = slot, item = resolved.item, weapon = def.weapon }
        end
        if def.equipProp then
            return { action = 'equip_prop', slot = slot, item = resolved.item }
        end
        return nil, ('%s cannot be used from a quick slot.'):format(def.label or resolved.item)
    end

    if resolved.kind == 'duty_weapon' then
        return { action = 'equip_duty_weapon', slot = slot, weapon = resolved.weapon }
    end

    if resolved.kind == 'emote' then
        return { action = 'play_emote', slot = slot, name = resolved.name }
    end

    return nil, 'Unsupported quick slot.'
end)
