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
            platePrefix = 'LSPD',
            vehicles = {
                { model = 'police', label = 'Patrol Cruiser', minGrade = 0 },
                { model = 'police2', label = 'Buffalo Patrol', minGrade = 1 },
                { model = 'police3', label = 'Interceptor', minGrade = 2 },
                { model = 'policeb', label = 'Police Bike', minGrade = 2 },
                { model = 'policet', label = 'Transport Van', minGrade = 3 },
                { model = 'police4', label = 'Unmarked Cruiser', minGrade = 4 },
                { model = 'riot', label = 'SWAT Bearcat', minGrade = 5 },
                { model = 'polmav', label = 'Air Support', minGrade = 6 },
            },
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
        hq = vector3(369.23, -1607.72, 29.29),
        hqHeading = 323.63,
        hqHint = '[E] Sheriff Station — members: toggle duty | robbery response unit',
        blip = { sprite = 60, color = 46, scale = 0.9 },
        marker = { 160, 110, 40 },
        depot = {
            label = 'Sheriff Fleet Garage',
            coords = vector3(376.33, -1631.79, 27.84),
            spawn = vector4(376.33, -1631.79, 27.84, 145.06),
            platePrefix = 'SASD',
            vehicles = {
                { model = 'sheriff', label = 'Sheriff Cruiser', minGrade = 0 },
                { model = 'sheriff2', label = 'Sheriff SUV', minGrade = 1 },
                { model = 'police3', label = 'County Interceptor', minGrade = 2 },
                { model = 'policeb', label = 'Police Bike', minGrade = 3 },
                { model = 'police4', label = 'Unmarked Unit', minGrade = 4 },
                { model = 'riot', label = 'Tactical Response', minGrade = 5 },
            },
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
        hqRadius = 2.0,
        hqHint = '[E] FIB HQ — toggle duty | walk in, lift to motor pool',
        blip = { sprite = 60, color = 0, scale = 0.85 },
        marker = { 20, 20, 20 },
        depot = {
            label = 'FIB Motor Pool',
            -- Fleet garage (MRPD-style picker) — underground parking after the lift
            coords = vector3(176.16, -706.13, 33.13),
            spawn = vector4(176.16, -706.13, 33.13, 62.78),
            platePrefix = 'FIB',
            vehicles = {
                { model = 'fbi', label = 'FIB Sedan', minGrade = 0 },
                { model = 'fbi2', label = 'FIB SUV', minGrade = 1 },
                { model = 'police4', label = 'Unmarked Cruiser', minGrade = 3 },
                { model = 'baller6', label = 'Armored SUV', minGrade = 4 },
                { model = 'schafter5', label = 'Executive Sedan', minGrade = 5 },
                { model = 'polmav', label = 'FIB Air Unit', minGrade = 6 },
            },
            lift = {
                label = 'FIB Lift',
                lobby = vector4(136.25, -761.65, 45.75, 161.02),
                garage = vector4(182.66, -727.47, 33.13, 250.0),
                garageRadius = 2.2,
            },
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
            platePrefix = 'EMS',
            vehicles = {
                { model = 'ambulance', label = 'Ambulance', minGrade = 0 },
                { model = 'ambulance2', label = 'Ambulance Type II', minGrade = 2 },
                { model = 'lguard', label = 'Lifeguard SUV', minGrade = 3 },
                { model = 'rumpo', label = 'EMS Response Van', minGrade = 4 },
                { model = 'burrito3', label = 'Command Unit', minGrade = 6 },
                { model = 'polmav', label = 'Air Ambulance', minGrade = 7 },
            },
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
            platePrefix = 'CAB',
            vehicles = {
                { model = 'taxi', label = 'Yellow Cab', minGrade = 0 },
                { model = 'taxiold', label = 'Classic Cab', minGrade = 1 },
                { model = 'dynasty', label = 'Executive Sedan', minGrade = 2 },
                { model = 'rumpo', label = 'Dispatch Van', minGrade = 3 },
                { model = 'stretch', label = 'Limousine', minGrade = 5 },
                { model = 'bus', label = 'City Shuttle', minGrade = 6 },
            },
        },
        grades = Sunset.BuildServiceGrades('fare', {
            'Driver', 'Senior Driver', 'Dispatcher', 'Fleet Specialist', 'Shift Lead', 'Operations Lead', 'Deputy Manager', 'Owner',
        }, { 180, 250, 320, 400, 480, 560, 640, 750 }),
        loadout = Sunset.BuildServiceLoadout('taxi'),
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
            -- Interaction: open lot behind the shop (not inside the building)
            coords = vector3(-358.35, -122.45, 38.70),
            -- Spawn: East Joshua Rd — room for tow trucks / flatbeds
            spawn = vector4(-368.50, -107.80, 38.68, 249.0),
            platePrefix = 'LSC',
            vehicles = {
                { model = 'towtruck', label = 'Tow Truck', minGrade = 0 },
                { model = 'towtruck2', label = 'Heavy Tow', minGrade = 2 },
                { model = 'flatbed', label = 'Flatbed', minGrade = 3 },
                { model = 'utillitruck3', label = 'Service Truck', minGrade = 4 },
                { model = 'burrito3', label = 'Parts Van', minGrade = 5 },
                { model = 'slamtruck', label = 'Recovery Rig', minGrade = 6 },
            },
        },
        grades = Sunset.BuildServiceGrades('repair', {
            'Apprentice', 'Mechanic', 'Journeyman', 'Senior Mechanic', 'Foreman', 'Shop Lead', 'Deputy Manager', 'Shop Manager',
        }, { 220, 320, 400, 480, 560, 640, 720, 800 }),
        loadout = Sunset.BuildServiceLoadout('mechanic'),
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
            platePrefix = 'LSFD',
            vehicles = {
                { model = 'firetruk', label = 'Fire Engine', minGrade = 0 },
                { model = 'ambulance', label = 'Rescue Ambulance', minGrade = 2 },
                { model = 'lguard', label = 'Brush Patrol', minGrade = 3 },
                { model = 'rumpo', label = 'Crew Van', minGrade = 4 },
                { model = 'utillitruck3', label = 'Utility Truck', minGrade = 5 },
                { model = 'burrito3', label = 'Command Unit', minGrade = 6 },
            },
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
    lssi = {
        label = 'LSSI — License & Safety',
        applicationsOpen = true,
        weeklyReportTarget = 12,
        type = 'legal',
        factionType = 'education',
        description = 'Los Santos Safety Institute — pilot, boat, and firearm licensing instructors.',
        society = 'lssi',
        duty = true,
        hq = vector3(20.5, -1105.0, 29.8),
        hqHint = '[E] LSSI HQ — instructors: toggle duty | issue pilot/boat/weapon licenses',
        blip = { sprite = 498, color = 2, scale = 0.85 },
        marker = { 50, 200, 80 },
        grades = Sunset.BuildEducationGrades(),
        loadout = Sunset.BuildServiceLoadout('lssi'),
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
        depot = {
            label = 'Cartel Motor Pool',
            coords = vector3(1390.50, 1148.20, 114.33),
            spawn = vector4(1390.50, 1148.20, 114.33, 180.0),
            platePrefix = 'CRT',
            vehicles = {
                { model = 'baller2', label = 'Cartel SUV', minGrade = 0 },
                { model = 'manchez', label = 'Scout Bike', minGrade = 1 },
                { model = 'dubsta2', label = 'Armored SUV', minGrade = 2 },
                { model = 'rumpo3', label = 'Cargo Van', minGrade = 3 },
                { model = 'cavalcade2', label = 'Executive SUV', minGrade = 4 },
                { model = 'insurgent2', label = 'Convoy Truck', minGrade = 6 },
            },
        },
        grades = Sunset.BuildCriminalGrades({ craft_illegal = 1, sell = 1 }),
        loadout = Sunset.BuildServiceLoadout('cartel'),
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
        depot = {
            label = 'Syndicate Garage',
            coords = vector3(-1515.20, 855.40, 181.59),
            spawn = vector4(-1515.20, 855.40, 181.59, 120.0),
            platePrefix = 'SYN',
            vehicles = {
                { model = 'stanier', label = 'Street Sedan', minGrade = 0 },
                { model = 'kuruma', label = 'Armored Kuruma', minGrade = 2 },
                { model = 'schafter3', label = 'Executive Sedan', minGrade = 3 },
                { model = 'fugitive', label = 'Pursuit Sedan', minGrade = 4 },
                { model = 'banshee', label = 'Fastback', minGrade = 5 },
                { model = 'youga2', label = 'Contraband Van', minGrade = 6 },
            },
        },
        grades = Sunset.BuildCriminalGrades({ craft_illegal = 1, fence = 1 }),
        loadout = Sunset.BuildServiceLoadout('syndicate'),
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
    { perm = 'issue_license', cmd = '/issuelicense [id] [pilot|boat|weapon]', desc = 'Grant license (LSSI instructor)' },
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
    if Sunset.FactionTypeMatches(jobId, 'law_enforcement')
        or Sunset.FactionTypeMatches(jobId, 'ems')
        or Sunset.FactionTypeMatches(jobId, 'fire_rescue') then
        list[#list + 1] = { cmd = '/r [message]', desc = 'Faction radio (your department only)' }
        list[#list + 1] = { cmd = '/d [message]', desc = 'Shared emergency radio (LSPD, Sheriff, FIB, EMS, LSFD)' }
    else
        list[#list + 1] = { cmd = '/f [message]', desc = 'Faction radio chat' }
    end
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

local function coord3(point)
    if not point then return nil end
    local x = tonumber(point.x)
    local y = tonumber(point.y)
    local z = tonumber(point.z)
    if not x or not y or not z then return nil end
    return x, y, z
end

--- Saved positions inside faction motor pools / lifts are not safe last-location spawns.
function Sunset.GetFactionDepotRescueSpawn(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return nil end

    for _, faction in pairs(Sunset.Factions or {}) do
        local depot = faction.depot
        if not depot then goto continue end

        local hotspots = {}
        if depot.spawn then hotspots[#hotspots + 1] = depot.spawn end
        if depot.lift and depot.lift.garage then hotspots[#hotspots + 1] = depot.lift.garage end
        if depot.lift and depot.lift.lobby then hotspots[#hotspots + 1] = depot.lift.lobby end
        if depot.coords then hotspots[#hotspots + 1] = depot.coords end

        for _, point in ipairs(hotspots) do
            local px, py, pz = coord3(point)
            if px then
                local dx, dy, dz = x - px, y - py, z - pz
                if (dx * dx + dy * dy + dz * dz) <= (14.0 * 14.0) then
                    if depot.exitSpawn then
                        return {
                            x = depot.exitSpawn.x,
                            y = depot.exitSpawn.y,
                            z = depot.exitSpawn.z,
                            w = depot.exitSpawn.w or 0.0,
                        }
                    end
                    if faction.hq then
                        return {
                            x = faction.hq.x,
                            y = faction.hq.y,
                            z = faction.hq.z,
                            w = 0.0,
                        }
                    end
                end
            end
        end

        ::continue::
    end
    return nil
end
