Sunset = Sunset or {}

local FISHING_ROD_EQUIP = {
    model = 'prop_fishing_rod_01',
    anim = { dict = 'amb@world_human_stand_fishing@idle_a', name = 'idle_c', flag = 49 },
}

Sunset.Items = {
    -- `icon` is a basename from sunset_ui/web/assets/items (never an emoji).
    water = { label = 'Water Bottle', weight = 0.2, usable = true, hunger = 0, thirst = 25, category = 'drinks', icon = 'water_bottle' },
    bread = { label = 'Bread', weight = 0.2, usable = true, hunger = 20, thirst = 0, category = 'food', icon = 'bread' },
    burger = { label = 'Burger', weight = 0.3, usable = true, hunger = 35, thirst = -5, category = 'food', icon = 'burger' },
    phone = { label = 'Phone', weight = 0.1, usable = false, category = 'misc', icon = 'phone' },
    id_card = { label = 'ID Card', weight = 0.05, usable = false, category = 'misc', icon = 'id_card' },
    driver_license = { label = 'Driver License', weight = 0.05, usable = false, category = 'misc', icon = 'driver_license' },
    repairkit = { label = 'Repair Kit', weight = 2.0, usable = true, category = 'tools', icon = 'repairkit' },
    bandage = { label = 'Bandage', weight = 0.1, usable = true, heal = 25, category = 'medical', icon = 'bandage' },
    cigarette = { label = 'Cigarette', weight = 0.05, usable = true, stress = -10, category = 'supplies', icon = 'cigarette_pack' },
    lockpick = { label = 'Lockpick', weight = 0.2, usable = true, category = 'tools', icon = 'lockpick' },
    metal_scrap = { label = 'Metal Scrap', weight = 0.5, usable = false, category = 'materials', icon = 'metalscrap' },
    plastic = { label = 'Plastic', weight = 0.15, usable = false, category = 'materials', icon = 'plastic' },
    cloth = { label = 'Cloth', weight = 0.1, usable = false, category = 'materials', icon = 'cloth' },
    chemicals = { label = 'Chemicals', weight = 0.3, usable = false, category = 'materials', icon = 'acetone' },
    gunpowder = { label = 'Gunpowder', weight = 0.2, usable = false, category = 'ammo', icon = 'ammo_box_empty' },
    sealed_pouch = { label = 'Sealed Pouch', weight = 0.15, usable = true, stress = -15, category = 'supplies', icon = 'filled_evidence_bag' },
    shiv = { label = 'Shiv', weight = 0.3, usable = false, weapon = 'WEAPON_SWITCHBLADE', category = 'tools', icon = 'weapon_trigger' },
    gas_can = { label = 'Gas Can', weight = 3.0, usable = true, maxLiters = 20, category = 'tools', icon = 'jerry_can' },
    fresh_fish    = { label = 'Fresh Fish',      weight = 0.8,  usable = false, category = 'food',    icon = 'cooked_fish' },
    -- Typed fish (caught with new rarity system) — heavier rarity = more bag space used
    fish_common   = { label = 'Common Fish',     weight = 0.8,  usable = false, category = 'food',    icon = 'cooked_fish' },
    fish_uncommon = { label = 'Uncommon Fish',   weight = 1.2,  usable = false, category = 'food',    icon = 'cooked_fish' },
    fish_rare     = { label = 'Rare Fish',        weight = 2.0,  usable = false, category = 'food',    icon = 'cooked_fish' },
    fish_epic     = { label = 'Epic Fish',        weight = 3.0,  usable = false, category = 'food',    icon = 'cooked_fish' },
    fish_legendary = { label = 'Legendary Fish', weight = 5.0,  usable = false, category = 'food',    icon = 'cooked_fish' },
    -- Fishing bait (consumabil la fiecare aruncare)
    bait_worm    = { label = 'Worm Bait',         weight = 0.05, usable = false, category = 'fishing', icon = 'bread' },
    bait_lure    = { label = 'Artificial Lure',   weight = 0.05, usable = false, category = 'fishing', icon = 'fishing_license' },
    bait_premium = { label = 'Premium Bait',      weight = 0.05, usable = false, category = 'fishing', icon = 'fishing_license' },
    -- Undita (upgrade sequential prin NPC, tradeable)
    fishing_rod_1 = { label = 'Fishing Rod Mk1', weight = 1.5,  usable = false, category = 'fishing', icon = 'fishing_rod', equipProp = FISHING_ROD_EQUIP },
    fishing_rod_2 = { label = 'Fishing Rod Mk2', weight = 1.5,  usable = false, category = 'fishing', icon = 'fishing_rod', equipProp = FISHING_ROD_EQUIP },
    fishing_rod_3 = { label = 'Fishing Rod Mk3', weight = 1.5,  usable = false, category = 'fishing', icon = 'fishing_rod', equipProp = FISHING_ROD_EQUIP },
    fishing_rod_4 = { label = 'Fishing Rod Mk4', weight = 1.5,  usable = false, category = 'fishing', icon = 'fishing_rod', equipProp = FISHING_ROD_EQUIP },
    fishing_rod_5 = { label = 'Fishing Rod Mk5', weight = 1.5,  usable = false, category = 'fishing', icon = 'fishing_rod', equipProp = FISHING_ROD_EQUIP },
    ammo_9mm = { label = '9mm Ammo', weight = 0.25, usable = false, category = 'ammo', icon = 'pistol_ammo' },
    stolen_silver_watch = { label = 'Stolen Silver Watch', weight = 0.4, usable = false, category = 'misc', icon = 'backpack' },
    stolen_luxury_watch = { label = 'Stolen Luxury Watch', weight = 0.45, usable = false, category = 'misc', icon = 'backpack' },
    stolen_gold_watch = { label = 'Stolen Gold Watch', weight = 0.45, usable = false, category = 'misc', icon = 'backpack' },
    stolen_diamond_watch = { label = 'Stolen Diamond Watch', weight = 0.5, usable = false, category = 'misc', icon = 'filled_evidence_bag' },
    stolen_collector_watch = { label = 'Stolen Collector Watch', weight = 0.55, usable = false, category = 'misc', icon = 'filled_evidence_bag' },
    stolen_bracelet = { label = 'Stolen Bracelet', weight = 0.25, usable = false, category = 'misc', icon = 'backpack' },
    stolen_gold_chain = { label = 'Stolen Gold Chain', weight = 0.3, usable = false, category = 'misc', icon = 'metalscrap' },
    stolen_gold_bracelet = { label = 'Stolen Gold Bracelet', weight = 0.3, usable = false, category = 'misc', icon = 'metalscrap' },
    stolen_diamond_jewelry = { label = 'Stolen Designer Jewelry', weight = 0.4, usable = false, category = 'misc', icon = 'filled_evidence_bag' },
}

