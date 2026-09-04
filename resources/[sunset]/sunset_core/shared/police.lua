Sunset = Sunset or {}

Sunset.Police = {
    summonRange = 125.0,
    arrestRange = 5.0,
    jailRadius = 12.0,
    jailCoords = vector4(1641.99, 2570.29, 45.56, 270.0),
    releaseCoords = vector4(1855.68, 2604.45, 45.67, 270.0),
    pdJailPoint = vector3(461.85, -994.55, 24.91),
    bookingPoints = {
        { label = 'MRPD Booking — basement', coords = vector3(461.85, -994.55, 24.91) },
        { label = 'Bolingbroke Reception — front processing gate', coords = vector3(1845.91, 2585.84, 45.67) },
    },

    decayMinutes = {
        [1] = 15,
        [2] = 25,
        [3] = 40,
        [4] = 55,
        [5] = 75,
    },

    bounties = {
        [1] = 100,
        [2] = 250,
        [3] = 500,
        [4] = 1000,
        [5] = 2000,
    },

    reasons = {
        speeding = { label = 'Speeding', stars = 1, jailMinutes = 2 },
        reckless = { label = 'Reckless Driving', stars = 2, jailMinutes = 4 },
        assault = { label = 'Assault', stars = 2, jailMinutes = 5 },
        robbery = { label = 'Robbery', stars = 3, jailMinutes = 10 },
        evading = { label = 'Evading Police', stars = 3, jailMinutes = 8 },
        murder = { label = 'Murder', stars = 5, jailMinutes = 20 },
    },

    violations = {
        { code = 'speeding', label = 'Speeding', amount = 150 },
        { code = 'reckless', label = 'Reckless Driving', amount = 350 },
        { code = 'parking', label = 'Illegal Parking', amount = 75 },
        { code = 'redlight', label = 'Running Red Light', amount = 200 },
        { code = 'noinsurance', label = 'No Insurance', amount = 500 },
        { code = 'disturbance', label = 'Public Disturbance', amount = 250 },
    },

    confiscatable = {
        lockpick = true,
        gunpowder = true,
        shiv = true,
        sealed_pouch = true,
        chemicals = true,
        ammo_9mm = true,
    },

    radar = {
        mobileRange = 45.0,
        mobileCone = 18.0,
        scanIntervalMs = 750,
        defaultLimitMph = 55,
        lockCooldownMs = 4000,
    },

    fixedRadars = {
        { label = 'Legion Square East', coords = vector3(215.4, -1024.8, 29.3), limitMph = 45, radius = 22.0 },
        { label = 'Del Perro Freeway', coords = vector3(-1470.2, -499.5, 32.8), limitMph = 65, radius = 28.0 },
        { label = 'Route 68 Sandy', coords = vector3(1956.4, 3842.1, 32.2), limitMph = 55, radius = 25.0 },
        { label = 'Palomino Ave', coords = vector3(-517.8, -610.2, 30.4), limitMph = 40, radius = 20.0 },
    },
}

function Sunset.GetPoliceReason(code)
    if not code or not Sunset.Police then return nil end
    return Sunset.Police.reasons[string.lower(code)]
end

function Sunset.GetPoliceViolation(code)
    if not code or not Sunset.Police then return nil end
    code = string.lower(code)
    for _, row in ipairs(Sunset.Police.violations or {}) do
        if row.code == code then return row end
    end
    return nil
end

function Sunset.IsConfiscatableItem(item)
    return Sunset.Police and Sunset.Police.confiscatable and Sunset.Police.confiscatable[item] == true
end
