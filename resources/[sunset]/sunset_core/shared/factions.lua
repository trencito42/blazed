Sunset = Sunset or {}

local function ensureFactionBuilders()
    if type(Sunset.BuildLawEnforcementLoadout) == 'function'
        and type(Sunset.BuildLawEnforcementGrades) == 'function' then
        return
    end

    local function runCoreShared(path)
        local chunk = LoadResourceFile('sunset_core', path)
        if not chunk then return false end
        local fn, err = load(chunk, '@sunset_core/' .. path)
        if not fn then
            print(('[sunset_factions] Failed to load %s: %s'):format(path, tostring(err)))
            return false
        end
        fn()
        return true
    end

    runCoreShared('shared/faction_outfits.lua')
    runCoreShared('shared/faction_grades.lua')

    if type(Sunset.BuildLawEnforcementGrades) ~= 'function' then
        function Sunset.BuildLawEnforcementGrades(salaryScale)
            salaryScale = tonumber(salaryScale) or 1.0
            local grades = {}
            for grade = 0, 7 do
                grades[grade] = {
                    label = ('Grade %d'):format(grade),
                    salary = math.floor(450 * salaryScale * (grade + 1)),
                }
            end
            return grades
        end
    end

    if type(Sunset.BuildLawEnforcementLoadout) ~= 'function' then
        function Sunset.BuildLawEnforcementLoadout(_, vehicle)
            return {
                armor = 100,
                weapons = {},
                gradeOutfits = {},
                vehicle = vehicle,
            }
        end
    end
end

ensureFactionBuilders()

