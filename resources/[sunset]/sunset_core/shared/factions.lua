Sunset = Sunset or {}

-- type: legal | illegal
-- duty: must clock in at HQ for faction abilities + full salary
Sunset.Factions = {
    police = {
        label = 'LSPD',
        type = 'legal',
        factionType = 'law_enforcement',
        description = 'Los Santos Police Department — patrol, enforce the law, and protect citizens.',
        society = 'police',
        duty = true,
        hq = vector3(441.15, -981.95, 30.69),
        hqHint = '[E] LSPD — join / toggle duty',
        blip = { sprite = 60, color = 29, scale = 0.9 },
        marker = { 0, 100, 200 },
        depot = {
            label = 'MRPD Fleet Garage',
            coords = vector3(452.12, -1017.35, 28.45),
            spawn = vector4(438.42, -1018.30, 28.75, 90.0),
            vehicle = 'police',
            platePrefix = 'LSPD',
        },
        loadout = {
            armor = 100,
            male = {
                [1] = { drawable = 0, texture = 0 },
                [3] = { drawable = 0, texture = 0 },
                [4] = { drawable = 35, texture = 0 },
                [6] = { drawable = 25, texture = 0 },
                [8] = { drawable = 58, texture = 0 },
                [11] = { drawable = 55, texture = 0 },
            },
            female = {
                [1] = { drawable = 0, texture = 0 },
                [3] = { drawable = 0, texture = 0 },
                [4] = { drawable = 34, texture = 0 },
                [6] = { drawable = 25, texture = 0 },
                [8] = { drawable = 35, texture = 0 },
                [11] = { drawable = 48, texture = 0 },
            },
            weapons = {
                { weapon = 'WEAPON_NIGHTSTICK', ammo = 0 },
                { weapon = 'WEAPON_FLASHLIGHT', ammo = 0 },
                { weapon = 'WEAPON_STUNGUN', ammo = 0 },
                { weapon = 'WEAPON_COMBATPISTOL', ammo = 90 },
            },
            gradeWeapons = {
                [2] = {
                    { weapon = 'WEAPON_CARBINERIFLE', ammo = 120 },
                    { weapon = 'WEAPON_PUMPSHOTGUN', ammo = 24 },
                },
            },
        },
        grades = {
            [0] = { label = 'Cadet', salary = 400, perms = { cuff = true, uncuff = true, escort = true, frisk = true, members = true } },
            [1] = { label = 'Officer', salary = 550, perms = { cuff = true, uncuff = true, escort = true, vehicle_detain = true, frisk = true, fine = true, ticket = true, wanted = true, arrest = true, backup = true, mdc = true, megaphone = true, radar = true, confiscate = true, members = true } },
            [2] = { label = 'Sergeant', salary = 700, perms = { cuff = true, uncuff = true, escort = true, vehicle_detain = true, frisk = true, fine = true, ticket = true, wanted = true, clear_wanted = true, arrest = true, backup = true, mdc = true, megaphone = true, radar = true, confiscate = true, invite = true, members = true } },
            [3] = { label = 'Lieutenant', salary = 900, perms = { cuff = true, uncuff = true, escort = true, vehicle_detain = true, frisk = true, fine = true, ticket = true, wanted = true, clear_wanted = true, arrest = true, backup = true, mdc = true, megaphone = true, radar = true, confiscate = true, invite = true, giverank = true, fwarn = true, fmotd = true, members = true } },
            [4] = { label = 'Chief', salary = 1200, perms = { cuff = true, uncuff = true, escort = true, vehicle_detain = true, frisk = true, fine = true, ticket = true, wanted = true, clear_wanted = true, arrest = true, backup = true, mdc = true, megaphone = true, radar = true, confiscate = true, invite = true, promote = true, giverank = true, uninvite = true, fwarn = true, fmotd = true, members = true } },
        },
    },
    medic = {
        label = 'Pillbox EMS',
        type = 'legal',
        factionType = 'ems',
        description = 'Emergency medical services — heal, revive, and stabilize patients at Pillbox.',
        society = 'medic',
        duty = true,
        hq = vector3(298.0, -584.0, 43.28),
        hqHint = '[E] Pillbox EMS — join / toggle duty (exterior)',
        blip = { sprite = 61, color = 1, scale = 0.9 },
        marker = { 255, 50, 50 },
        depot = {
            label = 'EMS Ambulance Bay',
            coords = vector3(294.58, -574.35, 43.18),
            spawn = vector4(294.58, -574.35, 43.18, 70.0),
            vehicle = 'ambulance',
            platePrefix = 'EMS',
        },
        grades = {
            [0] = { label = 'Trainee', salary = 350, perms = { stabilize = true } },
            [1] = { label = 'Paramedic', salary = 500, perms = { stabilize = true, heal = true, revive = true } },
            [2] = { label = 'Doctor', salary = 650, perms = { stabilize = true, heal = true, revive = true, invite = true } },
            [3] = { label = 'Surgeon', salary = 800, perms = { stabilize = true, heal = true, revive = true, invite = true } },
            [4] = { label = 'Chief Medical', salary = 1000, perms = { stabilize = true, heal = true, revive = true, invite = true, promote = true } },
        },
    },
    taxi = {
        label = 'Downtown Cab Co.',
        type = 'legal',
        factionType = 'transport',
        description = 'City taxi service — pick up passengers via the Downtown Cab phone app or manual fares.',
        society = 'taxi',
        duty = true,
        hq = vector3(903.32, -170.14, 74.08),
        hqHint = '[E] Downtown Cab — join / toggle duty',
        blip = { sprite = 198, color = 5, scale = 0.85 },
        marker = { 255, 200, 0 },
        depot = {
            label = 'Cab Depot',
            coords = vector3(916.45, -170.62, 74.08),
            spawn = vector4(916.45, -170.62, 74.08, 240.0),
            vehicle = 'taxi',
            platePrefix = 'CAB',
        },
        grades = {
            [0] = { label = 'Driver', salary = 180, perms = { fare = true } },
            [1] = { label = 'Senior Driver', salary = 250, perms = { fare = true } },
            [2] = { label = 'Dispatcher', salary = 320, perms = { fare = true, invite = true } },
            [3] = { label = 'Fleet Manager', salary = 400, perms = { fare = true, invite = true, promote = true } },
        },
    },
    mechanic = {
        label = 'LS Customs',
        type = 'legal',
        factionType = 'mechanic',
        description = 'Vehicle repair shop — fix cars at HQ or on the road for other players.',
        society = 'mechanic',
        duty = true,
        hq = vector3(-337.52, -136.57, 39.01),
        hqHint = '[E] LS Customs — repair in vehicle ($250) / join on foot',
        blip = { sprite = 446, color = 47, scale = 0.85 },
        marker = { 255, 140, 0 },
        depot = {
            label = 'Tow Fleet',
            coords = vector3(-356.20, -126.55, 39.01),
            spawn = vector4(-356.20, -126.55, 39.01, 70.0),
            vehicle = 'towtruck',
            platePrefix = 'LSC',
        },
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
        factionType = 'fire_rescue',
        description = 'Fire and rescue — field stabilization and extraction. Revive at Engineer rank and above.',
        society = 'lsfd',
        duty = true,
        hq = vector3(1194.82, -1464.01, 34.86),
        hqHint = '[E] LS Fire Department — join / toggle duty',
        blip = { sprite = 436, color = 1, scale = 0.85 },
        marker = { 255, 80, 0 },
        depot = {
            label = 'Fire Station Garage',
            coords = vector3(1200.45, -1465.80, 34.86),
            spawn = vector4(1200.45, -1465.80, 34.86, 0.0),
            vehicle = 'firetruk',
            platePrefix = 'LSFD',
        },
        grades = {
            [0] = { label = 'Probationary', salary = 300, perms = { stabilize = true } },
            [1] = { label = 'Firefighter', salary = 420, perms = { stabilize = true, heal = true } },
            [2] = { label = 'Engineer', salary = 550, perms = { stabilize = true, heal = true, revive = true, invite = true } },
            [3] = { label = 'Captain', salary = 750, perms = { stabilize = true, heal = true, revive = true, invite = true } },
            [4] = { label = 'Battalion Chief', salary = 950, perms = { stabilize = true, heal = true, revive = true, invite = true, promote = true } },
        },
    },
    sunset_cartel = {
        label = 'Sunset Cartel',
        type = 'illegal',
        factionType = 'criminal_org',
        description = 'Organized crime — craft at the lab, move product, stay off the radar.',
        society = 'sunset_cartel',
        duty = true,
        hq = vector3(1394.72, 1141.98, 114.33),
        hqHint = '[E] Cartel safehouse — members only',
        blip = { sprite = 84, color = 1, scale = 0.8 },
        marker = { 180, 0, 0 },
        stash = vector3(1392.10, 1144.20, 114.33),
        grades = {
            [0] = { label = 'Runner', salary = 0, perms = {} },
            [1] = { label = 'Soldier', salary = 0, perms = { craft_illegal = true, sell = true } },
            [2] = { label = 'Enforcer', salary = 0, perms = { craft_illegal = true, sell = true, invite = true } },
            [3] = { label = 'Underboss', salary = 0, perms = { craft_illegal = true, sell = true, invite = true } },
            [4] = { label = 'Boss', salary = 0, perms = { craft_illegal = true, sell = true, invite = true, promote = true } },
        },
    },
    night_syndicate = {
        label = 'Night Syndicate',
        type = 'illegal',
        factionType = 'criminal_org',
        description = 'Street syndicate — weapons bench, fencing stolen goods, crew operations.',
        society = 'night_syndicate',
        duty = true,
        hq = vector3(-1520.88, 849.55, 181.59),
        hqHint = '[E] Syndicate HQ — members only',
        blip = { sprite = 84, color = 40, scale = 0.8 },
        marker = { 80, 0, 120 },
        stash = vector3(-1517.40, 851.10, 181.59),
        grades = {
            [0] = { label = 'Associate', salary = 0, perms = {} },
            [1] = { label = 'Soldier', salary = 0, perms = { craft_illegal = true, fence = true } },
            [2] = { label = 'Capo', salary = 0, perms = { craft_illegal = true, fence = true, invite = true } },
            [3] = { label = 'Consigliere', salary = 0, perms = { craft_illegal = true, fence = true, invite = true } },
            [4] = { label = 'Don', salary = 0, perms = { craft_illegal = true, fence = true, invite = true, promote = true } },
        },
    },
}

