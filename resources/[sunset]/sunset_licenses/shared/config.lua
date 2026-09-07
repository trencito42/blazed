SunsetLicenses = SunsetLicenses or {}

SunsetLicenses.PaydayExpiry = 200

SunsetLicenses.Types = {
    driver = {
        label = 'Driving License',
        short = 'Driver',
        facility = 'driving_school',
        instructorFaction = false,
        vehicleClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20 },
    },
    pilot = {
        label = 'Pilot License',
        short = 'Pilot',
        facility = 'airport',
        instructorFaction = true,
        vehicleClasses = { 15, 16 },
    },
    boat = {
        label = 'Boat License',
        short = 'Boat',
        facility = 'marina',
        instructorFaction = true,
        vehicleClasses = { 14 },
    },
    weapon = {
        label = 'Firearm License',
        short = 'Weapon',
        facility = 'range',
        instructorFaction = true,
        vehicleClasses = {},
    },
}

SunsetLicenses.Facilities = {
    driving_school = {
        label = 'Driving School',
        blip = { sprite = 225, color = 5, scale = 0.85 },
        marker = vector3(240.12, -1379.35, 33.74),
        markerRadius = 2.5,
        license = 'driver',
    },
    airport = {
        label = 'Flight School — LSIA',
        blip = { sprite = 307, color = 2, scale = 0.9 },
        marker = vector3(-1037.2, -2737.8, 20.17),
        markerRadius = 3.0,
        license = 'pilot',
        spawn = vector4(-1145.2, -2864.5, 13.95, 330.0),
        testVehicle = 'maverick',
    },
    marina = {
        label = 'Boat School — Marina',
        blip = { sprite = 410, color = 2, scale = 0.85 },
        marker = vector3(-794.5, -1510.2, 1.6),
        markerRadius = 3.0,
        license = 'boat',
        spawn = vector4(-798.2, -1502.5, 0.12, 110.0),
        testVehicle = 'dinghy',
    },
    range = {
        label = 'Weapon Range — LSSI',
        blip = { sprite = 313, color = 2, scale = 0.85 },
        marker = vector3(13.2, -1097.5, 29.8),
        markerRadius = 2.5,
        license = 'weapon',
    },
}

SunsetLicenses.MeleeWeapons = {
    WEAPON_UNARMED = true,
    WEAPON_KNIFE = true,
    WEAPON_SWITCHBLADE = true,
    WEAPON_BAT = true,
    WEAPON_CROWBAR = true,
    WEAPON_FLASHLIGHT = true,
    WEAPON_NIGHTSTICK = true,
    WEAPON_HAMMER = true,
    WEAPON_GOLFCLUB = true,
    WEAPON_BOTTLE = true,
    WEAPON_DAGGER = true,
    WEAPON_HATCHET = true,
    WEAPON_KNUCKLE = true,
    WEAPON_MACHETE = true,
    WEAPON_WRENCH = true,
    WEAPON_POOLCUE = true,
    WEAPON_BATTLEAXE = true,
    WEAPON_STONE_HATCHET = true,
}

function SunsetLicenses.isFirearmWeapon(weaponName)
    if not weaponName or weaponName == '' then return false end
    weaponName = string.upper(weaponName)
    if SunsetLicenses.MeleeWeapons[weaponName] then return false end
    return weaponName:sub(1, 7) == 'WEAPON_'
end

function SunsetLicenses.vehicleClassForLicense(classId)
    classId = tonumber(classId) or -1
    for licenseType, def in pairs(SunsetLicenses.Types) do
        for _, cls in ipairs(def.vehicleClasses or {}) do
            if cls == classId then return licenseType end
        end
    end
    return nil
end

