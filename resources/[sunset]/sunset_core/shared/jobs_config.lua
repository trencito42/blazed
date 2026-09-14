Sunset = Sunset or {}

--- Civilian job gameplay config (depots, routes, payouts). Hire data in jobs_civilian.lua.
Sunset.JobsConfig = {
    trucker = {
        label = 'Trucker',
        help = 'Go to the depot, spawn your rig, pick up cargo, deliver, then return the truck. Use /recovertrailer if your trailer detaches or is destroyed.',
        depot = {
            coords = vector3(1208.77, -3114.84, 5.54),
            spawn = vector4(1245.58, -3135.42, 5.54, 90.0),
            trailerSpawn = vector4(1255.0, -3135.42, 5.54, 90.0),
            blip = { sprite = 477, color = 5, scale = 0.85 },
        },
        -- Truck model pool per delivery category.
        -- hasTrailer = true  → spawn + validate a cargo trailer (semi routes).
        -- hasTrailer = false → rigid box truck, no trailer.
        categoryTrucks = {
            convenience = { models = {'mule', 'mule3'},       hasTrailer = false },
            fuel        = { models = {'phantom'},              hasTrailer = true,  trailerModel = 'tanker' },
            restaurant  = { models = {'benson', 'benson2'},   hasTrailer = false },
            industrial  = { models = {'benson2', 'pounder2'}, hasTrailer = false },
            pharma      = { models = {'pounder', 'pounder2'}, hasTrailer = false },
            premium     = { models = {'pounder2', 'pounder'}, hasTrailer = false },
        },
        truckModel   = 'phantom',   -- fallback if category not in categoryTrucks
        trailerModel = 'trailers2', -- used only when hasTrailer = true
        -- Delivery categories: convenience, fuel, restaurant, industrial, pharma, premium.
        -- All routes are available from rank 1. Higher rank = pay bonus (see server/trucker.lua).
        routes = {
            -- ── Convenience (24/7 stores) ─────────────────────────────────
            { category = 'convenience', pay = 650,
              pickup   = vector3(892.15, -3204.55, 5.90),
              delivery = vector3(2673.27, 3513.14, 52.71),
              label    = 'Terminal → Harmony 24/7' },
            { category = 'convenience', pay = 600,
              pickup   = vector3(-424.88, -2789.33, 6.0),
              delivery = vector3(-706.0, -913.0, 19.2),
              label    = 'Docks → Mirror Park 24/7' },

            -- ── Fuel (Gas Stations) ───────────────────────────────────────
            { category = 'fuel', pay = 720,
              pickup   = vector3(-424.88, -2789.33, 6.0),
              delivery = vector3(1702.55, 6416.12, 32.76),
              label    = 'Docks → Paleto Bay Gas Station' },
            { category = 'fuel', pay = 680,
              pickup   = vector3(892.15, -3204.55, 5.90),
              delivery = vector3(1181.2, 2671.5, 37.9),
              label    = 'Terminal → Sandy Shores Gas Station' },

            -- ── Restaurant ────────────────────────────────────────────────
            { category = 'restaurant', pay = 850,
              pickup   = vector3(892.15, -3204.55, 5.90),
              delivery = vector3(-1037.27, -250.68, 37.29),
              label    = 'Freight → Vinewood Restaurant' },
            { category = 'restaurant', pay = 800,
              pickup   = vector3(2747.32, 3472.88, 55.67),
              delivery = vector3(-266.0, -715.0, 33.7),
              label    = 'Sandy Shores → Rockford Hills Diner' },

            -- ── Industrial ────────────────────────────────────────────────
            { category = 'industrial', pay = 950,
              pickup   = vector3(2747.32, 3472.88, 55.67),
              delivery = vector3(-219.45, -2419.88, 6.0),
              label    = 'Sandy Shores → South Docks' },
            { category = 'industrial', pay = 1100,
              pickup   = vector3(-195.46, -2530.22, 6.0),
              delivery = vector3(438.10, -1990.69, 23.74),
              label    = 'South Port → Construction Site' },
            { category = 'industrial', pay = 1050,
              pickup   = vector3(892.15, -3204.55, 5.90),
              delivery = vector3(-337.0, -1513.0, 27.7),
              label    = 'Terminal → Davis Lumber Yard' },

            -- ── Pharmaceutical ────────────────────────────────────────────
            { category = 'pharma', pay = 1400,
              pickup   = vector3(-195.46, -2530.22, 6.0),
              delivery = vector3(307.73, -1569.00, 29.25),
              label    = 'Cold Storage → Central Hospital' },
            { category = 'pharma', pay = 1350,
              pickup   = vector3(892.15, -3204.55, 5.90),
              delivery = vector3(-248.0, 6329.0, 31.4),
              label    = 'Terminal → Paleto Bay Clinic' },

            -- ── Premium ───────────────────────────────────────────────────
            { category = 'premium', pay = 1800,
              pickup   = vector3(892.15, -3204.55, 5.90),
              delivery = vector3(-1626.00, 5191.00, 1.00),
              label    = 'Terminal → Paleto Premium Depot' },
            { category = 'premium', pay = 2000,
              pickup   = vector3(-424.88, -2789.33, 6.0),
              delivery = vector3(2747.32, 3472.88, 55.67),
              label    = 'Docks → Sandy Shores Warehouse' },
        },
        xpPerDelivery = 45,
        timeoutSec = 1800,
        deliveryRadius = 25.0,
        deliveryZTolerance = 8.0,
        returnRadius = 25.0,
        requiresWorkVehicle = true,
        vehicleExitGraceSec = 60,
        requiresAttachedTrailer = true,
        trailerGraceSec = 60,
        trailerRecoveryCooldownSec = 180,
        trailerRecoveryMaxUses = 3,
        trailerRecoveryMaxDistance = 30.0,
        trailerLossPartialPayFraction = 0.5,
    },

    garbage = {
        label = 'Garbage Collector',
        help = 'Drive to bins, pick up trash (E), dump at the truck rear, then unload at the depot when full.',
        depot = {
            coords = vector3(-321.70, -1545.94, 27.72),
            spawn = vector4(-341.12, -1530.45, 27.72, 270.0),
            unload = vector3(-350.45, -1560.22, 25.22),
            blip = { sprite = 318, color = 2, scale = 0.85 },
        },
        truckModel = 'trash',
        capacity = 8,
        bins = {
            vector3(-128.45, -1415.22, 29.35),
            vector3(45.12, -1398.55, 29.35),
            vector3(180.88, -1315.45, 29.22),
            vector3(295.45, -1270.12, 29.45),
            vector3(-55.22, -1755.88, 29.42),
            vector3(120.55, -1688.22, 29.30),
            vector3(380.12, -1512.45, 29.28),
            vector3(510.88, -1455.22, 29.28),
            vector3(-200.45, -1605.12, 33.48),
            vector3(-350.22, -1470.88, 30.55),
        },
        payPerBin = 48,
        payPerUnload = 120,
        xpPerBin = 12,
        xpPerUnload = 30,
        collectRadius = 3.0,
        dumpRadius = 3.5,
        truckRearOffset = -4.5,
        timeoutSec = 1500,
        requiresWorkVehicle = true,
        vehicleExitGraceSec = 60,
    },

    courier = {
        label = 'Courier',
        help = 'Pick up packages at the warehouse and deliver them on foot.',
        warehouse = {
            coords = vector3(78.45, 112.22, 81.17),
            blip = { sprite = 478, color = 3, scale = 0.85 },
        },
        deliveries = {
            { coords = vector3(-47.22, -1758.45, 29.42), label = 'Davis Ave' },
            { coords = vector3(213.88, -810.45, 30.73), label = 'Legion Square' },
            { coords = vector3(-706.22, -914.55, 19.22), label = 'Little Seoul' },
            { coords = vector3(373.45, -828.22, 29.28), label = 'Pillbox Hill' },
            { coords = vector3(-1288.45, -1115.22, 6.99), label = 'Vespucci Canals' },
            { coords = vector3(127.55, -1298.88, 29.22), label = 'Strawberry' },
        },
        packageProp = 'prop_cs_cardbox_01',
        packagesPerRun = 4,
        payPerPackage = 75,
        xpPerPackage = 18,
        deliveryRadius = 2.5,
        pickupRadius = 3.5,
        pickupZTolerance = 5.0,
        timeoutSec = 1200,
    },

    fisherman = {
        label = 'Fisherman',
        help = 'Fish in the Paleto Bay area near Billy Ray, then sell your catch at any 24/7 store.',
        -- [ZONE FIX] The fishing spot is the measured water/pontoon area, NOT the
        -- NPC position. GPS/objective point here on shift start.
        -- Derived from the centroid of the previously measured waterfront strip.
        spots = {
            { coords = vector3(-1600.56, 5237.43, 1.0) },
        },
        -- [ZONE FIX] Old polygon spanned y=5211..5265 only — it lay entirely
        -- NORTH of Billy Ray (y=5207.74) and the bait shop (y=5203.87), so the
        -- ray-casting test returned false at every real fishing position and
        -- /fish always answered "not in the Paleto Bay fishing area".
        -- New zone covers both VERIFIED anchors (Billy Ray, bait shop) plus the
        -- previously measured waterfront strip, i.e. the whole pier/waterfront.
        -- Rectangle: x -1620..-1578, y 5195..5268.
        -- Refine with /fishdebug in-game if the shoreline needs tightening.
        fishZone = {
            { x = -1620.00, y = 5195.00 },
            { x = -1578.00, y = 5195.00 },
            { x = -1578.00, y = 5268.00 },
            { x = -1620.00, y = 5268.00 },
        },
        fishZoneMinZ = -5.0,   -- include barca pe apa
        fishZoneMaxZ = 12.0,   -- include pontoon/dig ridicat
        biteDelayMinMs = 2500,
        biteDelayMaxMs = 6500,
        reactionWindowMs = 1500,
        catchRadius    = 50.0,   -- fallback daca fishZone lipseste
        catchZTolerance = 8.0,   -- fallback Z tolerance
        markerSize     = 2.0,    -- visible water marker at the fishing spot
        markerDrawRadius = 80.0, -- draw it while approaching on shift
        -- [FIX] sellPoint was missing — cfg.sellPoint.coords crashed on
        -- every sell attempt. Coordinates from items.lua 24/7 Paleto Bay.
        sellPoint = { coords = vector3(-54.37, 6244.70, 31.09) },
        sellRadius = 5.0,
        catchPayMin = 28,
        catchPayMax = 85,
        fishItem = 'fresh_fish',
        carryBase = 2,
        carryPerLevel = 1,
        carryMax = 12,
        xpPerCatch = 15,
        sellBonusMultiplier = 1.15,
        timeoutSec = 900,
    },

    mechanic = {
        label = 'Roadside Mechanic',
        help = 'Go on duty to accept /service mechanic calls. Repair vehicles to earn pay.',
        depot = {
            coords = vector3(-347.45, -133.22, 39.01),
            blip = { sprite = 446, color = 5, scale = 0.85 },
        },
        repairRadius = 6.0,
        repairDurationMs = 12000,
        payPerRepair = 160,
        xpPerRepair = 25,
        healthRestoreMin = 400,
        healthRestoreMax = 1000,
        timeoutSec = 2400,
        dispatchServiceType = 'mechanic',
    },
}

function Sunset.GetJobConfig(jobId)
    return Sunset.JobsConfig and Sunset.JobsConfig[jobId]
end