Sunset.Shops = {
    -- fishing_supply handled by sunset_fishingshop (dedicated UI at Paleto)
    twentyfour7 = {
        label = '24/7 Store',
        coords = vector3(25.74, -1347.32, 29.50),
        items = {
            { item = 'water', price = 6 },
            { item = 'bread', price = 10 },
            { item = 'burger', price = 22 },
            { item = 'bandage', price = 35 },
            { item = 'cigarette', price = 14 },
            { item = 'metal_scrap', price = 18 },
            { item = 'plastic', price = 10 },
            { item = 'cloth', price = 12 },
            { item = 'chemicals', price = 42 },
            { item = 'gas_can', price = 55 },
        },
    },
    ammunation = {
        label = 'Ammunation',
        coords = vector3(22.56, -1106.24, 29.80),
        items = {
            { item = 'repairkit', price = 180 },
            { item = 'lockpick', price = 95 },
            { item = 'gunpowder', price = 52 },
        },
    },
}

-- Every purchasable 24/7 location (shared catalog; each row is a separate business).
Sunset.TwentyFourSevenStores = {
    { id = 'legion',      label = '24/7 - Legion Square',  coords = vector3(25.74,   -1347.32, 29.50), cashier = vector4(24.47,  -1347.38, 29.50, 270.0) },
    { id = 'strawberry',  label = '24/7 - Strawberry',     coords = vector3(-46.06,  -1757.88, 29.42), cashier = vector4(-47.52, -1758.66, 29.42, 45.0) },
    { id = 'littleseoul', label = '24/7 - Little Seoul',   coords = vector3(-707.12,  -913.43,  19.22), cashier = vector4(-706.06, -914.63, 19.22, 90.0) },
    { id = 'mirrorpark',  label = '24/7 - Mirror Park',    coords = vector3(1164.44,  -322.49,  69.21), cashier = vector4(1165.05, -323.68, 69.21, 100.0) },
    { id = 'vinewood',    label = '24/7 - Vinewood Hills', coords = vector3(548.46,   2671.72,  42.16), cashier = vector4(549.04,  2671.36, 42.16, 100.0) },
    { id = 'rockford',    label = '24/7 - Rockford Hills', coords = vector3(-3038.24,  584.19,   7.91), cashier = vector4(-3039.54, 584.75,  7.91,  20.0) },
    { id = 'sandy',       label = '24/7 - Sandy Shores',   coords = vector3(2678.55,  3279.25,  55.24), cashier = vector4(2679.95, 3280.55, 55.24, 0.0) },
    { id = 'paleto',      label = '24/7 - Paleto Bay',     coords = vector3(-54.37,   6244.70,  31.09), cashier = vector4(-51.87,  6244.40, 31.09, 315.0) },
}

Sunset.ATMs = {
    vector3(147.58, -1035.78, 29.34),
    vector3(-386.73, 6045.95, 31.50),
    vector3(-1205.02, -324.79, 37.86),
    vector3(-2962.58, 482.63, 15.70),
}

