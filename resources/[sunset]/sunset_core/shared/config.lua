Sunset = Sunset or {}

Sunset.Config = {
    ServerName = 'SunsetMP',
    MaxCharacters = 1,
    DefaultSpawn = vector4(-1037.58, -2737.58, 20.17, 328.0),
    StartingCash = 500,
    StartingBank = 2500,
    Debug = false,

    -- Economy
    PaydayInterval = 60 * 60, -- hourly SA:MP-style payday
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
    HospitalSpawn = vector4(311.18, -592.49, 43.28, 70.0), -- Pillbox

    -- Save
    SaveInterval = 60, -- seconds

    -- Fuel ($ per 1% tank)
    FuelPricePerPercent = 1.75,
    FuelFillRatePerSec = 0.22,
    FuelPumpReach = 4.2,

    -- Combat
    FriendlyFire = true,            -- players can damage other players (PvP)
    FactionFriendlyFire = false,    -- same faction members immune when both on duty
}

Sunset.Jobs = {
    unemployed = { label = 'Unemployed', type = 'civilian', grades = { [0] = { label = 'Freelancer', salary = 0, perms = {} } } },
}

Sunset.Nationalities = {
    'Romanian', 'American', 'British', 'French', 'German', 'Italian', 'Spanish', 'Russian', 'Turkish', 'Other'
}
