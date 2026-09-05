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
    RespectPerPayday = 1,
    LevelRespectMultiplier = 4, -- level 1->2 costs 4 RP, 2->3 costs 8 RP
    LevelPriceBase = 2500, -- level 1->2 costs $2,500, then scales with level

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
    HospitalSpawn = vector4(298.0, -584.0, 43.28, 70.0), -- Pillbox exterior (lobby IPL not walkable)

    -- Save
    SaveInterval = 60, -- seconds

    -- Fuel ($ per 1% tank; $ per liter for gas can fills at pump)
    FuelPricePerPercent = 1.75,
    FuelPricePerLiter = 2.92,
    -- Pump flow (liters/sec). 60L sedan @ 3.0 L/s ≈ 20s empty→full; 20L can @ 2.5 L/s ≈ 8s.
    FuelFlowLitersPerSecond = 3.0,
    GasCanFlowLitersPerSecond = 2.5,
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
