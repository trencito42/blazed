Sunset = Sunset or {}

-- Per vehicle-class tuning (GTA vehicle classes 0–22)
Sunset.VehicleProfiles = {
    -- Fuel is consumed in liters/hour, then converted to a percentage of the
    -- vehicle's real handling tank. These are gameplay values: normal driving
    -- should make fuel relevant without forcing a stop every few minutes.
    classFuelLitersPerHour = {
        [0] = 24,   -- Compacts
        [1] = 30,   -- Sedans
        [2] = 40,   -- SUVs
        [3] = 32,   -- Coupes
        [4] = 42,   -- Muscle
        [5] = 40,   -- Sports Classics
        [6] = 46,   -- Sports
        [7] = 58,   -- Super
        [8] = 16,   -- Motorcycles
        [9] = 45,   -- Off-road
        [10] = 72,  -- Industrial
        [11] = 38,  -- Utility
        [12] = 50,  -- Vans
        [13] = 0,   -- Cycles
        [14] = 95,  -- Boats
        [15] = 180, -- Helicopters
        [16] = 340, -- Planes
        [17] = 40,  -- Service
        [18] = 52,  -- Emergency
        [19] = 75,  -- Military
        [20] = 88,  -- Commercial
        [21] = 0,   -- Trains
        [22] = 65,  -- Open Wheel
    },

    consumption = {
        idleLoad = 0.07,
        baseLoad = 0.45,
        rpmLoad = 0.75,
        speedLoad = 0.25,
        throttleLoad = 0.35,
        redlineStart = 0.72,
        redlineLoad = 1.25,
        speedReferenceKmh = 160.0,
    },

    -- Tank capacity in liters (gas-can pour + display; vehicles.fuel column stays 0–100% for HUD/pump)
    classTankCapacityLiters = {
        [0] = 45,   -- Compacts
        [1] = 60,   -- Sedans
        [2] = 80,   -- SUVs
        [3] = 55,   -- Coupes
        [4] = 70,   -- Muscle
        [5] = 65,   -- Sports Classics
        [6] = 60,   -- Sports
        [7] = 55,   -- Super
        [8] = 18,   -- Motorcycles
        [9] = 75,   -- Off-road
        [10] = 120, -- Industrial
        [11] = 70,  -- Utility
        [12] = 90,  -- Vans
        [13] = 0,   -- Cycles
        [14] = 200, -- Boats
        [15] = 150, -- Helicopters
        [16] = 300, -- Planes
        [17] = 65,  -- Service
        [18] = 80,  -- Emergency
        [19] = 100, -- Military
        [20] = 150, -- Commercial
        [21] = 0,   -- Trains
        [22] = 70,  -- Open Wheel
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
    modelFuelMultiplier = {
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

function Sunset.GetGasCanMaxLiters()
    local def = Sunset.Items and Sunset.Items.gas_can
    return (def and def.maxLiters) or 20
end

-- Pump fill rates: Sunset.Config.FuelFlowLitersPerSecond / GasCanFlowLitersPerSecond

function Sunset.GetVehicleTankCapacityLiters(vehicleClass)
    local caps = Sunset.VehicleProfiles.classTankCapacityLiters or {}
    local cap = caps[vehicleClass]
    if cap and cap > 0 then return cap end
    return caps[1] or 60
end

function Sunset.PercentToTankLiters(percent, vehicleClass)
    local cap = Sunset.GetVehicleTankCapacityLiters(vehicleClass)
    return math.max(0, math.min(cap, (tonumber(percent) or 0) / 100.0 * cap))
end

function Sunset.TankLitersToPercent(liters, vehicleClass)
    local cap = Sunset.GetVehicleTankCapacityLiters(vehicleClass)
    if cap <= 0 then return 0 end
    return math.max(0, math.min(100, (tonumber(liters) or 0) / cap * 100.0))
end

function Sunset.GetVehicleFuelMultiplier(modelHash, vehicleClass)
    local profiles = Sunset.VehicleProfiles
    if modelHash then
        for name, mult in pairs(profiles.modelFuelMultiplier or {}) do
            if joaat(name) == modelHash then
                return mult
            end
        end
    end
    return 1.0
end

function Sunset.GetVehicleFuelLitersPerHour(modelHash, vehicleClass)
    local profiles = Sunset.VehicleProfiles or {}
    local classRate = (profiles.classFuelLitersPerHour or {})[vehicleClass]
    if classRate == nil then classRate = (profiles.classFuelLitersPerHour or {})[1] or 30 end
    return math.max(0, classRate * Sunset.GetVehicleFuelMultiplier(modelHash, vehicleClass))
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