SunsetLicenses.Theory = {
    driver = {
        title = 'Driving School — Theory',
        intro = 'Read each question carefully. You need 3/4 correct to pass. On the road: stop at reds, yield to pedestrians, and stay in your lane.',
        passScore = 3,
        questions = {
            {
                q = 'What should you do at a red traffic light?',
                options = { 'Speed through if clear', 'Stop and wait for green', 'Honk and go', 'Reverse' },
                correct = 2,
            },
            {
                q = 'When may you use your phone while driving?',
                options = { 'Never while the vehicle is moving', 'At any time', 'Only on highways', 'Only at night' },
                correct = 1,
            },
            {
                q = 'Who has priority at a pedestrian crossing?',
                options = { 'The vehicle', 'Pedestrians on the crossing', 'Whoever is faster', 'Emergency vehicles only' },
                correct = 2,
            },
            {
                q = 'What does a solid double yellow line mean?',
                options = { 'Pass freely', 'No passing / stay in lane', 'Parking allowed', 'U-turn required' },
                correct = 2,
            },
        },
    },
    pilot = {
        title = 'Flight School — Theory',
        intro = 'Aircraft are dangerous without training. Maintain altitude in checkpoints, avoid buildings, and land gently at LSIA with the engine off.',
        passScore = 3,
        questions = {
            {
                q = 'Before takeoff you must:',
                options = { 'Check fuel and controls', 'Skip preflight', 'Take off immediately', 'Land first' },
                correct = 1,
            },
            {
                q = 'If you lose engine power you should:',
                options = { 'Panic and bail', 'Attempt a controlled landing', 'Fly upside down', 'Increase throttle only' },
                correct = 2,
            },
            {
                q = 'Helicopter yaw is controlled mainly by:',
                options = { 'Rudder pedals / anti-torque', 'Brakes', 'Horn', 'Seatbelt' },
                correct = 1,
            },
            {
                q = 'After landing you must:',
                options = { 'Leave engine running', 'Shut down engine safely', 'Take off again', 'Abandon aircraft' },
                correct = 2,
            },
        },
    },
    boat = {
        title = 'Boat School — Theory',
        intro = 'On the water: wear a life jacket mindset, watch for swimmers, and complete all buoys before returning to the marina.',
        passScore = 3,
        questions = {
            {
                q = 'Near swimmers you should:',
                options = { 'Speed up', 'Slow down and keep distance', 'Rev engine', 'Ignore them' },
                correct = 2,
            },
            {
                q = 'At night boats need:',
                options = { 'No lights', 'Proper navigation lights', 'Only horn', 'Flares only' },
                correct = 2,
            },
            {
                q = 'Before starting the engine:',
                options = { 'Check fuel and area is clear', 'Jump in water', 'Speed away', 'Close eyes' },
                correct = 1,
            },
            {
                q = 'Returning to dock you should:',
                options = { 'Ram the pier', 'Approach slowly', 'Full throttle', 'Abandon boat' },
                correct = 2,
            },
        },
    },
    weapon = {
        title = 'Firearm Safety — Theory',
        intro = 'Treat every gun as loaded. Keep the muzzle pointed in a safe direction and only fire at range targets during the practical.',
        passScore = 3,
        questions = {
            {
                q = 'First rule of firearm safety:',
                options = { 'Always treat as loaded', 'Point at friends', 'Keep finger on trigger', 'Ignore surroundings' },
                correct = 1,
            },
            {
                q = 'You may discharge only:',
                options = { 'Anywhere in the city', 'At authorized range targets', 'At vehicles', 'At buildings' },
                correct = 2,
            },
            {
                q = 'Without a license you may carry:',
                options = { 'Any rifle', 'Melee tools only (no firearms)', 'Explosives', 'Heavy MG' },
                correct = 2,
            },
            {
                q = 'After the practical you must:',
                options = { 'Keep the test weapon', 'Holster / clear and end test', 'Sell the gun', 'Shoot in town' },
                correct = 2,
            },
        },
    },
}

SunsetLicenses.Practical = {
    driver = {
        vehicle = 'blista',
        spawn = vector4(222.5, -1388.2, 30.58, 270.0),
        checkpointRadius = 6.0,
        maxTimeSec = 420,
        checkpoints = {
            vector3(250.0, -1388.0, 30.5),
            vector3(280.0, -1350.0, 30.5),
            vector3(310.0, -1388.0, 30.5),
            vector3(280.0, -1420.0, 30.5),
            vector3(240.0, -1388.0, 30.5),
        },
        finish = vector3(222.5, -1388.2, 30.58),
        finishRadius = 8.0,
    },
    pilot = {
        checkpointRadius = 35.0,
        maxTimeSec = 600,
        checkpoints = {
            vector3(-1080.0, -2880.0, 45.0),
            vector3(-980.0, -2950.0, 55.0),
            vector3(-880.0, -2850.0, 50.0),
            vector3(-1000.0, -2750.0, 48.0),
        },
        finish = vector3(-1145.2, -2864.5, 13.95),
        finishRadius = 25.0,
        requireEngineOff = true,
    },
    boat = {
        checkpointRadius = 18.0,
        maxTimeSec = 480,
        checkpoints = {
            vector3(-820.0, -1520.0, 0.0),
            vector3(-860.0, -1580.0, 0.0),
            vector3(-780.0, -1620.0, 0.0),
            vector3(-740.0, -1540.0, 0.0),
        },
        finish = vector3(-798.2, -1502.5, 0.12),
        finishRadius = 15.0,
        requireEngineOff = true,
    },
    weapon = {
        weapon = 'WEAPON_PISTOL',
        ammo = 48,
        targetsRequired = 5,
        targetRadius = 1.2,
        maxTimeSec = 300,
        targets = {
            vector4(15.5, -1083.2, 29.8, 180.0),
            vector4(18.0, -1083.2, 29.8, 180.0),
            vector4(20.5, -1083.2, 29.8, 180.0),
            vector4(15.5, -1086.0, 29.8, 180.0),
            vector4(20.5, -1086.0, 29.8, 180.0),
        },
        zoneCenter = vector3(16.5, -1094.0, 29.8),
        zoneRadius = 22.0,
    },
}
