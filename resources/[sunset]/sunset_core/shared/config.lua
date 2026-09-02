Sunset = Sunset or {}

Sunset.Config = {
    ServerName = 'SunsetMP',
    MaxCharacters = 3,
    DefaultSpawn = vector4(-1037.58, -2737.58, 20.17, 328.0), -- LSIA
    StartingCash = 500,
    StartingBank = 2500,
    Debug = true,
}

Sunset.Jobs = {
    unemployed = { label = 'Șomer', grades = { [0] = { label = 'Freelancer', salary = 0 } } },
    taxi = { label = 'Taximetrist', grades = { [0] = { label = 'Șofer', salary = 150 } } },
    mechanic = { label = 'Mecanic', grades = { [0] = { label = 'Ucenic', salary = 200 } } },
    police = { label = 'Poliție', grades = { [0] = { label = 'Cadet', salary = 350 } } },
    medic = { label = 'EMS', grades = { [0] = { label = 'Paramedic', salary = 300 } } },
}

Sunset.Nationalities = {
    'Romanian', 'American', 'British', 'French', 'German', 'Italian', 'Spanish', 'Russian', 'Turkish', 'Other'
}
