Sunset = Sunset or {}

Sunset.Fire = {
    factionId = 'lsfd',
    extinguisherWeapon = 'WEAPON_FIREEXTINGUISHER',
    incidentIntervalSec = 900,
    maxActiveIncidents = 3,
    extinguishRange = 8.0,
    extinguishRate = 12,
    fireHealth = 100,
    payout = 350,
    societyCut = 0.15,
    spawnPoints = {
        -- Roadside/industrial scenes away from faction HQs and public spawn.
        vector4(842.5, -2115.4, 29.3, 175.0),
        vector4(-430.2, -1719.1, 19.0, 70.0),
        vector4(-1037.0, -2737.0, 20.2, 240.0),
        vector4(1703.7, 3755.2, 34.1, 35.0),
        vector4(-304.5, 6228.4, 31.5, 135.0),
        vector4(2560.1, 2607.4, 38.1, 110.0),
    },
    vehicleModels = { 'sultan', 'futo', 'blista', 'asea', 'primo' },
}
