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
        grades = { [0] = { label = 'Driver', salary = 180, perms = {} } },
        npcCoords = { x = 1208.77, y = -3114.84 },
    },
    garbage = {
        label = 'Garbage Collector',
        type = 'civilian',
        description = 'Collect bins on city routes and unload at the depot.',
        grades = { [0] = { label = 'Collector', salary = 160, perms = {} } },
        npcCoords = { x = -321.70, y = -1545.94 },
    },
    courier = {
        label = 'Courier',
        type = 'civilian',
        description = 'Pick up packages and deliver them on foot.',
        grades = { [0] = { label = 'Runner', salary = 140, perms = {} } },
        npcCoords = { x = 78.45, y = 112.22 },
    },
    fisherman = {
        label = 'Fisherman',
        type = 'civilian',
        description = 'Fish at coastal spots and sell your catch.',
        grades = { [0] = { label = 'Angler', salary = 150, perms = {} } },
        npcCoords = { x = -1593.23, y = 5207.74 },  -- Billy Ray
    },
    mechanic = {
        label = 'Roadside Mechanic',
        type = 'civilian',
        description = 'Respond to /service mechanic calls and repair vehicles.',
        grades = { [0] = { label = 'Apprentice', salary = 170, perms = {} } },
        npcCoords = { x = -347.45, y = -133.22 },
    },
    lockpicking = {
        label = 'Lockpicking',
        type = 'criminal',
        description = 'Skill for breaking into vehicles. Improves success rate when using a lockpick.',
        grades = { [0] = { label = 'Novice', salary = 0, perms = {} } },
    },
}
