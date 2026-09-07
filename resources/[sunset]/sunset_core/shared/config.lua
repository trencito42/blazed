Sunset = Sunset or {}

Sunset.Brand = {
    ServerName = 'blaze.mp',
    DisplayName = 'Blaze MP',
    CurrencyShort = 'BP',
    CurrencyName = 'Blaze Points',
    PassName = 'Blaze Pass',
}

Sunset.Config = {
    ServerName = Sunset.Brand.ServerName,
    MaxCharacters = 1,
    DefaultSpawn = vector4(-1037.58, -2737.58, 20.17, 328.0),
    StartingCash = 250,
    StartingBank = 1000,
    Debug = false,

    -- Economy
    PaydayInterval = 60 * 60, -- hourly SA:MP-style payday
    TaxRate = 0.08, -- 8% on bank payday deposits
    RespectPerPayday = 1,
    LevelRespectMultiplier = 4, -- level 1->2 costs 4 RP, 2->3 costs 8 RP
    LevelPriceBase = 3000, -- level 1->2 costs $3,000, then scales with level

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
    HospitalBill = 400,
    HospitalSpawn = vector4(298.0, -584.0, 43.28, 70.0), -- Pillbox exterior (lobby IPL not walkable)

    -- Save
    SaveInterval = 60, -- seconds

    -- Fuel ($ per 1% tank; $ per liter for gas can fills at pump)
    FuelPricePerPercent = 2.25,
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
