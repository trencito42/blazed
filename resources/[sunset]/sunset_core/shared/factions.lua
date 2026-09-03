Sunset = Sunset or {}

-- type: legal | illegal
-- duty: must clock in at HQ for faction abilities + full salary
Sunset.Factions = {
    police = {
        label = 'LSPD',
        type = 'legal',
        society = 'police',
        duty = true,
        hq = vector3(441.15, -981.95, 30.69),
        blip = { sprite = 60, color = 29, scale = 0.9 },
        marker = { 0, 100, 200 },
        grades = {
            [0] = { label = 'Cadet', salary = 400, perms = {} },
            [1] = { label = 'Officer', salary = 550, perms = { cuff = true, fine = true } },
            [2] = { label = 'Sergeant', salary = 700, perms = { cuff = true, fine = true, invite = true } },
            [3] = { label = 'Lieutenant', salary = 900, perms = { cuff = true, fine = true, invite = true } },
            [4] = { label = 'Chief', salary = 1200, perms = { cuff = true, fine = true, invite = true, promote = true } },
        },
    },
    medic = {
        label = 'Pillbox EMS',
        type = 'legal',
        society = 'medic',
        duty = true,
        hq = vector3(307.12, -595.55, 43.28),
        blip = { sprite = 61, color = 1, scale = 0.9 },
        marker = { 255, 50, 50 },
        grades = {
            [0] = { label = 'Trainee', salary = 350, perms = { heal = true } },
            [1] = { label = 'Paramedic', salary = 500, perms = { heal = true, revive = true } },
            [2] = { label = 'Doctor', salary = 650, perms = { heal = true, revive = true, invite = true } },
            [3] = { label = 'Surgeon', salary = 800, perms = { heal = true, revive = true, invite = true } },
            [4] = { label = 'Chief Medical', salary = 1000, perms = { heal = true, revive = true, invite = true, promote = true } },
        },
    },
    taxi = {
        label = 'Downtown Cab Co.',
        type = 'legal',
        society = 'taxi',
        duty = true,
        hq = vector3(903.32, -170.14, 74.08),
        blip = { sprite = 198, color = 5, scale = 0.85 },
        marker = { 255, 200, 0 },
        grades = {
            [0] = { label = 'Driver', salary = 180, perms = { fare = true } },
            [1] = { label = 'Senior Driver', salary = 250, perms = { fare = true } },
            [2] = { label = 'Dispatcher', salary = 320, perms = { fare = true, invite = true } },
        },
    },
    mechanic = {
        label = 'LS Customs',
        type = 'legal',
        society = 'mechanic',
        duty = true,
        hq = vector3(-337.52, -136.57, 39.01),
        blip = { sprite = 446, color = 47, scale = 0.85 },
        marker = { 255, 140, 0 },
        grades = {
            [0] = { label = 'Apprentice', salary = 220, perms = { repair = true } },
            [1] = { label = 'Mechanic', salary = 320, perms = { repair = true } },
            [2] = { label = 'Foreman', salary = 450, perms = { repair = true, invite = true } },
            [3] = { label = 'Shop Manager', salary = 600, perms = { repair = true, invite = true, promote = true } },
        },
    },
    lsfd = {
        label = 'LS Fire Department',
        type = 'legal',
        society = 'lsfd',
        duty = true,
        hq = vector3(1194.82, -1464.01, 34.86),
        blip = { sprite = 436, color = 1, scale = 0.85 },
        marker = { 255, 80, 0 },
        grades = {
            [0] = { label = 'Probationary', salary = 300, perms = { heal = true } },
            [1] = { label = 'Firefighter', salary = 420, perms = { heal = true } },
            [2] = { label = 'Engineer', salary = 550, perms = { heal = true, invite = true } },
            [3] = { label = 'Captain', salary = 750, perms = { heal = true, invite = true, promote = true } },
        },
    },
    sunset_cartel = {
        label = 'Sunset Cartel',
        type = 'illegal',
        society = 'sunset_cartel',
        duty = true,
        hq = vector3(1394.72, 1141.98, 114.33),
        blip = { sprite = 84, color = 1, scale = 0.8 },
        marker = { 180, 0, 0 },
        grades = {
            [0] = { label = 'Runner', salary = 0, perms = {} },
            [1] = { label = 'Soldier', salary = 0, perms = { craft_illegal = true } },
            [2] = { label = 'Enforcer', salary = 0, perms = { craft_illegal = true, invite = true } },
            [3] = { label = 'Underboss', salary = 0, perms = { craft_illegal = true, invite = true, promote = true } },
            [4] = { label = 'Boss', salary = 0, perms = { craft_illegal = true, invite = true, promote = true } },
        },
    },
    night_syndicate = {
        label = 'Night Syndicate',
        type = 'illegal',
        society = 'night_syndicate',
        duty = true,
        hq = vector3(-1520.88, 849.55, 181.59),
        blip = { sprite = 84, color = 40, scale = 0.8 },
        marker = { 80, 0, 120 },
        grades = {
            [0] = { label = 'Associate', salary = 0, perms = {} },
            [1] = { label = 'Soldier', salary = 0, perms = { craft_illegal = true } },
            [2] = { label = 'Capo', salary = 0, perms = { craft_illegal = true, invite = true } },
            [3] = { label = 'Consigliere', salary = 0, perms = { craft_illegal = true, invite = true, promote = true } },
            [4] = { label = 'Don', salary = 0, perms = { craft_illegal = true, invite = true, promote = true } },
        },
    },
}

-- Mirror into Jobs for payday / HUD compatibility
for id, faction in pairs(Sunset.Factions) do
    Sunset.Jobs[id] = {
        label = faction.label,
        type = faction.type,
        society = faction.society,
        duty = faction.duty,
        grades = faction.grades,
    }
end

Sunset.Jobs.unemployed = Sunset.Jobs.unemployed or {
    label = 'Unemployed',
    type = 'civilian',
    grades = { [0] = { label = 'Freelancer', salary = 0, perms = {} } },
}

function Sunset.GetFaction(jobId)
    return Sunset.Factions[jobId]
end

function Sunset.GetFactionGrade(jobId, grade)
    local f = Sunset.Factions[jobId]
    if not f then return nil end
    return f.grades[grade or 0]
end

function Sunset.HasFactionPerm(jobId, grade, perm)
    local g = Sunset.GetFactionGrade(jobId, grade)
    if not g or not g.perms then return false end
    return g.perms[perm] == true
end
