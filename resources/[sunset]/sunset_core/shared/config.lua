Sunset = Sunset or {}

Sunset.Config = {
    ServerName = 'SunsetMP',
    MaxCharacters = 1,
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
    unemployed = { label = 'Unemployed', type = 'civilian', grades = { [0] = { label = 'Freelancer', salary = 0, perms = {} } } },
}

Sunset.Nationalities = {
    'Romanian', 'American', 'British', 'French', 'German', 'Italian', 'Spanish', 'Russian', 'Turkish', 'Other'
}