-- Command reference shown in /faction and help (filtered by player perms at runtime)
Sunset.FactionCommandCatalog = {
    { perm = 'stabilize', cmd = '/stabilize [id]', desc = 'Stabilize a downed patient' },
    { perm = 'heal', cmd = '/heal [id]', desc = 'Treat injuries (self if no id)' },
    { perm = 'revive', cmd = '/revive [id]', desc = 'Revive a downed player' },
    { perm = 'repair', cmd = '/repairveh [id]', desc = 'Repair a player vehicle' },
    { perm = 'fare', cmd = '/fare [id] [amount]', desc = 'Charge a manual taxi fare' },
    { perm = 'sell', cmd = '/sellpouch', desc = 'Sell sealed pouches at HQ (Cartel)' },
    { perm = 'fence', cmd = '/fence', desc = 'Fence contraband at HQ (Syndicate)' },
    { perm = 'invite', cmd = '/finvite [id]', desc = 'Recruit unemployed player' },
    { perm = 'promote', cmd = '/fpromote [id] [grade]', desc = 'Promote a faction member' },
}

Sunset.IllegalSellPrices = {
    sunset_cartel = { item = 'sealed_pouch', price = 450, label = 'Sealed Pouch' },
    night_syndicate = {
        { item = 'shiv', price = 120, label = 'Shiv' },
        { item = 'ammo_9mm', price = 85, label = '9mm Ammo' },
        { item = 'lockpick', price = 40, label = 'Lockpick' },
    },
}

