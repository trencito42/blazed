Sunset = Sunset or {}

Sunset.Taxi = {
    factionId = 'taxi',
    appName = 'Downtown Cab',
    appShort = 'Cab',
    baseFare = 75,
    perKm = 35,
    minFare = 100,
    requestTimeout = 300,
    companyCut = 0.12,
    pickupRadius = 18.0,
    dropoffRadius = 28.0,
    completeRadius = 60.0,
    arrivingDistanceKm = 0.15,
    distanceUpdateMs = 1500,
    allowedVehicles = { 'taxi' },
    tipOptions = { 25, 50, 100 },
    destinations = {
        { id = 'legion', label = 'Legion Square', category = 'Popular', coords = vector3(215.76, -810.12, 30.73) },
        { id = 'pillbox', label = 'Pillbox Hospital', category = 'Popular', coords = vector3(307.12, -595.55, 43.28) },
        { id = 'mrpd', label = 'Mission Row PD', category = 'Popular', coords = vector3(441.15, -981.95, 30.69) },
        { id = 'airport', label = 'LSIA Airport', category = 'Popular', coords = vector3(-1037.52, -2737.44, 20.17) },
        { id = 'sandy', label = 'Sandy Shores', category = 'Blaine County', coords = vector3(1960.13, 3740.02, 32.34) },
        { id = 'paleto', label = 'Paleto Bay', category = 'Blaine County', coords = vector3(-247.41, 6331.46, 32.43) },
        { id = 'vinewood', label = 'Vinewood Hills', category = 'Popular', coords = vector3(725.32, 120.05, 80.75) },
        { id = 'beach', label = 'Vespucci Beach', category = 'Popular', coords = vector3(-1393.42, -1286.19, 4.52) },
        { id = 'docks', label = 'LS Docks', category = 'Popular', coords = vector3(797.04, -2990.99, 6.02) },
        { id = 'casino', label = 'Diamond Casino', category = 'Popular', coords = vector3(925.33, 46.15, 81.11) },
        { id = 'grove', label = 'Grove Street', category = 'Popular', coords = vector3(-42.89, -1753.91, 29.42) },
        { id = 'mirror', label = 'Mirror Park', category = 'Popular', coords = vector3(1137.42, -482.09, 66.0) },
        { id = 'delperro', label = 'Del Perro Pier', category = 'Popular', coords = vector3(-1632.87, -1007.81, 13.02) },
        { id = 'chumash', label = 'Chumash', category = 'Blaine County', coords = vector3(-3192.61, 1101.91, 20.72) },
        { id = 'grapeseed', label = 'Grapeseed', category = 'Blaine County', coords = vector3(1697.92, 4785.52, 41.98) },
    },
    mapBounds = { minX = -4000, maxX = 6000, minY = -5500, maxY = 8000 },
}

function Sunset.Taxi.IsValidTaxiVehicle(modelHash)
    if not modelHash then return false end
    local cfg = Sunset.Taxi
    for _, name in ipairs(cfg.allowedVehicles or { 'taxi' }) do
        if joaat(name) == modelHash then return true end
    end
    local faction = Sunset.Factions and Sunset.Factions[cfg.factionId or 'taxi']
    local depot = faction and faction.depot
    if depot and depot.vehicle and joaat(depot.vehicle) == modelHash then
        return true
    end
    return modelHash == joaat('taxi')
end

function Sunset.TaxiDistanceKm(a, b)
    if not a or not b then return 0 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz) / 1000.0
end

function Sunset.TaxiEstimateFare(pickup, destination)
    local cfg = Sunset.Taxi
    local km = Sunset.TaxiDistanceKm(pickup, destination)
    local fare = math.floor((cfg.baseFare or 75) + km * (cfg.perKm or 35))
    return math.max(fare, cfg.minFare or 100), km
end
