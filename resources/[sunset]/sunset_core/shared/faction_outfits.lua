Sunset = Sunset or {}

local function piece(drawable, texture)
    return { drawable = drawable or 0, texture = texture or 0 }
end

local function leoOutfit(top, pants, opts)
    opts = opts or {}
    return {
        [1] = piece(0, 0),
        [3] = piece(opts.arms or 0, 0),
        [4] = piece(pants or 35, 0),
        [6] = piece(opts.shoes or 25, 0),
        [8] = piece(opts.undershirt or 58, 0),
        [11] = piece(top or 55, opts.topTexture or 0),
    }
end

function Sunset.BuildLeoGradeOutfits(style)
    style = style or 'lspd'
    local maleTops = {
        lspd = { 55, 56, 57, 58, 59, 60, 61, 62 },
        fib = { 55, 56, 57, 58, 59, 60, 61, 62 },
        sheriff = { 55, 55, 55, 55, 55, 55, 55, 55 },
    }
    local femaleTops = {
        lspd = { 48, 49, 50, 51, 52, 53, 54, 55 },
        fib = { 48, 49, 50, 51, 52, 53, 54, 55 },
        sheriff = { 48, 48, 48, 48, 48, 48, 48, 48 },
    }
    local malePants = style == 'sheriff' and 36 or 35
    local femalePants = style == 'sheriff' and 33 or 34
    local topsM = maleTops[style] or maleTops.lspd
    local topsF = femaleTops[style] or femaleTops.lspd
    local gradeOutfits = {}
    for grade = 0, 7 do
        local idx = grade + 1
        local sheriffTex = style == 'sheriff' and 1 or 0
        gradeOutfits[grade] = {
            male = leoOutfit(topsM[idx], malePants, {
                undershirt = style == 'fib' and 58 or 58,
                shoes = style == 'sheriff' and 24 or 25,
                arms = style == 'sheriff' and 19 or (style == 'fib' and 12 or 0),
                topTexture = style == 'sheriff' and sheriffTex or 0,
            }),
            female = leoOutfit(topsF[idx], femalePants, {
                undershirt = style == 'fib' and 35 or 35,
                shoes = style == 'sheriff' and 24 or 25,
                arms = style == 'sheriff' and 31 or (style == 'fib' and 14 or 0),
                topTexture = style == 'sheriff' and sheriffTex or 0,
            }),
        }
    end
    return gradeOutfits
end

function Sunset.BuildEmsGradeOutfits()
    local maleTops = { 250, 251, 252, 253, 254, 255, 256, 257 }
    local femaleTops = { 258, 259, 260, 261, 262, 263, 264, 265 }
    local gradeOutfits = {}
    for grade = 0, 7 do
        local idx = grade + 1
        gradeOutfits[grade] = {
            male = leoOutfit(maleTops[idx], 96, { undershirt = 15, shoes = 42, arms = 85 }),
            female = leoOutfit(femaleTops[idx], 99, { undershirt = 15, shoes = 42, arms = 109 }),
        }
    end
    return gradeOutfits
end

function Sunset.BuildFireGradeOutfits()
    local maleTops = { 314, 315, 316, 317, 318, 319, 320, 321 }
    local femaleTops = { 322, 323, 324, 325, 326, 327, 328, 329 }
    local gradeOutfits = {}
    for grade = 0, 7 do
        local idx = grade + 1
        gradeOutfits[grade] = {
            male = leoOutfit(maleTops[idx], 120, { undershirt = 15, shoes = 24, arms = 85 }),
            female = leoOutfit(femaleTops[idx], 126, { undershirt = 15, shoes = 24, arms = 109 }),
        }
    end
    return gradeOutfits
end

local SERVICE_OUTFIT_PRESETS = {
    mechanic = {
        maleTops = { 66, 66, 66, 73, 73, 73, 89, 89 },
        femaleTops = { 59, 59, 59, 62, 62, 62, 65, 65 },
        maleTopTextures = { 2, 2, 2, 0, 0, 0, 0, 0 },
        femaleTopTextures = { 2, 2, 2, 0, 0, 0, 0, 0 },
        malePants = 98, femalePants = 101,
        maleShoes = 12, femaleShoes = 26,
        maleArms = 11, femaleArms = 14,
        maleUndershirt = 15, femaleUndershirt = 15,
    },
    taxi = {
        maleTops = { 13, 13, 32, 32, 32, 32, 32, 32 },
        femaleTops = { 27, 27, 41, 41, 41, 41, 41, 41 },
        maleTopTextures = { 5, 5, 0, 0, 0, 0, 0, 0 },
        femaleTopTextures = { 5, 5, 0, 0, 0, 0, 0, 0 },
        malePants = 24, femalePants = 34,
        maleShoes = 10, femaleShoes = 29,
        maleArms = 11, femaleArms = 14,
        maleUndershirt = 31, femaleUndershirt = 35,
    },
    cartel = {
        maleTops = { 13, 13, 31, 31, 31, 31, 31, 31 },
        femaleTops = { 27, 27, 38, 38, 38, 38, 38, 38 },
        maleTopTextures = { 0, 0, 0, 0, 0, 0, 0, 0 },
        femaleTopTextures = { 0, 0, 0, 0, 0, 0, 0, 0 },
        malePants = 10, femalePants = 6,
        maleShoes = 12, femaleShoes = 26,
        maleArms = 11, femaleArms = 14,
        maleUndershirt = 15, femaleUndershirt = 15,
    },
    syndicate = {
        maleTops = { 16, 16, 57, 57, 57, 57, 57, 57 },
        femaleTops = { 30, 30, 49, 49, 49, 49, 49, 49 },
        maleTopTextures = { 0, 0, 0, 0, 0, 0, 0, 0 },
        femaleTopTextures = { 0, 0, 0, 0, 0, 0, 0, 0 },
        malePants = 4, femalePants = 3,
        maleShoes = 1, femaleShoes = 3,
        maleArms = 0, femaleArms = 14,
        maleUndershirt = 15, femaleUndershirt = 15,
    },
}

