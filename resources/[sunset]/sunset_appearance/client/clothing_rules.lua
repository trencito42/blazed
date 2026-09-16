-- ============================================================
--  sunset_appearance client — clothing compatibility RULES
--  The single source of truth for top -> torso -> undershirt
--  compatibility. Data-driven so a new custom pack or a newly
--  discovered broken combo never requires editing behavior code.
--
--  Resolution order for a top selection:
--    1. Authored Overrides (this file / populated via /clothinglab)
--    2. besttorso JSON community data (torso only)
--    3. Gender safe defaults
--
--  Undershirts: a top change snaps the undershirt to the rule's
--  default (the safe combo). Players may then pick any undershirt
--  that is not explicitly blocked for that top (preview shows the
--  result instantly). Blocked entries are authored from observed
--  holes/clipping via /clothinglab.
--
--  [CLOTHING LOGGING] Debug logging controlled by convar
--  sv_clothing_debug (0=off, 1=on). Categories:
--  [CLOTHING RESOLVE] — resolution path taken
--  [CLOTHING VALIDATE] — validation results
--  [CLOTHING FALLBACK] — fallback triggered
--  [CLOTHING APPLY] — atomic application
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
    if now - last < 5000 then return end -- 5s dedup
    lastWarnings[key] = now
    clothingDebug(category, fmt, ...)
end

-- Author-maintained compatibility overrides.
-- Format: [genderKey] = { [topDrawable] = {
--     torso = { drawable, texture },            -- optional (else besttorso)
--     defaultUndershirt = { drawable, texture },-- optional (else gender none)
--     blockedUndershirts = { [drawable] = true },-- optional
-- } }
-- POPULATE VIA /clothingdebug "SAVE COMBINATION" output (admin 4+).
SunsetClothingRules.Overrides = {
    male = {
        -- example (do not ship guesses):
        -- [32] = { torso = { 8, 0 }, defaultUndershirt = { 15, 0 }, blockedUndershirts = { [3] = true } },
    },
    female = {},
}

-- Gender-safe "no undershirt" (bare torso) drawables.
SunsetClothingRules.NoneUndershirt = { male = 15, female = 15 }

local function genderKey(gender)
    return gender == 1 and 'female' or 'male'
end

local function overrideFor(gender, topDrawable)
    local bank = SunsetClothingRules.Overrides[genderKey(gender)]
    return bank and bank[math.floor(tonumber(topDrawable) or -1)] or nil
end

-- Resolve the full combo for a top: torso (d,t) + default undershirt (d,t).
function SunsetClothingRules.resolveTopCombo(ped, gender, topDrawable, topTexture)
    local ov = overrideFor(gender, topDrawable)
    local genderKeyStr = genderKey(gender)

    local torsoD, torsoT
    if ov and ov.torso then
        torsoD, torsoT = ov.torso[1], ov.torso[2]
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

    return torsoD, torsoT or 0, underD, underT or 0
end

function SunsetClothingRules.isUndershirtAllowed(gender, topDrawable, undershirtDrawable)
    local ov = overrideFor(gender, topDrawable)
    if ov and ov.blockedUndershirts then
        return not ov.blockedUndershirts[math.floor(tonumber(undershirtDrawable) or -1)]
    end
    return true -- no authored data: allowed (live preview shows the result)
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
