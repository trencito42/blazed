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
        fib = { 111, 112, 113, 114, 115, 116, 117, 118 },
        sheriff = { 95, 96, 97, 98, 99, 100, 101, 102 },
    }
    local femaleTops = {
        lspd = { 48, 49, 50, 51, 52, 53, 54, 55 },
        fib = { 27, 28, 29, 30, 31, 32, 33, 34 },
        sheriff = { 42, 43, 44, 45, 46, 47, 48, 49 },
    }
    local malePants = style == 'sheriff' and 36 or 35
    local femalePants = style == 'sheriff' and 33 or 34
    local topsM = maleTops[style] or maleTops.lspd
    local topsF = femaleTops[style] or femaleTops.lspd
    local gradeOutfits = {}
    for grade = 0, 7 do
        local idx = grade + 1
        gradeOutfits[grade] = {
            male = leoOutfit(topsM[idx], malePants, {
                undershirt = style == 'fib' and 130 or 58,
                shoes = style == 'sheriff' and 24 or 25,
            }),
            female = leoOutfit(topsF[idx], femalePants, {
                undershirt = style == 'fib' and 160 or 35,
                shoes = style == 'sheriff' and 24 or 25,
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