-- Jobs table: civilian + factions (payday, admin)
Sunset.Jobs = {}
for id, job in pairs(Sunset.CivilianJobs or {}) do
    Sunset.Jobs[id] = job
end
for id, faction in pairs(Sunset.Factions) do
    Sunset.Jobs[id] = {
        label = faction.label,
        type = faction.type,
        society = faction.society,
        duty = faction.duty,
        grades = faction.grades,
    }
end

function Sunset.GetFaction(jobId)
    return Sunset.Factions[jobId]
end

function Sunset.GetFactionGrade(jobId, grade)
    local f = Sunset.Factions[jobId]
    if not f then return nil end
    return f.grades[grade or 0]
end

function Sunset.GetFactionCommandsForGrade(jobId, grade)
    local list = {}
    for _, row in ipairs(Sunset.FactionCommandCatalog or {}) do
        if Sunset.HasFactionPerm(jobId, grade, row.perm) then
            list[#list + 1] = row
        end
    end
    list[#list + 1] = { cmd = '/duty', desc = 'Toggle on/off shift' }
    list[#list + 1] = { cmd = '/f [message]', desc = 'Faction radio chat' }
    list[#list + 1] = { cmd = '/leavefaction', desc = 'Leave your faction' }
    list[#list + 1] = { cmd = '/quitfaction', desc = 'Leave your faction (alias)' }
    if Sunset.FactionTypeMatches(jobId, 'law_enforcement') then
        list[#list + 1] = { cmd = '/pdgarage', desc = 'Spawn MRPD patrol vehicle (on duty)' }
        list[#list + 1] = { cmd = '/pd', desc = 'LSPD command list' }
        list[#list + 1] = { cmd = '/so [id]', desc = 'Summon nearby suspect' }
        list[#list + 1] = { cmd = '/wanted', desc = 'List active wanted players' }
        if Sunset.HasFactionPerm(jobId, grade, 'cuff') then
            list[#list + 1] = { cmd = '/cuff [id]', desc = 'Restrain a nearby suspect' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'uncuff') then
            list[#list + 1] = { cmd = '/uncuff [id]', desc = 'Remove a nearby suspect’s restraints' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'wanted') then
            list[#list + 1] = { cmd = '/su [id] [reason]', desc = 'Add a persisted wanted charge' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'arrest') then
            list[#list + 1] = { cmd = '/booking', desc = 'GPS to nearest arrest booking marker' }
            list[#list + 1] = { cmd = '/arrest [id]', desc = 'Book cuffed, wanted suspect at marker' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'escort') then
            list[#list + 1] = { cmd = '/escort [id]', desc = 'Drag/escort restrained suspect' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'vehicle_detain') then
            list[#list + 1] = { cmd = '/putinveh [id]', desc = 'Place suspect in a nearby vehicle' }
            list[#list + 1] = { cmd = '/takeout [id]', desc = 'Remove suspect from nearby vehicle' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'frisk') then
            list[#list + 1] = { cmd = '/frisk [id]', desc = 'Search suspect inventory' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'ticket') then
            list[#list + 1] = { cmd = '/ticket [id]', desc = 'Issue server-priced citation (UI)' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'mdc') then
            list[#list + 1] = { cmd = '/mdc', desc = 'Mobile data terminal' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'clear_wanted') then
            list[#list + 1] = { cmd = '/clear [id]', desc = 'Clear wanted status' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'confiscate') then
            list[#list + 1] = { cmd = '/confiscate [id]', desc = 'Confiscate configured contraband' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'radar') then
            list[#list + 1] = { cmd = '/startradar', desc = 'Activate speed radar' }
            list[#list + 1] = { cmd = '/stopradar', desc = 'Deactivate speed radar' }
            list[#list + 1] = { cmd = '/radars', desc = 'List fixed speed cameras' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'megaphone') then
            list[#list + 1] = { cmd = '/m [message]', desc = 'Megaphone (nearby)' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'backup') then
            list[#list + 1] = { cmd = '/backup', desc = 'Request LSPD backup' }
        end
    end
    if Sunset.HasFactionPerm(jobId, grade, 'fmotd') or Sunset.HasFactionPerm(jobId, grade, 'invite') then
        list[#list + 1] = { cmd = '/fmembers', desc = 'List online faction members' }
        list[#list + 1] = { cmd = '/fmotd [message]', desc = 'Set faction message of the day' }
    end
    if Sunset.HasFactionPerm(jobId, grade, 'fwarn') then
        list[#list + 1] = { cmd = '/fwarn [id] [reason]', desc = 'Issue faction warning' }
    end
    if Sunset.HasFactionPerm(jobId, grade, 'uninvite') then
        list[#list + 1] = { cmd = '/funinvite [id]', desc = 'Remove member from faction' }
    end
    return list
end
