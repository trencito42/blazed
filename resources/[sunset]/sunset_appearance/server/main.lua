-- ============================================================
--  sunset_appearance server — saveAppearance with validation
--  [CLOTHING FIX B1] The callback previously persisted ANY
--  client JSON into characters.appearance (injection, junk keys,
--  absurd values). Now every field is type-checked and bounded
--  server-side before storage. Bounds are deliberately generous
--  (above any current GTA drawable count) so DLC growth does not
--  break saves, while garbage/negative/huge values are rejected.
-- ============================================================

local COMPONENT_SLOTS = { '1', '3', '4', '5', '6', '7', '8', '9', '10', '11' }
local PROP_SLOTS = { '0', '1', '2', '6', '7' }
local MAX_DRAWABLE = 400   -- no freemode component exceeds this today
local MAX_TEXTURE = 64
local MAX_PROP_DRAWABLE = 150

local function loadCharacterForPlayer(source, playerId, charId)
    local char = MySQL.single.await('SELECT * FROM characters WHERE id = ? AND player_id = ?', { charId, playerId })
    if not char then return nil end
    return Sunset.DecodeCharacter(char)
end

local function num(value, min, max, fallback)
    value = tonumber(value)
    if not value then return fallback end
    if value ~= value then return fallback end -- NaN
    if value < min or value > max then return nil end -- out of range = reject
    return math.floor(value * 1000 + 0.5) / 1000 -- keep 3 decimals for mixes
end

local function sanitizePair(raw, maxDrawable, fallbackDraw, fallbackTex, minDrawable)
    if type(raw) ~= 'table' then return nil end
    minDrawable = minDrawable or -1
    local d = num(raw.drawable, minDrawable, maxDrawable, fallbackDraw)
    if d == nil then return nil end
    local t = num(raw.texture, 0, MAX_TEXTURE, fallbackTex or 0)
    if t == nil then return nil end
    if d < 0 then d = minDrawable t = 0 end
    return { drawable = math.floor(d), texture = math.floor(t) }
end

