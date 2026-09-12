-- ============================================================
--  sunset_clothing server — saved outfits (C8)
--  Server-authoritative: ownership by character_id, count cap,
--  appearance sanitized through sunset_appearance's validator.
-- ============================================================

local MAX_OUTFITS = 8

-- Reject markup characters in user-chosen outfit names (rendered in UI).
local function hasBadChars(s)
    return s:find('[<>"\']') ~= nil
end

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function sanitize(appearance, fallback)
    if GetResourceState('sunset_appearance') ~= 'started' then return nil, 'Appearance system unavailable.' end
    local ok, result, err = pcall(function()
        return exports.sunset_appearance:ValidateAppearance(appearance, fallback)
    end)
    if not ok then return nil, 'Validation error.' end
    return result, err
end

exports.sunset_core:RegisterCallback('sunset:outfits:list', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local rows = MySQL.query.await(
        'SELECT id, name, appearance, updated_at FROM character_outfits WHERE character_id = ? ORDER BY name ASC',
        { char.id }) or {}
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = { id = row.id, name = row.name, updatedAt = row.updated_at }
    end
    return { outfits = out, max = MAX_OUTFITS }
end)

exports.sunset_core:RegisterCallback('sunset:outfits:save', function(source, name, snapshot)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    name = tostring(name or ''):gsub('^%s*(.-)%s*$', '%1'):sub(1, 24)
    if #name < 2 then return nil, 'The name must have at least 2 characters.' end
    if hasBadChars(name) then return nil, 'Invalid characters in name.' end

    local count = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM character_outfits WHERE character_id = ?', { char.id })) or 0
    local existing = MySQL.scalar.await(
        'SELECT id FROM character_outfits WHERE character_id = ? AND name = ?', { char.id, name })

    if not existing and count >= MAX_OUTFITS then
        return nil, ('Limita de %d outfit-uri atinsa. Sterge unul mai vechi.'):format(MAX_OUTFITS)
    end

    -- The client sends a ped clothing snapshot (what the player actually
    -- wears); the server validates it with the same sanitizer as
    -- saveAppearance and merges it over the persisted appearance so head/
    -- hair/overlays stay from the DB (snapshot only covers clothes+props).
    local base = char.appearance
    local merged = base
    if type(snapshot) == 'table' then
        merged = {
            headBlend = base and base.headBlend,
            hair = base and base.hair,
            overlays = base and base.overlays,
            components = snapshot.components,
            props = snapshot.props,
        }
    end
    local sanitized, err = sanitize(merged, base)
    if not sanitized then return nil, err or 'Invalid appearance.' end

    if existing then
        MySQL.update.await(
            'UPDATE character_outfits SET appearance = ? WHERE id = ? AND character_id = ?',
            { json.encode(sanitized), existing, char.id })
        return true, 'existing'
    end
    MySQL.insert.await(
        'INSERT INTO character_outfits (character_id, name, appearance) VALUES (?, ?, ?)',
        { char.id, name, json.encode(sanitized) })
    return true, 'new'
end)

exports.sunset_core:RegisterCallback('sunset:outfits:equip', function(source, outfitId)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    outfitId = tonumber(outfitId)
    if not outfitId then return nil, 'Invalid outfit.' end

    local row = MySQL.single.await(
        'SELECT appearance FROM character_outfits WHERE id = ? AND character_id = ?',
        { outfitId, char.id })
    if not row then return nil, 'Outfit not found.' end

    local decoded = type(row.appearance) == 'string' and json.decode(row.appearance) or row.appearance
    local sanitized, err = sanitize(decoded, char.appearance)
    if not sanitized then return nil, err or 'Stored outfit is corrupt.' end

    -- Equip = write onto the live character appearance (same path as shop
    -- purchase, minus the fee: outfits you already own are free to wear).
    local encoded = json.encode(sanitized)
    if not encoded then return nil, 'Outfit data error.' end
    MySQL.update.await('UPDATE characters SET appearance = ? WHERE id = ?', { encoded, char.id })
    char.appearance = sanitized
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    TriggerClientEvent('sunset:clothing:applyAppearance', source, sanitized)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:outfits:delete', function(source, outfitId)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    outfitId = tonumber(outfitId)
    if not outfitId then return nil, 'Invalid outfit.' end
    local changed = MySQL.update.await(
        'DELETE FROM character_outfits WHERE id = ? AND character_id = ?',
        { outfitId, char.id })
    if not changed or changed < 1 then return nil, 'Outfit not found.' end
    return true
end)

exports.sunset_core:RegisterCallback('sunset:outfits:rename', function(source, outfitId, newName)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    outfitId = tonumber(outfitId)
    newName = tostring(newName or ''):gsub('^%s*(.-)%s*$', '%1'):sub(1, 24)
    if not outfitId or #newName < 2 then return nil, 'Invalid name.' end
    if hasBadChars(newName) then return nil, 'Invalid characters in name.' end
    local changed = MySQL.update.await(
        'UPDATE character_outfits SET name = ? WHERE id = ? AND character_id = ?',
        { newName, outfitId, char.id })
    if not changed or changed < 1 then return nil, 'Outfit not found or name taken.' end
    return true
end)