-- type: legal | illegal
-- duty: must clock in at HQ for faction abilities + full salary
Sunset.Factions = {
    police = {
        label = 'LSPD',
        applicationsOpen = true,
        weeklyReportTarget = 20,
        type = 'legal',
        factionType = 'law_enforcement',
        description = 'Los Santos Police Department — patrol, citations, and city-wide law enforcement.',
        society = 'police',
        duty = true,
        hq = vector3(441.15, -981.95, 30.69),
        hqHint = '[E] LSPD HQ — members: toggle duty | applications: Discord/site',
        blip = { sprite = 60, color = 29, scale = 0.9 },
        marker = { 0, 100, 200 },
        depot = {
            label = 'MRPD Fleet Garage',
            coords = vector3(452.12, -1017.35, 28.45),
            spawn = vector4(438.42, -1018.30, 28.75, 90.0),
            vehicle = 'police',
            platePrefix = 'LSPD',
        },
        loadout = Sunset.BuildLawEnforcementLoadout('lspd', 'police'),
        grades = Sunset.BuildLawEnforcementGrades(1.0),
    },
    sheriff = {
        label = 'San Andreas Sheriff',
        applicationsOpen = true,
        weeklyReportTarget = 18,
        type = 'legal',
        factionType = 'law_enforcement',
        robberyDispatch = true,
        description = 'County sheriff department — robbery response, warrants, and high-risk pursuits.',
        society = 'sheriff',
        duty = true,
        hq = vector3(361.89, -1592.35, 29.29),
        hqHint = '[E] Sheriff Station — members: toggle duty | robbery priority unit',
        blip = { sprite = 60, color = 46, scale = 0.9 },
        marker = { 160, 110, 40 },
        depot = {
            label = 'Sheriff Fleet Garage',
            coords = vector3(372.45, -1607.80, 29.29),
            spawn = vector4(372.45, -1607.80, 29.29, 230.0),
            vehicle = 'sheriff',
            platePrefix = 'SASD',
        },
        loadout = Sunset.BuildLawEnforcementLoadout('sheriff', 'sheriff2'),
        grades = Sunset.BuildLawEnforcementGrades(0.95),
    },
    fib = {
        label = 'FIB',
        applicationsOpen = true,
        weeklyReportTarget = 15,
        type = 'legal',
        factionType = 'law_enforcement',
        description = 'Federal Investigation Bureau — investigations, raids, and federal warrants.',
        society = 'fib',
        duty = true,
        hq = vector3(105.52, -745.12, 45.75),
        hqHint = '[E] FIB HQ — members: toggle duty | federal investigations',
        blip = { sprite = 60, color = 0, scale = 0.85 },
        marker = { 20, 20, 20 },
        depot = {
            label = 'FIB Motor Pool',
            coords = vector3(110.20, -736.40, 45.75),
            spawn = vector4(110.20, -736.40, 45.75, 160.0),
            vehicle = 'fbi',
            platePrefix = 'FIB',
        },
        loadout = Sunset.BuildLawEnforcementLoadout('fib', 'fbi2', {
            [4] = {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 180 },
                { weapon = 'WEAPON_SMG', ammo = 150 },
            },
            [5] = {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 210 },
                { weapon = 'WEAPON_SMG', ammo = 180 },
            },
            [6] = {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 240 },
                { weapon = 'WEAPON_SMG', ammo = 210 },
            },
            [7] = {
                { weapon = 'WEAPON_CARBINERIFLE', ammo = 270 },
                { weapon = 'WEAPON_SMG', ammo = 240 },
                { weapon = 'WEAPON_PUMPSHOTGUN', ammo = 48 },
            },
        }),
        grades = Sunset.BuildLawEnforcementGrades(1.05),
    },
    medic = {
        label = 'Pillbox EMS',
        applicationsOpen = true,
        weeklyReportTarget = 15,
        type = 'legal',
        factionType = 'ems',
        description = 'Emergency medical services — heal, revive, and stabilize patients at Pillbox.',
        society = 'medic',
        duty = true,
        hq = vector3(298.0, -584.0, 43.28),
        hqHint = '[E] Pillbox EMS HQ — members: toggle duty | applications: Discord/site',
        blip = { sprite = 61, color = 1, scale = 0.9 },
        marker = { 255, 50, 50 },
        depot = {
            label = 'EMS Ambulance Bay',
            coords = vector3(294.58, -574.35, 43.18),
            spawn = vector4(294.58, -574.35, 43.18, 70.0),
            vehicle = 'ambulance',
            platePrefix = 'EMS',
        },
        grades = Sunset.BuildEmsGrades(),
        loadout = {
            armor = 0,
            gradeOutfits = Sunset.BuildEmsGradeOutfits(),
            weapons = {
                { weapon = 'WEAPON_FLASHLIGHT', ammo = 0 },
            },
        },
    },
    taxi = {
        label = 'Downtown Cab Co.',
        applicationsOpen = true,
        weeklyReportTarget = 20,
        type = 'legal',
        factionType = 'transport',
        description = 'City taxi service — pick up passengers via the Downtown Cab phone app or manual fares.',
        society = 'taxi',
        duty = true,
        hq = vector3(903.32, -170.14, 74.08),
        hqHint = '[E] Downtown Cab HQ — members: toggle duty | applications: Discord/site',
        blip = { sprite = 198, color = 5, scale = 0.85 },
        marker = { 255, 200, 0 },
        depot = {
            label = 'Cab Depot',
            coords = vector3(916.45, -170.62, 74.08),
            spawn = vector4(916.45, -170.62, 74.08, 240.0),
            vehicle = 'taxi',
            platePrefix = 'CAB',
        },
        grades = Sunset.BuildServiceGrades('fare', {
            'Driver', 'Senior Driver', 'Dispatcher', 'Fleet Specialist', 'Shift Lead', 'Operations Lead', 'Deputy Manager', 'Owner',
        }, { 180, 250, 320, 400, 480, 560, 640, 750 }),
    },
    mechanic = {
        label = 'LS Customs',
        applicationsOpen = true,
        weeklyReportTarget = 15,
        type = 'legal',
        factionType = 'mechanic',
        description = 'Vehicle repair shop — fix cars at HQ or on the road for other players.',
        society = 'mechanic',
        duty = true,
        hq = vector3(-337.52, -136.57, 39.01),
        hqHint = '[E] LS Customs — vehicle repair $250 | members: toggle duty',
        blip = { sprite = 446, color = 47, scale = 0.85 },
        marker = { 255, 140, 0 },
        depot = {
            label = 'Tow Fleet',
            coords = vector3(-356.20, -126.55, 39.01),
            spawn = vector4(-356.20, -126.55, 39.01, 70.0),
            vehicle = 'towtruck',
            platePrefix = 'LSC',
        },
        grades = Sunset.BuildServiceGrades('repair', {
            'Apprentice', 'Mechanic', 'Journeyman', 'Senior Mechanic', 'Foreman', 'Shop Lead', 'Deputy Manager', 'Shop Manager',
        }, { 220, 320, 400, 480, 560, 640, 720, 800 }),
    },
    lsfd = {
        label = 'LS Fire Department',
        applicationsOpen = true,
        weeklyReportTarget = 15,
        type = 'legal',
        factionType = 'fire_rescue',
        description = 'Fire and rescue — clock in, take the firetruk, answer vehicle fires with the extinguisher. Revive at Engineer rank and above.',
        society = 'lsfd',
        duty = true,
        hq = vector3(1194.82, -1464.01, 34.86),
        hqHint = '[E] LSFD HQ — members: toggle duty | applications: Discord/site',
        blip = { sprite = 436, color = 1, scale = 0.85 },
        marker = { 255, 80, 0 },
        depot = {
            label = 'Fire Station Garage',
            coords = vector3(1200.45, -1465.80, 34.86),
            spawn = vector4(1200.45, -1465.80, 34.86, 0.0),
            vehicle = 'firetruk',
            platePrefix = 'LSFD',
        },
        grades = Sunset.BuildFireGrades(),
        loadout = {
            armor = 25,
            gradeOutfits = Sunset.BuildFireGradeOutfits(),
            weapons = {
                { weapon = 'WEAPON_FLASHLIGHT', ammo = 0 },
            },
        },
    },
    sunset_cartel = {
        label = 'Sunset Cartel',
        applicationsOpen = false,
        weeklyReportTarget = 10,
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
        grades = Sunset.BuildCriminalGrades({ craft_illegal = 1, sell = 1 }),
    },
    night_syndicate = {
        label = 'Night Syndicate',
        applicationsOpen = false,
        weeklyReportTarget = 10,
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
        grades = Sunset.BuildCriminalGrades({ craft_illegal = 1, fence = 1 }),
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
    { perm = 'invite', cmd = '/finvite [id]', desc = 'Leader: invite an accepted applicant nearby' },
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

function Sunset.GetFactionCommandsForGrade(jobId, grade, isLeader)
    local list = {}
    for _, row in ipairs(Sunset.FactionCommandCatalog or {}) do
        -- Recruitment is an explicit leader responsibility, regardless of a
        -- rank's older generic permissions.
        if row.perm == 'invite' and isLeader then
            list[#list + 1] = row
        elseif row.perm ~= 'invite' and Sunset.HasFactionPerm(jobId, grade, row.perm) then
            list[#list + 1] = row
        end
    end
    list[#list + 1] = { cmd = '/duty', desc = 'Toggle on/off shift' }
    list[#list + 1] = { cmd = '/f [message]', desc = 'Faction radio chat' }
    list[#list + 1] = { cmd = '/leavefaction', desc = 'Leave your faction' }
    list[#list + 1] = { cmd = '/quitfaction', desc = 'Leave your faction (alias)' }
    list[#list + 1] = { cmd = '/factionquit', desc = 'Leave your faction (alias)' }
    if Sunset.FactionTypeMatches(jobId, 'law_enforcement') then
        list[#list + 1] = { cmd = '/pdgarage', desc = 'Spawn MRPD patrol vehicle (on duty)' }
        list[#list + 1] = { cmd = '/pd', desc = 'LSPD command list' }
        list[#list + 1] = { cmd = '/so [id]', desc = 'Summon nearby suspect' }
        list[#list + 1] = { cmd = '/wanted', desc = 'List active wanted players' }
        list[#list + 1] = { cmd = '/find [id]', desc = 'Set GPS on a wanted player (limited ranks: up to ★2)' }
        if Sunset.HasFactionPerm(jobId, grade, 'cuff') then
            list[#list + 1] = { cmd = '/cuff [id]', desc = 'Restrain a nearby suspect' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'uncuff') then
            list[#list + 1] = { cmd = '/uncuff [id]', desc = 'Remove a nearby suspect’s restraints' }
        end
        if Sunset.HasFactionPerm(jobId, grade, 'wanted') or Sunset.HasFactionPerm(jobId, grade, 'wanted_limited') then
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
        if Sunset.HasFactionPerm(jobId, grade, 'ticket') or Sunset.HasFactionPerm(jobId, grade, 'fine') then
            list[#list + 1] = { cmd = '/ticket [id]', desc = 'Issue server-priced citation (UI)' }
            list[#list + 1] = { cmd = '/fine [id]', desc = 'Alias for /ticket citation UI' }
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
            list[#list + 1] = { cmd = '/startradar [limit_kmh]', desc = 'Lock the patrol car and monitor traffic' }
            list[#list + 1] = { cmd = '/setradar [limit_kmh]', desc = 'Alias for /startradar' }
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
    if Sunset.FactionTypeMatches(jobId, 'fire_rescue') then
        list[#list + 1] = { cmd = '/fd', desc = 'LSFD how-to: duty, garage, fires, payout' }
        list[#list + 1] = { cmd = '/firestart', desc = 'Dispatch a vehicle fire if none is active (on duty)' }
        list[#list + 1] = { cmd = '/firecalls', desc = 'List active fires and set GPS (on duty)' }
        list[#list + 1] = { cmd = '/calls', desc = 'Open service calls — accept civilian /service fire' }
        list[#list + 1] = { cmd = 'Extinguisher', desc = 'At the wreck, spray LMB until the fire is out (~$350)' }
        list[#list + 1] = { cmd = '[E] garage', desc = 'Spawn firetruk at Fire Station Garage (on duty)' }
    end
    list[#list + 1] = { cmd = '/fmotd [message?]', desc = 'Read MOTD; permitted ranks may set it' }
    if Sunset.HasFactionPerm(jobId, grade, 'fmotd') or Sunset.HasFactionPerm(jobId, grade, 'invite') then
        list[#list + 1] = { cmd = '/fmembers', desc = 'List online faction members' }
    end
    if Sunset.HasFactionPerm(jobId, grade, 'fwarn') then
        list[#list + 1] = { cmd = '/fwarn [id] [reason]', desc = 'Issue faction warning' }
    end
    if Sunset.HasFactionPerm(jobId, grade, 'uninvite') then
        list[#list + 1] = { cmd = '/funinvite [id]', desc = 'Remove member from faction' }
    end
    if Sunset.HasFactionPerm(jobId, grade, 'giverank') then
        list[#list + 1] = { cmd = '/fgiverank [id] [grade]', desc = 'Set member faction rank' }
    end
    return list
end
