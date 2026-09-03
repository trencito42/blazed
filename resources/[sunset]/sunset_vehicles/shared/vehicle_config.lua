Sunset = Sunset or {}

-- Per vehicle-class tuning (GTA vehicle classes 0–21)
Sunset.VehicleProfiles = {
    -- Base fuel drain per second when moving (scaled by RPM + speed)
    fuelBase = 0.0035,

    classFuel = {
        [0] = 0.82,  -- Compacts
        [1] = 1.00,  -- Sedans
        [2] = 1.18,  -- SUVs
        [3] = 0.95,  -- Coupes
        [4] = 1.12,  -- Muscle
        [5] = 1.08,  -- Sports Classics
        [6] = 1.35,  -- Sports
        [7] = 1.55,  -- Super
        [8] = 0.55,  -- Motorcycles
        [9] = 1.22,  -- Off-road
        [10] = 1.30, -- Industrial
        [11] = 1.05, -- Utility
        [12] = 1.15, -- Vans
        [13] = 0.0,  -- Cycles
        [14] = 2.40, -- Boats
        [15] = 3.20, -- Helicopters
        [16] = 4.50, -- Planes
        [17] = 1.00, -- Service
        [18] = 1.10, -- Emergency
        [19] = 1.25, -- Military
        [20] = 1.40, -- Commercial
        [21] = 0.0,  -- Trains
    },

  -- Collision damage multipliers vs sedan baseline
    classDamage = {
        [0] = { engine = 0.95, body = 0.95 },
        [1] = { engine = 1.00, body = 1.00 },
        [2] = { engine = 0.85, body = 0.88 },
        [3] = { engine = 1.05, body = 1.00 },
        [4] = { engine = 1.10, body = 1.05 },
        [5] = { engine = 1.15, body = 1.02 },
        [6] = { engine = 1.40, body = 1.12 },
        [7] = { engine = 1.35, body = 1.08 },
        [8] = { engine = 1.25, body = 1.20 },
        [9] = { engine = 0.90, body = 0.82 },
        [10] = { engine = 0.70, body = 0.75 },
        [11] = { engine = 0.88, body = 0.90 },
        [12] = { engine = 0.92, body = 0.86 },
        [17] = { engine = 1.00, body = 1.00 },
        [18] = { engine = 0.80, body = 0.78 },
        [19] = { engine = 0.75, body = 0.72 },
        [20] = { engine = 0.78, body = 0.80 },
    },

    -- Optional per-model overrides (hash or model name)
    modelFuel = {
        taxi = 0.92,
        ambulance = 1.05,
        police = 1.08,
        firetruk = 1.20,
        towtruck = 1.18,
    },

    modelDamage = {
        taxi = { engine = 0.95, body = 0.95 },
        firetruk = { engine = 0.65, body = 0.60 },
        towtruck = { engine = 0.72, body = 0.68 },
    },
}

function Sunset.GetVehicleFuelMultiplier(modelHash, vehicleClass)
    local profiles = Sunset.VehicleProfiles
    if modelHash then
        for name, mult in pairs(profiles.modelFuel or {}) do
            if joaat(name) == modelHash then
                return mult
            end
        end
    end
    return (profiles.classFuel or {})[vehicleClass] or 1.0
end

function Sunset.GetVehicleDamageProfile(modelHash, vehicleClass)
    local profiles = Sunset.VehicleProfiles
    if modelHash then
        for name, row in pairs(profiles.modelDamage or {}) do
            if joaat(name) == modelHash then
                return row
            end
        end
    end
    return (profiles.classDamage or {})[vehicleClass] or { engine = 1.0, body = 1.0 }
end
