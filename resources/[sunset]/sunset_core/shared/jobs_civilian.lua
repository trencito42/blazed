Sunset = Sunset or {}

-- Civilian jobs (Job Center) — separate from factions (LSPD, EMS, gangs...)
Sunset.CivilianJobs = {
    unemployed = {
        label = 'Unemployed',
        type = 'civilian',
        grades = { [0] = { label = 'Freelancer', salary = 0, perms = {} } },
    },
    trucker = {
        label = 'Trucker',
        type = 'civilian',
        description = 'Haul cargo across San Andreas. (Routes coming soon)',
        grades = { [0] = { label = 'Driver', salary = 150, perms = {} } },
    },
    fisherman = {
        label = 'Fisherman',
        type = 'civilian',
        description = 'Catch and sell fish. (Minigame coming soon)',
        grades = { [0] = { label = 'Angler', salary = 120, perms = {} } },
    },
}
