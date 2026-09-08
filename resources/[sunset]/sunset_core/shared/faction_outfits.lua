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

-- ====================================================================
-- AUTHENTIC REAL GTA V PED SKINS FOR ALL FACTIONS
-- ====================================================================
Sunset.FactionSkins = {
    police = {
        label = 'LSPD',
        defaultMale = 's_m_y_cop_01',
        defaultFemale = 's_f_y_cop_01',
        gradeMale = {
            [0] = 's_m_y_cop_01',
            [1] = 's_m_y_cop_01',
            [2] = 's_m_y_cop_01',
            [3] = 'csb_cop',
            [4] = 'csb_cop',
            [5] = 's_m_m_ciasec_01',
            [6] = 's_m_m_ciasec_01',
            [7] = 's_m_m_ciasec_01',
        },
        gradeFemale = {
            [0] = 's_f_y_cop_01',
            [1] = 's_f_y_cop_01',
            [2] = 's_f_y_cop_01',
            [3] = 's_f_y_cop_01',
            [4] = 's_f_y_cop_01',
            [5] = 's_f_y_cop_01',
            [6] = 's_f_y_cop_01',
            [7] = 's_f_y_cop_01',
        },
        options = {
            { key = 'cop', label = 'Ofițer LSPD Patrulă', male = 's_m_y_cop_01', female = 's_f_y_cop_01', minGrade = 0 },
            { key = 'senior', label = 'Ofițer LSPD Senior / Sergent', male = 'csb_cop', female = 's_f_y_cop_01', minGrade = 2 },
            { key = 'hway', label = 'Highway Patrol (Autostradă)', male = 's_m_y_hwaycop_01', female = 's_f_y_cop_01', minGrade = 1 },
            { key = 'swat', label = 'SWAT / Intervenție Rapidă', male = 's_m_y_swat_01', female = 's_f_y_cop_01', minGrade = 2 },
            { key = 'command', label = 'Conducere / Detectiv', male = 's_m_m_ciasec_01', female = 's_f_y_cop_01', minGrade = 4 },
        },
    },
    sheriff = {
        label = 'San Andreas Sheriff',
        defaultMale = 's_m_y_sheriff_01',
        defaultFemale = 's_f_y_sheriff_01',
        gradeMale = {
            [0] = 's_m_y_sheriff_01',
            [1] = 's_m_y_sheriff_01',
            [2] = 's_m_y_sheriff_01',
            [3] = 's_m_y_sheriff_01',
            [4] = 's_m_y_hwaycop_01',
            [5] = 's_m_y_hwaycop_01',
            [6] = 's_m_y_sheriff_01',
            [7] = 's_m_y_sheriff_01',
        },
        gradeFemale = {
            [0] = 's_f_y_sheriff_01',
            [1] = 's_f_y_sheriff_01',
            [2] = 's_f_y_sheriff_01',
            [3] = 's_f_y_sheriff_01',
            [4] = 's_f_y_sheriff_01',
            [5] = 's_f_y_sheriff_01',
            [6] = 's_f_y_sheriff_01',
            [7] = 's_f_y_sheriff_01',
        },
        options = {
            { key = 'sheriff', label = 'Șerif Patrulă', male = 's_m_y_sheriff_01', female = 's_f_y_sheriff_01', minGrade = 0 },
            { key = 'hway', label = 'Highway Patrol Sheriff', male = 's_m_y_hwaycop_01', female = 's_f_y_sheriff_01', minGrade = 1 },
            { key = 'swat', label = 'Tactical Response / SWAT', male = 's_m_y_swat_01', female = 's_f_y_sheriff_01', minGrade = 2 },
        },
    },
    fib = {
        label = 'FIB',
        defaultMale = 'mp_m_fibsec_01',
        defaultFemale = 's_f_m_fembarber',
        gradeMale = {
            [0] = 'mp_m_fibsec_01',
            [1] = 'mp_m_fibsec_01',
            [2] = 'mp_m_fibsec_01',
            [3] = 's_m_m_fiboffice_02',
            [4] = 's_m_m_fiboffice_02',
            [5] = 's_m_m_fiboffice_01',
            [6] = 's_m_m_fiboffice_01',
            [7] = 's_m_m_fiboffice_01',
        },
        gradeFemale = {
            [0] = 's_f_m_fembarber',
            [1] = 's_f_m_fembarber',
            [2] = 's_f_m_fembarber',
            [3] = 's_f_m_fembarber',
            [4] = 's_f_m_fembarber',
            [5] = 's_f_m_fembarber',
            [6] = 's_f_m_fembarber',
            [7] = 's_f_m_fembarber',
        },
        options = {
            { key = 'tactical', label = 'Agent Operativ Tactic', male = 'mp_m_fibsec_01', female = 's_f_y_cop_01', minGrade = 0 },
            { key = 'agent', label = 'Agent Special Costum', male = 's_m_m_fiboffice_02', female = 's_f_m_fembarber', minGrade = 1 },
            { key = 'raid', label = 'Black Ops Raid Tactic', male = 's_m_y_blackops_01', female = 's_f_y_cop_01', minGrade = 3 },
            { key = 'director', label = 'Director / Executive SAC', male = 's_m_m_fiboffice_01', female = 's_f_m_fembarber', minGrade = 4 },
        },
    },
    medic = {
        label = 'Pillbox EMS',
        defaultMale = 's_m_m_paramedic_01',
        defaultFemale = 's_f_y_scrubs_01',
        gradeMale = {
            [0] = 's_m_m_paramedic_01',
            [1] = 's_m_m_paramedic_01',
            [2] = 's_m_m_paramedic_01',
            [3] = 's_m_m_paramedic_01',
            [4] = 's_m_m_paramedic_01',
            [5] = 's_m_m_doctor_01',
            [6] = 's_m_m_doctor_01',
            [7] = 's_m_m_doctor_01',
        },
        gradeFemale = {
            [0] = 's_f_y_scrubs_01',
            [1] = 's_f_y_scrubs_01',
            [2] = 's_f_y_scrubs_01',
            [3] = 's_f_y_scrubs_01',
            [4] = 's_f_y_scrubs_01',
            [5] = 's_f_y_scrubs_01',
            [6] = 's_f_y_scrubs_01',
            [7] = 's_f_y_scrubs_01',
        },
        options = {
            { key = 'paramedic', label = 'Paramedic Ambulanță', male = 's_m_m_paramedic_01', female = 's_f_y_scrubs_01', minGrade = 0 },
            { key = 'doctor', label = 'Medic / Chirurg Halat Alb', male = 's_m_m_doctor_01', female = 's_f_y_scrubs_01', minGrade = 3 },
        },
    },
    lsfd = {
        label = 'LS Fire Department',
        defaultMale = 's_m_y_fireman_01',
        defaultFemale = 's_m_y_fireman_01',
        gradeMale = {
            [0] = 's_m_y_fireman_01',
            [1] = 's_m_y_fireman_01',
            [2] = 's_m_y_fireman_01',
            [3] = 's_m_y_fireman_01',
            [4] = 's_m_y_fireman_01',
            [5] = 's_m_y_fireman_01',
            [6] = 's_m_y_fireman_01',
            [7] = 's_m_y_fireman_01',
        },
        gradeFemale = {
            [0] = 's_m_y_fireman_01',
            [1] = 's_m_y_fireman_01',
            [2] = 's_m_y_fireman_01',
            [3] = 's_m_y_fireman_01',
            [4] = 's_m_y_fireman_01',
            [5] = 's_m_y_fireman_01',
            [6] = 's_m_y_fireman_01',
            [7] = 's_m_y_fireman_01',
        },
        options = {
            { key = 'fireman', label = 'Pompier Bunker Gear', male = 's_m_y_fireman_01', female = 's_m_y_fireman_01', minGrade = 0 },
            { key = 'paramedic', label = 'Paramedic / Prim Ajutor', male = 's_m_m_paramedic_01', female = 's_f_y_scrubs_01', minGrade = 2 },
        },
    },
    mechanic = {
        label = 'LS Customs',
        defaultMale = 'mp_m_waremech_01',
        defaultFemale = 'mp_m_waremech_01',
        gradeMale = {
            [0] = 'mp_m_waremech_01',
            [1] = 'mp_m_waremech_01',
            [2] = 'mp_m_waremech_01',
            [3] = 'mp_m_waremech_01',
            [4] = 's_m_y_xmech_01',
            [5] = 's_m_y_xmech_01',
            [6] = 's_m_y_xmech_01',
            [7] = 's_m_y_xmech_01',
        },
        gradeFemale = {
            [0] = 'mp_m_waremech_01',
            [1] = 'mp_m_waremech_01',
            [2] = 's_f_y_migrant_01',
            [3] = 's_f_y_migrant_01',
            [4] = 's_f_y_migrant_01',
            [5] = 's_f_y_migrant_01',
            [6] = 's_f_y_migrant_01',
            [7] = 's_f_y_migrant_01',
        },
        options = {
            { key = 'mechanic', label = 'Mecanic Salopetă Garaj', male = 'mp_m_waremech_01', female = 'mp_m_waremech_01', minGrade = 0 },
            { key = 'tuner', label = 'Mecanic Tuner / Custom', male = 's_m_y_xmech_01', female = 's_f_y_migrant_01', minGrade = 1 },
            { key = 'heavy', label = 'Mecanic Heavy / Tractări', male = 's_m_m_dockwork_01', female = 's_f_y_migrant_01', minGrade = 2 },
        },
    },
    taxi = {
        label = 'Downtown Cab Co.',
        defaultMale = 'a_m_y_stlat_01',
        defaultFemale = 'a_f_y_smartcaspat_01',
        gradeMale = {
            [0] = 'a_m_y_stlat_01',
            [1] = 'a_m_y_stlat_01',
            [2] = 'a_m_y_stlat_01',
            [3] = 'a_m_y_smartcaspat_01',
            [4] = 'a_m_y_smartcaspat_01',
            [5] = 'a_m_y_smartcaspat_01',
            [6] = 'ig_chengsr',
            [7] = 'ig_chengsr',
        },
        gradeFemale = {
            [0] = 'a_f_y_smartcaspat_01',
            [1] = 'a_f_y_smartcaspat_01',
            [2] = 'a_f_y_smartcaspat_01',
            [3] = 'a_f_y_smartcaspat_01',
            [4] = 'a_f_y_smartcaspat_01',
            [5] = 'a_f_y_smartcaspat_01',
            [6] = 'a_f_y_smartcaspat_01',
            [7] = 'a_f_y_smartcaspat_01',
        },
        options = {
            { key = 'driver', label = 'Șofer Taxi Clasic', male = 'a_m_y_stlat_01', female = 'a_f_y_smartcaspat_01', minGrade = 0 },
            { key = 'executive', label = 'Șofer Executiv / Limuzină', male = 'a_m_y_smartcaspat_01', female = 'a_f_y_smartcaspat_01', minGrade = 2 },
            { key = 'manager', label = 'Manager Flotă', male = 'ig_chengsr', female = 'a_f_y_smartcaspat_01', minGrade = 4 },
        },
    },
    lssi = {
        label = 'LSSI — License & Safety',
        defaultMale = 's_m_m_highsec_02',
        defaultFemale = 'a_f_y_business_02',
        gradeMale = {
            [0] = 's_m_m_highsec_02',
            [1] = 's_m_m_highsec_02',
            [2] = 's_m_m_highsec_02',
            [3] = 's_m_m_highsec_02',
            [4] = 'a_m_y_business_01',
            [5] = 'a_m_y_business_01',
            [6] = 'a_m_y_business_01',
            [7] = 'a_m_y_business_01',
        },
        gradeFemale = {
            [0] = 'a_f_y_business_02',
            [1] = 'a_f_y_business_02',
            [2] = 'a_f_y_business_02',
            [3] = 'a_f_y_business_02',
            [4] = 'a_f_y_business_02',
            [5] = 'a_f_y_business_02',
            [6] = 'a_f_y_business_02',
            [7] = 'a_f_y_business_02',
        },
        options = {
            { key = 'inspector', label = 'Instructor Rutier / Uniformă', male = 's_m_m_highsec_02', female = 'a_f_y_business_02', minGrade = 0 },
            { key = 'examiner', label = 'Examinator Oficial Costum', male = 'a_m_y_business_01', female = 'a_f_y_business_02', minGrade = 2 },
        },
    },
    sunset_cartel = {
        label = 'Sunset Cartel',
        defaultMale = 'g_m_y_mexgoon_01',
        defaultFemale = 'g_f_y_vagos_01',
        gradeMale = {
            [0] = 'g_m_y_mexgoon_01',
            [1] = 'g_m_y_mexgoon_01',
            [2] = 'g_m_y_mexgoon_01',
            [3] = 'g_m_y_mexgoon_02',
            [4] = 'g_m_y_mexgoon_02',
            [5] = 'g_m_m_mexboss_01',
            [6] = 'ig_ortega',
            [7] = 'ig_ortega',
        },
        gradeFemale = {
            [0] = 'g_f_y_vagos_01',
            [1] = 'g_f_y_vagos_01',
            [2] = 'g_f_y_vagos_01',
            [3] = 'g_f_y_vagos_01',
            [4] = 'g_f_y_vagos_01',
            [5] = 'g_f_y_vagos_01',
            [6] = 'g_f_y_vagos_01',
            [7] = 'g_f_y_vagos_01',
        },
        options = {
            { key = 'sicario', label = 'Sicario Cartel Tatuat', male = 'g_m_y_mexgoon_01', female = 'g_f_y_vagos_01', minGrade = 0 },
            { key = 'enforcer', label = 'Soldat Cartel Tactic', male = 'g_m_y_mexgoon_02', female = 'g_f_y_vagos_01', minGrade = 2 },
            { key = 'lieutenant', label = 'Locotenent Senior', male = 'g_m_m_mexboss_01', female = 'g_f_y_vagos_01', minGrade = 3 },
            { key = 'patron', label = 'Patrón / Lider Cartel', male = 'ig_ortega', female = 'g_f_y_vagos_01', minGrade = 5 },
        },
    },
    night_syndicate = {
        label = 'Night Syndicate',
        defaultMale = 'g_m_y_armgoon_02',
        defaultFemale = 'g_f_y_ballas_01',
        gradeMale = {
            [0] = 'g_m_y_armgoon_02',
            [1] = 'g_m_y_armgoon_02',
            [2] = 'g_m_y_armgoon_02',
            [3] = 'g_m_m_armgoon_01',
            [4] = 'g_m_m_armgoon_01',
            [5] = 'g_m_y_korean_01',
            [6] = 'g_m_y_korean_01',
            [7] = 'g_m_y_korean_01',
        },
        gradeFemale = {
            [0] = 'g_f_y_ballas_01',
            [1] = 'g_f_y_ballas_01',
            [2] = 'g_f_y_ballas_01',
            [3] = 'g_f_y_ballas_01',
            [4] = 'g_f_y_ballas_01',
            [5] = 'g_f_y_ballas_01',
            [6] = 'g_f_y_ballas_01',
            [7] = 'g_f_y_ballas_01',
        },
        options = {
            { key = 'runner', label = 'Street Enforcer Geacă Piele', male = 'g_m_y_armgoon_02', female = 'g_f_y_ballas_01', minGrade = 0 },
            { key = 'captain', label = 'Căpitan Sindicat Mafiot', male = 'g_m_m_armgoon_01', female = 'g_f_y_ballas_01', minGrade = 2 },
            { key = 'don', label = 'Don Sindicat / Boss', male = 'g_m_y_korean_01', female = 'g_f_y_ballas_01', minGrade = 4 },
        },
    },
}

function Sunset.ResolveFactionSkin(factionId, grade, gender)
    local def = Sunset.FactionSkins[factionId]
    if not def then return nil end
    grade = tonumber(grade) or 0
    gender = tonumber(gender) or 0
    local isFemale = gender == 1
    local gradeTable = isFemale and def.gradeFemale or def.gradeMale
    local skin = gradeTable and gradeTable[grade]
    if not skin then
        skin = isFemale and def.defaultFemale or def.defaultMale
    end
    return skin
end

function Sunset.GetFactionSkinOptions(factionId, grade, gender)
    local def = Sunset.FactionSkins[factionId]
    if not def or not def.options then return {} end
    grade = tonumber(grade) or 0
    gender = tonumber(gender) or 0
    local isFemale = gender == 1
    local list = {}
    for _, opt in ipairs(def.options) do
        local minG = opt.minGrade or 0
        if grade >= minG then
            list[#list + 1] = {
                index = #list + 1,
                key = opt.key,
                label = opt.label,
                model = isFemale and opt.female or opt.male,
                minGrade = minG,
            }
        end
    end
    return list
end
