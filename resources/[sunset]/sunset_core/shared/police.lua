Sunset = Sunset or {}

Sunset.Police = {
    summonRange = 125.0,
    arrestRange = 5.0,
    jailRadius = 12.0,
    jailCoords = vector4(1641.99, 2570.29, 45.56, 270.0),
    releaseCoords = vector4(1855.68, 2604.45, 45.67, 270.0),
    pdJailPoint = vector3(461.85, -994.55, 24.91),

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
}

function Sunset.GetPoliceReason(code)
    if not code or not Sunset.Police then return nil end
    return Sunset.Police.reasons[string.lower(code)]
end