Sunset.Garages = {
    legion = {
        label = 'Legion Garage',
        spawn = vector4(215.12, -805.45, 30.81, 70.0),
        store = vector3(229.70, -800.11, 30.57),
    },
    airport = {
        label = 'LSIA Garage',
        spawn = vector4(-1034.62, -2733.41, 20.17, 328.0),
        store = vector3(-1025.0, -2725.0, 20.17),
    },
}

Sunset.GasStations = {
    {
        label = 'LTD Gasoline - Legion',
        coords = vector3(265.65, -1261.28, 29.14),
        pumps = {
            vector4(264.92, -1254.32, 29.14, 90.0),
            vector4(264.92, -1260.98, 29.14, 90.0),
            vector4(264.92, -1267.64, 29.14, 90.0),
        },
    },
    {
        label = 'Ron Gas - Grove St',
        coords = vector3(-70.21, -1761.79, 29.53),
        pumps = {
            vector4(-63.61, -1767.94, 29.12, 270.0),
            vector4(-61.18, -1760.46, 29.16, 270.0),
        },
    },
    {
        label = 'Xero Gas - Mirror Park',
        coords = vector3(1208.61, -1402.29, 35.22),
        pumps = {
            vector4(1204.84, -1400.85, 35.22, 90.0),
            vector4(1207.12, -1398.04, 35.22, 90.0),
        },
    },
    {
        label = 'LTD Gasoline - Vinewood',
        coords = vector3(621.07, 269.52, 103.09),
        pumps = {
            vector4(625.71, 269.95, 103.09, 270.0),
            vector4(618.42, 269.12, 103.09, 270.0),
        },
    },
    {
        label = 'Ron Gas - Paleto',
        coords = vector3(179.86, 6602.85, 31.86),
        pumps = {
            vector4(186.29, 6606.38, 32.05, 180.0),
            vector4(179.10, 6604.87, 32.05, 180.0),
        },
    },
    {
        label = 'Xero Gas - Sandy Shores',
        coords = vector3(2005.01, 3774.20, 32.18),
        pumps = {
            vector4(2001.52, 3772.28, 32.18, 120.0),
            vector4(2006.31, 3774.85, 32.18, 300.0),
        },
    },
    {
        label = 'LTD Gasoline - Route 68',
        coords = vector3(1039.34, 2671.78, 39.55),
        pumps = {
            vector4(1035.42, 2674.08, 39.55, 0.0),
            vector4(1042.14, 2674.55, 39.55, 0.0),
        },
    },
    {
        label = 'Ron Gas - Great Ocean',
        coords = vector3(-2554.85, 2334.40, 33.06),
        pumps = {
            vector4(-2552.14, 2334.48, 33.06, 240.0),
            vector4(-2558.92, 2336.01, 33.06, 60.0),
        },
    },
    {
        label = 'Xero Gas - LSIA',
        coords = vector3(-724.62, -935.16, 19.21),
        pumps = {
            vector4(-721.14, -938.86, 19.02, 0.0),
            vector4(-728.56, -938.86, 19.02, 0.0),
        },
    },
    {
        label = 'LTD Gasoline - Del Perro',
        coords = vector3(-1437.62, -276.74, 46.21),
        pumps = {
            vector4(-1435.12, -284.68, 46.21, 130.0),
            vector4(-1444.52, -274.22, 46.21, 310.0),
        },
    },
}

Sunset.ClothingShops = {
    vector3(72.25, -1399.10, 29.38),
    vector3(-703.78, -152.26, 37.42),
}

Sunset.BarberShops = {
    vector3(-814.31, -183.82, 37.57),
    vector3(136.78, -1708.40, 29.29),
}

Sunset.JobCenters = {
    cityhall = {
        label = 'Job Center',
        coords = vector3(-265.04, -963.62, 31.22),
        blip = { sprite = 407, color = 2, scale = 0.85 },
        -- Creator jobs are injected at runtime from sunset_jobcreator (published templates).
        jobs = {
            { id = 'unemployed', label = 'Unemployed' },
            { id = 'fisherman', label = 'Fisherman' },
            { id = 'mechanic', label = 'Roadside Mechanic' },
        },
    },
}

-- Blip presets for world map
Sunset.WorldBlips = {
    shop = { sprite = 52, color = 2, scale = 0.75 },
    atm = { sprite = 108, color = 2, scale = 0.65 },
    garage = { sprite = 357, color = 3, scale = 0.75 },
    clothing = { sprite = 73, color = 47, scale = 0.7 },
    barber = { sprite = 71, color = 47, scale = 0.7 },
    property = { sprite = 40, color = 5, scale = 0.75 },
    jobcenter = { sprite = 407, color = 2, scale = 0.85 },
    gas = { sprite = 361, color = 1, scale = 0.75 },
}
