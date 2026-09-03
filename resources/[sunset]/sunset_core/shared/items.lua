Sunset = Sunset or {}

Sunset.Items = {
    water = { label = 'Water Bottle', weight = 0.2, usable = true, hunger = 0, thirst = 25 },
    bread = { label = 'Bread', weight = 0.2, usable = true, hunger = 20, thirst = 0 },
    burger = { label = 'Burger', weight = 0.3, usable = true, hunger = 35, thirst = -5 },
    phone = { label = 'Phone', weight = 0.1, usable = false },
    id_card = { label = 'ID Card', weight = 0.05, usable = false },
    driver_license = { label = 'Driver License', weight = 0.05, usable = false },
    repairkit = { label = 'Repair Kit', weight = 2.0, usable = true },
    bandage = { label = 'Bandage', weight = 0.1, usable = true, heal = 25 },
    cigarette = { label = 'Cigarette', weight = 0.05, usable = true, stress = -10 },
    lockpick = { label = 'Lockpick', weight = 0.2, usable = true },
    metal_scrap = { label = 'Metal Scrap', weight = 0.5, usable = false },
    plastic = { label = 'Plastic', weight = 0.15, usable = false },
    cloth = { label = 'Cloth', weight = 0.1, usable = false },
    chemicals = { label = 'Chemicals', weight = 0.3, usable = false },
    gunpowder = { label = 'Gunpowder', weight = 0.2, usable = false },
    sealed_pouch = { label = 'Sealed Pouch', weight = 0.15, usable = true, stress = -15 },
    shiv = { label = 'Shiv', weight = 0.3, usable = false },
    ammo_9mm = { label = '9mm Ammo', weight = 0.25, usable = false },
}

Sunset.Shops = {
    twentyfour7 = {
        label = '24/7 Store',
        coords = vector3(25.74, -1347.32, 29.50),
        items = {
            { item = 'water', price = 5 },
            { item = 'bread', price = 8 },
            { item = 'burger', price = 15 },
            { item = 'bandage', price = 25 },
            { item = 'cigarette', price = 12 },
            { item = 'metal_scrap', price = 15 },
            { item = 'plastic', price = 8 },
            { item = 'cloth', price = 10 },
            { item = 'chemicals', price = 35 },
        },
    },
    ammunation = {
        label = 'Ammunation',
        coords = vector3(22.56, -1106.24, 29.80),
        items = {
            { item = 'repairkit', price = 150 },
            { item = 'lockpick', price = 75 },
            { item = 'gunpowder', price = 45 },
        },
    },
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
        jobs = {
            { id = 'unemployed', label = 'Unemployed' },
            { id = 'taxi', label = 'Taxi Driver' },
            { id = 'mechanic', label = 'Mechanic' },
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
}
