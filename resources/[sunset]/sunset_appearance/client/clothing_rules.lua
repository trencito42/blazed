-- ============================================================
--  sunset_appearance client — clothing compatibility RULES
--  The single source of truth for top -> torso -> undershirt
--  compatibility. Data-driven so a new custom pack or a newly
--  discovered broken combo never requires editing behavior code.
--
--  Resolution order for a top selection:
--    1. Authored Overrides (this file / populated via /clothinglab)
--    2. Archetype rule classification (closed vs open vs tank)
--    3. besttorso JSON community data (torso only)
--    4. Gender safe defaults (M: 15 / F: 14)
--
--  Undershirts:
--    - Closed/standalone tops (t-shirts, polos, closed jackets, hoodies)
--      automatically enforce undershirt 15 (None).
--    - Open tops (suit jackets, open cardigans) allow compatible undershirts
--      and default to safe inner layers.
-- ============================================================

SunsetClothingRules = SunsetClothingRules or {}

-- [CLOTHING LOGGING] Convar-controlled debug logging
local function clothingDebug(category, fmt, ...)
    if GetConvar('sv_clothing_debug', '0') ~= '1' then return end
    print(('[CLOTHING %s] %s'):format(category, fmt:format(...)))
end

-- Rate-limit identical warnings to avoid spam
local lastWarnings = {}
local function clothingWarn(category, key, fmt, ...)
    local now = GetGameTimer()
    local last = lastWarnings[key] or 0
    if now - last < 5000 then return end
    lastWarnings[key] = now
    clothingDebug(category, fmt, ...)
end

-- Gender-safe "no undershirt" (bare torso) drawables.
SunsetClothingRules.NoneUndershirt = { male = 15, female = 15 }

local function genderKey(gender)
    return (gender == 1 or gender == 'female') and 'female' or 'male'
end

-- Curated overrides for tops with known clipping or bad besttorso data.
-- Format: [genderKey] = { [topDrawable] = {
--     torso = { drawable, texture },
--     defaultUndershirt = { drawable, texture },
--     closed = boolean, -- if true, NO undershirt is allowed (forced to None 15)
--     blockedUndershirts = { [drawable] = true },
--     allowedUndershirts = { [drawable] = true },
-- } }
SunsetClothingRules.Overrides = {
    male = {
        -- Top 27: Black bomber/leather jacket -> Torso 0 (bare wrists, NOT Torso 1 which has white sleeves), closed
        [27] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 28, 29, 30: leather jackets / coats -> Torso 0, closed
        [28] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        [29] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 44: Green collared polo shirt -> Torso 0 (bare arms), closed
        [44] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 0: T-shirt / V-neck -> Torso 0, closed
        [0] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 1: Long sleeve shirt -> Torso 1, closed
        [1] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 4: Suit / Blazer Open -> Torso 4, defaultUndershirt = { 0, 0 }, open
        [4] = { torso = { 4, 0 }, defaultUndershirt = { 0, 0 }, closed = false },
        -- Top 7: Open Tuxedo / Jacket -> Torso 4, defaultUndershirt = { 0, 0 }, open
        [7] = { torso = { 4, 0 }, defaultUndershirt = { 0, 0 }, closed = false },
        -- Top 10: Open suit jacket -> Torso 4, defaultUndershirt = { 0, 0 }, open
        [10] = { torso = { 4, 0 }, defaultUndershirt = { 0, 0 }, closed = false },
        -- Top 15: Bare chest / no top -> Torso 15, defaultUndershirt = { 15, 0 }, closed
        [15] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 16: Sleeveless tank top -> Torso 15, defaultUndershirt = { 15, 0 }, closed
        [16] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 17: Tank top -> Torso 15, defaultUndershirt = { 15, 0 }, closed
        [17] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
    },
    female = {
        -- Top 15: Bare chest / no top -> Torso 15, defaultUndershirt = { 15, 0 }, closed
        [15] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 16: Tank top -> Torso 15, defaultUndershirt = { 15, 0 }, closed
        [16] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 27: Jacket -> Torso 0, defaultUndershirt = { 15, 0 }, closed
        [27] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 44: T-shirt / Polo -> Torso 0, defaultUndershirt = { 15, 0 }, closed
        [44] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
    },
}

local function overrideFor(gender, topDrawable)
    local bank = SunsetClothingRules.Overrides[genderKey(gender)]
    return bank and bank[math.floor(tonumber(topDrawable) or -1)] or nil
end

-- Inspect whether a top requires no undershirt by default (closed tops)
function SunsetClothingRules.isClosedTop(gender, topDrawable)
    local ov = overrideFor(gender, topDrawable)
    if ov and ov.closed ~= nil then return ov.closed end
    -- By GTA V design convention, the majority of standalone tops (drawables not designed as suit blazers)
    -- are closed tops that clip heavily if an undershirt is forced.
    return false
end