-- Returns a sanitized appearance table, or nil + reason on hostile input.
local function sanitizeAppearance(raw, fallback)
    if type(raw) ~= 'table' then return nil, 'appearance must be a table' end
    fallback = type(fallback) == 'table' and fallback or {}

    local out = { version = 2, components = {}, props = {}, overlays = {} }

    -- headBlend
    local hbRaw = type(raw.headBlend) == 'table' and raw.headBlend or {}
    local hbFallback = type(fallback.headBlend) == 'table' and fallback.headBlend or {}
    out.headBlend = {}
    for _, key in ipairs({ 'shapeFirst', 'shapeSecond', 'shapeThird', 'skinFirst', 'skinSecond', 'skinThird' }) do
        local v = num(hbRaw[key], 0, 45, num(hbFallback[key], 0, 45, 0))
        if v == nil then return nil, 'headBlend.' .. key .. ' out of range' end
        out.headBlend[key] = math.floor(v)
    end
    for _, key in ipairs({ 'shapeMix', 'skinMix', 'thirdMix' }) do
        local v = num(hbRaw[key], 0.0, 1.0, num(hbFallback[key], 0.0, 1.0, 0.0))
        if v == nil then return nil, 'headBlend.' .. key .. ' out of range' end
        out.headBlend[key] = v
    end

    -- hair
    local hairRaw = type(raw.hair) == 'table' and raw.hair or {}
    local hairFallback = type(fallback.hair) == 'table' and fallback.hair or {}
    out.hair = {}
    local hd = num(hairRaw.drawable, 0, MAX_DRAWABLE, num(hairFallback.drawable, 0, MAX_DRAWABLE, 0))
    if hd == nil then return nil, 'hair.drawable out of range' end
    out.hair.drawable = math.floor(hd)
    out.hair.texture = math.floor(num(hairRaw.texture, 0, MAX_TEXTURE, num(hairFallback.texture, 0, MAX_TEXTURE, 0)) or 0)
    out.hair.color = math.floor(num(hairRaw.color, 0, 63, num(hairFallback.color, 0, 63, 0)) or 0)
    out.hair.highlight = math.floor(num(hairRaw.highlight, 0, 63, num(hairFallback.highlight, 0, 63, 0)) or 0)

    -- overlays (1 beard, 2 eyebrows)
    for _, key in ipairs({ '1', '2' }) do
        local ovRaw = type(raw.overlays) == 'table' and type(raw.overlays[key]) == 'table' and raw.overlays[key] or {}
        local idx = num(ovRaw.index, 0, 28, 0)
        if idx == nil then return nil, 'overlay index out of range' end
        out.overlays[key] = {
            index = math.floor(idx),
            opacity = num(ovRaw.opacity, 0.0, 1.0, 0.0) or 0.0,
            color = math.floor(num(ovRaw.color, 0, 63, 0) or 0),
        }
    end

    -- components
    if raw.components ~= nil and type(raw.components) ~= 'table' then
        return nil, 'components must be a table'
    end
    for _, slot in ipairs(COMPONENT_SLOTS) do
        local fb = type(fallback.components) == 'table' and fallback.components[slot] or nil
        local pair = sanitizePair(
            type(raw.components) == 'table' and raw.components[slot] or nil,
            MAX_DRAWABLE,
            fb and tonumber(fb.drawable) or 0,
            fb and tonumber(fb.texture) or 0,
            0) -- components: min drawable 0
        if pair == nil and raw.components and raw.components[slot] ~= nil then
            return nil, ('component %s invalid'):format(slot)
        end
        out.components[slot] = pair or { drawable = fb and tonumber(fb.drawable) or 0, texture = fb and tonumber(fb.texture) or 0 }
    end

    -- props (-1 = none)
    if raw.props ~= nil and type(raw.props) ~= 'table' then
        return nil, 'props must be a table'
    end
    for _, slot in ipairs(PROP_SLOTS) do
        local fb = type(fallback.props) == 'table' and fallback.props[slot] or nil
        local pair = sanitizePair(
            type(raw.props) == 'table' and raw.props[slot] or nil,
            MAX_PROP_DRAWABLE,
            fb and tonumber(fb.drawable) or -1,
            fb and tonumber(fb.texture) or 0)
        if pair == nil and raw.props and raw.props[slot] ~= nil then
            return nil, ('prop %s invalid'):format(slot)
        end
        out.props[slot] = pair or { drawable = fb and tonumber(fb.drawable) or -1, texture = fb and tonumber(fb.texture) or 0 }
    end

    return out
end

exports.sunset_core:RegisterCallback('sunset:saveAppearance', function(source, appearance, gender, charId)
    local player = exports.sunset_core:GetPlayer(source)
    if not player then return nil, 'Not logged in' end

    local char = exports.sunset_core:GetCharacter(source)
    charId = tonumber(charId) or (char and char.id)
    if not char and charId then
        char = loadCharacterForPlayer(source, player.id, charId)
    end
    if not char then return nil, 'No character loaded' end

    -- [CLOTHING FIX B1] Ownership: the callback may only ever write the
    -- character that belongs to THIS player (charId is re-checked in SQL too).
    if charId and char.id ~= charId then
        return nil, 'Character mismatch.'
    end

    gender = tonumber(gender)
    if gender == 0 or gender == 1 then
        char.gender = gender
    end

    local sanitized, err = sanitizeAppearance(appearance, char.appearance)
    if not sanitized then
        print(('[sunset_appearance] rejected appearance save from %s: %s'):format(tostring(source), tostring(err)))
        return nil, 'Invalid appearance data. Nothing was saved.'
    end

    local encoded = json.encode(sanitized)
    if not encoded or #encoded > 8192 then return nil, 'Invalid appearance data' end

    MySQL.update.await('UPDATE characters SET appearance = ?, gender = ? WHERE id = ? AND player_id = ?', {
        encoded, char.gender, char.id, player.id
    })

    char.appearance = sanitized
    TriggerEvent('sunset:server:setActiveCharacter', source, char)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end)

-- [CLOTHING C8] Expose the sanitizer so sunset_clothing (outfits) validates
-- with the exact same bounds instead of duplicating logic.
exports('ValidateAppearance', function(appearance, fallback)
    return sanitizeAppearance(appearance, fallback)
end)