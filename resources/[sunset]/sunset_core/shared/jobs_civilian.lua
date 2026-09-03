Sunset = Sunset or {}

--- Civilian jobs (Job Center) — separate from factions (LSPD, EMS, gangs...)
Sunset.CivilianJobs = {
    unemployed = {
        label = 'Unemployed',
        type = 'civilian',
        grades = { [0] = { label = 'Freelancer', salary = 0, perms = {} } },
    },
    trucker = {
        label = 'Trucker',
        type = 'civilian',
        description = 'Haul cargo across San Andreas. Depot at the docks.',
        grades = { [0] = { label = 'Driver', salary = 150, perms = {} } },
    },
    garbage = {
        label = 'Garbage Collector',
        type = 'civilian',
        description = 'Collect bins on city routes and unload at the depot.',
        grades = { [0] = { label = 'Collector', salary = 130, perms = {} } },
    },
    courier = {
        label = 'Courier',
        type = 'civilian',
        description = 'Pick up packages and deliver them on foot.',
        grades = { [0] = { label = 'Runner', salary = 110, perms = {} } },
    },
    fisherman = {
        label = 'Fisherman',
        type = 'civilian',
        description = 'Fish at coastal spots and sell your catch.',
        grades = { [0] = { label = 'Angler', salary = 120, perms = {} } },
    },
    mechanic = {
        label = 'Roadside Mechanic',
        type = 'civilian',
        description = 'Respond to /service mechanic calls and repair vehicles.',
        grades = { [0] = { label = 'Apprentice', salary = 140, perms = {} } },
    },
}
