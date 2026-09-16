-- ============================================================
--  sunset_appearance client — clothing compatibility RULES
--  The single source of truth for top -> torso -> undershirt
--  compatibility. Data-driven so a new custom pack or a newly
--  discovered broken combo never requires editing behavior code.
--
--  Canonical Upper Body Bundle:
--    { top = {d,t}, torso = {d,t}, undershirt = {d,t}, source = '...' }
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
        -- Top 1: Long sleeve shirt -> Torso 0, closed
        [1] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 4: Suit / Blazer Open -> Torso 4, defaultUndershirt = { 0, 0 }, closed = false
        [4] = { torso = { 4, 0 }, defaultUndershirt = { 0, 0 }, closed = false },
        -- Top 7: Open Tuxedo / Jacket -> Torso 4, defaultUndershirt = { 0, 0 }, closed = false
        [7] = { torso = { 4, 0 }, defaultUndershirt = { 0, 0 }, closed = false },
        -- Top 10: Open suit jacket -> Torso 4, defaultUndershirt = { 0, 0 }, closed = false
        [10] = { torso = { 4, 0 }, defaultUndershirt = { 0, 0 }, closed = false },
        -- Top 15: Bare chest / no top -> Torso 15, defaultUndershirt = { 15, 0 }, closed = true
        [15] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 16: Sleeveless tank top -> Torso 15, defaultUndershirt = { 15, 0 }, closed = true
        [16] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 17: Tank top -> Torso 15, defaultUndershirt = { 15, 0 }, closed = true
        [17] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
    },
    female = {
        -- Top 15: Bare chest / no top -> Torso 15, defaultUndershirt = { 15, 0 }, closed = true
        [15] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 16: Tank top -> Torso 15, defaultUndershirt = { 15, 0 }, closed = true
        [16] = { torso = { 15, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 27: Jacket -> Torso 0, defaultUndershirt = { 15, 0 }, closed = true
        [27] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
        -- Top 44: T-shirt / Polo -> Torso 0, defaultUndershirt = { 15, 0 }, closed = true
        [44] = { torso = { 0, 0 }, defaultUndershirt = { 15, 0 }, closed = true },
    },
}

local function overrideFor(gender, topDrawable)
    local bank = SunsetClothingRules.Overrides[genderKey(gender)]
    return bank and bank[math.floor(tonumber(topDrawable) or -1)] or nil
end

function SunsetClothingRules.isClosedTop(gender, topDrawable)
    local ov = overrideFor(gender, topDrawable)
    if ov and ov.closed ~= nil then return ov.closed end
    return false
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

-- Canonical Upper Body Bundle Resolver
-- The SINGLE source of truth for { top, torso, undershirt }.
function SunsetClothingRules.resolveUpperBody(ped, gender, topDrawable, topTexture, currentUnderDrawable, currentUnderTexture, isTopChange)
    topDrawable = math.max(0, math.floor(tonumber(topDrawable) or 0))
    topTexture = math.max(0, math.floor(tonumber(topTexture) or 0))
    local genderKeyStr = genderKey(gender)
    local ov = overrideFor(gender, topDrawable)

    local torsoD, torsoT, defaultUnderD, defaultUnderT, isClosed, source

    if ov and ov.torso then
        torsoD, torsoT = ov.torso[1], ov.torso[2] or 0
        defaultUnderD = ov.defaultUndershirt and ov.defaultUndershirt[1] or SunsetClothingRules.NoneUndershirt[genderKeyStr]
        defaultUnderT = ov.defaultUndershirt and (ov.defaultUndershirt[2] or 0) or 0
        isClosed = ov.closed == true
        source = 'override'
        clothingDebug('RESOLVE', 'top=%d tex=%d gender=%s -> OVERRIDE torso=%d tex=%d under=%d', topDrawable, topTexture, genderKeyStr, torsoD, torsoT, defaultUnderD)
    else
        local btTorso, btTex
        if TorsoData and TorsoData.getBestTorso then
            btTorso, btTex = TorsoData.getBestTorso(gender, topDrawable, topTexture)
        end

        if btTorso and btTorso >= 0 then
            torsoD, torsoT = btTorso, btTex or 0
            defaultUnderD = SunsetClothingRules.NoneUndershirt[genderKeyStr]
            defaultUnderT = 0
            isClosed = false
            source = 'besttorso'
            clothingDebug('RESOLVE', 'top=%d tex=%d gender=%s -> BESTTORSO torso=%d tex=%d', topDrawable, topTexture, genderKeyStr, torsoD, torsoT)
        else
            torsoD = (gender == 1 or gender == 'female') and 14 or 15
            torsoT = 0
            defaultUnderD = SunsetClothingRules.NoneUndershirt[genderKeyStr]
            defaultUnderT = 0
            isClosed = false
            source = 'fallback'
            clothingWarn('FALLBACK', ('top%d_%s'):format(topDrawable, genderKeyStr),
                'top=%d tex=%d gender=%s -> FALLBACK torso=%d (no besttorso mapping)', topDrawable, topTexture, genderKeyStr, torsoD)
        end
    end

    local finalUnderD, finalUnderT
    if isTopChange or isClosed or currentUnderDrawable == nil then
        finalUnderD = defaultUnderD
        finalUnderT = defaultUnderT
    else
        local reqUnder = math.floor(tonumber(currentUnderDrawable) or defaultUnderD)
        if SunsetClothingRules.isUndershirtAllowed(gender, topDrawable, reqUnder) then
            finalUnderD = reqUnder
            finalUnderT = math.max(0, math.floor(tonumber(currentUnderTexture) or 0))
        else
            finalUnderD = defaultUnderD
            finalUnderT = defaultUnderT
        end
    end

    return {
        top = { drawable = topDrawable, texture = topTexture },
        torso = { drawable = torsoD, texture = torsoT },
        undershirt = { drawable = finalUnderD, texture = finalUnderT },
        isClosed = isClosed,
        source = source,
    }
end

-- Backward compatible resolveTopCombo
function SunsetClothingRules.resolveTopCombo(ped, gender, topDrawable, topTexture)
    local bundle = SunsetClothingRules.resolveUpperBody(ped, gender, topDrawable, topTexture, nil, nil, true)
    return bundle.torso.drawable, bundle.torso.texture, bundle.undershirt.drawable, bundle.undershirt.texture, bundle.isClosed, bundle.source
end

-- Complete atomic resolution when a top is selected (snaps to default undershirt).
function SunsetClothingRules.resolveTopSelection(appearance, ped, gender, topDrawable, topTexture)
    appearance = appearance or {}
    appearance.components = appearance.components or {}
    local bundle = SunsetClothingRules.resolveUpperBody(ped, gender, topDrawable, topTexture, nil, nil, true)

    appearance.components['11'] = bundle.top
    appearance.components['3'] = bundle.torso
    appearance.components['8'] = bundle.undershirt

    return appearance
end

-- Complete atomic resolution when an undershirt is selected (checks top compatibility).
function SunsetClothingRules.resolveUndershirtSelection(appearance, ped, gender, underDrawable, underTexture)
    appearance = appearance or {}
    appearance.components = appearance.components or {}
    local top = appearance.components['11'] or { drawable = 0, texture = 0 }
    local bundle = SunsetClothingRules.resolveUpperBody(ped, gender, top.drawable, top.texture, underDrawable, underTexture, false)

    appearance.components['8'] = bundle.undershirt
    appearance.components['3'] = bundle.torso

    return appearance
end

-- Registration API for addon packs / hot-loaded rules.
function SunsetClothingRules.RegisterTopCompatibility(gender, topDrawable, rule)
    gender = tostring(gender or '')
    if gender ~= 'male' and gender ~= 'female' then return false end
    topDrawable = math.floor(tonumber(topDrawable) or -1)
    if topDrawable < 0 or type(rule) ~= 'table' then return false end
    SunsetClothingRules.Overrides[gender][topDrawable] = rule
    return true
end
