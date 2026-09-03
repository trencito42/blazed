Sunset = Sunset or {}

Sunset.Config = {
    ServerName = 'SunsetMP',
    MaxCharacters = 3,
    DefaultSpawn = vector4(-1037.58, -2737.58, 20.17, 328.0),
    StartingCash = 500,
    StartingBank = 2500,
    Debug = true,

    -- Economy
    PaydayInterval = 45 * 60, -- seconds
    TaxRate = 0.05, -- 5% on bank payday deposits

    -- Survival
    HungerDrain = 0.8,  -- per minute
    ThirstDrain = 1.2,
    StressDrain = 0.1,
    StarvationDamage = 5,

    -- Inventory
    MaxWeight = 30.0,
    MaxSlots = 30,

    -- Death
    RespawnDelay = 5000, -- ms
    HospitalBill = 250,

    -- Save
    SaveInterval = 60, -- seconds
}

Sunset.Jobs = {
    unemployed = { label = 'Unemployed', grades = { [0] = { label = 'Freelancer', salary = 0 } } },
    taxi = { label = 'Taxi Driver', grades = { [0] = { label = 'Driver', salary = 150 } } },
    mechanic = { label = 'Mechanic', grades = { [0] = { label = 'Apprentice', salary = 200 } } },
    police = { label = 'Police', grades = { [0] = { label = 'Cadet', salary = 350 } } },
    medic = { label = 'EMS', grades = { [0] = { label = 'Paramedic', salary = 300 } } },
}

Sunset.Nationalities = {
    'Romanian', 'American', 'British', 'French', 'German', 'Italian', 'Spanish', 'Russian', 'Turkish', 'Other'
}