function Sunset.BuildServiceGradeOutfits(presetKey)
    local preset = SERVICE_OUTFIT_PRESETS[presetKey] or SERVICE_OUTFIT_PRESETS.mechanic
    local gradeOutfits = {}
    for grade = 0, 7 do
        local idx = grade + 1
        gradeOutfits[grade] = {
            male = leoOutfit(preset.maleTops[idx], preset.malePants, {
                undershirt = preset.maleUndershirt,
                shoes = preset.maleShoes,
                arms = preset.maleArms,
                topTexture = preset.maleTopTextures[idx] or 0,
            }),
            female = leoOutfit(preset.femaleTops[idx], preset.femalePants, {
                undershirt = preset.femaleUndershirt,
                shoes = preset.femaleShoes,
                arms = preset.femaleArms,
                topTexture = preset.femaleTopTextures[idx] or 0,
            }),
        }
    end
    return gradeOutfits
end

function Sunset.BuildServiceLoadout(presetKey, opts)
    opts = opts or {}
    local gradeOutfits = Sunset.BuildServiceGradeOutfits(presetKey)
    local fallbackMale = gradeOutfits[0] and gradeOutfits[0].male
    local fallbackFemale = gradeOutfits[0] and gradeOutfits[0].female
    return {
        armor = opts.armor or 0,
        male = fallbackMale,
        female = fallbackFemale,
        gradeOutfits = gradeOutfits,
        weapons = opts.weapons or {
            { weapon = 'WEAPON_FLASHLIGHT', ammo = 0 },
        },
    }
end

function Sunset.BuildLawEnforcementLoadout(style, vehicle, extraWeapons)
    local gradeOutfits = Sunset.BuildLeoGradeOutfits(style)
    local fallbackMale = gradeOutfits[0] and gradeOutfits[0].male
    local fallbackFemale = gradeOutfits[0] and gradeOutfits[0].female
    return {
        armor = 100,
        male = fallbackMale,
        female = fallbackFemale,
        gradeOutfits = gradeOutfits,
        weapons = {
            { weapon = 'WEAPON_NIGHTSTICK', ammo = 0 },
            { weapon = 'WEAPON_FLASHLIGHT', ammo = 0 },
            { weapon = 'WEAPON_STUNGUN', ammo = 0 },
            { weapon = 'WEAPON_COMBATPISTOL', ammo = 90 },
        },
        gradeWeapons = {
            [3] = {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 120 },
                { weapon = 'WEAPON_PUMPSHOTGUN', ammo = 24 },
            },
            [4] = (extraWeapons and extraWeapons[4]) or {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 150 },
                { weapon = 'WEAPON_PUMPSHOTGUN', ammo = 32 },
            },
            [5] = (extraWeapons and extraWeapons[5]) or {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 180 },
                { weapon = 'WEAPON_SMG', ammo = 120 },
            },
            [6] = (extraWeapons and extraWeapons[6]) or {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 210 },
                { weapon = 'WEAPON_SMG', ammo = 150 },
            },
            [7] = (extraWeapons and extraWeapons[7]) or {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 240 },
                { weapon = 'WEAPON_SMG', ammo = 180 },
                { weapon = 'WEAPON_PUMPSHOTGUN', ammo = 40 },
            },
        },
        vehicle = vehicle,
    }
end

function Sunset.ResolveFactionOutfit(loadout, grade, gender)
    if not loadout then return nil end
    grade = tonumber(grade) or 0
    gender = tonumber(gender) or 0
    local gradeOutfits = loadout.gradeOutfits
    local row = gradeOutfits and gradeOutfits[grade]
    if row then
        return (gender == 1 and row.female) or row.male
    end
    return (gender == 1 and loadout.female) or loadout.male
end