-- Resolve the full combo for a top: torso (d,t) + default undershirt (d,t) + isClosed.
function SunsetClothingRules.resolveTopCombo(ped, gender, topDrawable, topTexture)
    topDrawable = math.floor(tonumber(topDrawable) or 0)
    topTexture = math.floor(tonumber(topTexture) or 0)
    local ov = overrideFor(gender, topDrawable)
    local genderKeyStr = genderKey(gender)

    local torsoD, torsoT
    if ov and ov.torso then
        torsoD, torsoT = ov.torso[1], ov.torso[2] or 0
        clothingDebug('RESOLVE', 'top=%d tex=%d gender=%s -> OVERRIDE torso=%d tex=%d', topDrawable, topTexture, genderKeyStr, torsoD, torsoT)
    elseif SunsetAppearance and SunsetAppearance.resolveTorso then
        torsoD, torsoT = SunsetAppearance.resolveTorso(ped, gender, topDrawable, topTexture)
        if torsoD then
            clothingDebug('RESOLVE', 'top=%d tex=%d gender=%s -> BESTTORSO torso=%d tex=%d', topDrawable, topTexture, genderKeyStr, torsoD, torsoT)
        else
            torsoD = gender == 1 and 14 or 15
            torsoT = 0
            clothingWarn('FALLBACK', ('top%d_%s'):format(topDrawable, genderKeyStr),
                'top=%d tex=%d gender=%s -> FALLBACK torso=%d (no besttorso entry)', topDrawable, topTexture, genderKeyStr, torsoD)
        end
    else
        torsoD = gender == 1 and 14 or 15
        torsoT = 0
        clothingWarn('FALLBACK', ('top%d_%s'):format(topDrawable, genderKeyStr),
            'top=%d gender=%s -> FALLBACK torso=%d (no resolver)', topDrawable, genderKeyStr, torsoD)
    end

    local underD, underT
    if ov and ov.defaultUndershirt then
        underD, underT = ov.defaultUndershirt[1], ov.defaultUndershirt[2] or 0
    else
        underD = SunsetClothingRules.NoneUndershirt[genderKeyStr]
        underT = 0
    end

    local isClosed = (ov and ov.closed ~= nil) and ov.closed or false
    return torsoD, torsoT or 0, underD, underT or 0, isClosed
end

function SunsetClothingRules.isUndershirtAllowed(gender, topDrawable, undershirtDrawable)
    undershirtDrawable = math.floor(tonumber(undershirtDrawable) or 15)
    local noneVal = SunsetClothingRules.NoneUndershirt[genderKey(gender)]
    if undershirtDrawable == noneVal then return true end

    local ov = overrideFor(gender, topDrawable)
    if ov then
        if ov.closed == true then
            return false
        end
        if ov.allowedUndershirts then
            return ov.allowedUndershirts[undershirtDrawable] == true
        end
        if ov.blockedUndershirts then
            return not ov.blockedUndershirts[undershirtDrawable]
        end
    end
    return true
end

-- Complete atomic resolution when a top is selected.
-- Automatically adapts Component 11, Component 8 (undershirt), and Component 3 (torso/arms).
function SunsetClothingRules.resolveTopSelection(appearance, ped, gender, topDrawable, topTexture)
    appearance = appearance or {}
    appearance.components = appearance.components or {}
    topDrawable = math.floor(tonumber(topDrawable) or 0)
    topTexture = math.floor(tonumber(topTexture) or 0)

    appearance.components['11'] = { drawable = topDrawable, texture = topTexture }

    local torsoD, torsoT, defaultUnderD, defaultUnderT, isClosed =
        SunsetClothingRules.resolveTopCombo(ped, gender, topDrawable, topTexture)

    appearance.components['3'] = { drawable = torsoD, texture = torsoT }

    local currentUnder = appearance.components['8']
    local underDraw = currentUnder and tonumber(currentUnder.drawable) or nil

    if isClosed or underDraw == nil or not SunsetClothingRules.isUndershirtAllowed(gender, topDrawable, underDraw) then
        appearance.components['8'] = { drawable = defaultUnderD, texture = defaultUnderT }
    end

    return appearance
end

-- Complete atomic resolution when an undershirt is selected.
function SunsetClothingRules.resolveUndershirtSelection(appearance, ped, gender, underDrawable, underTexture)
    appearance = appearance or {}
    appearance.components = appearance.components or {}
    local top = appearance.components['11'] or { drawable = 0, texture = 0 }
    underDrawable = math.floor(tonumber(underDrawable) or 15)
    underTexture = math.floor(tonumber(underTexture) or 0)

    if not SunsetClothingRules.isUndershirtAllowed(gender, top.drawable, underDrawable) then
        local _, _, defaultUnderD, defaultUnderT =
            SunsetClothingRules.resolveTopCombo(ped, gender, top.drawable, top.texture)
        appearance.components['8'] = { drawable = defaultUnderD, texture = defaultUnderT }
        return appearance
    end

    appearance.components['8'] = { drawable = underDrawable, texture = underTexture }
    return appearance
end

-- Registration API for addon packs / hot-loaded rules (no file edits needed).
-- Exposed via sunset_appearance export RegisterTopCompatibility.
function SunsetClothingRules.RegisterTopCompatibility(gender, topDrawable, rule)
    gender = tostring(gender or '')
    if gender ~= 'male' and gender ~= 'female' then return false end
    topDrawable = math.floor(tonumber(topDrawable) or -1)
    if topDrawable < 0 or type(rule) ~= 'table' then return false end
    SunsetClothingRules.Overrides[gender][topDrawable] = rule
    return true
end
