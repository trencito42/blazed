-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Drug Pipeline (shared/config.lua)
--  Manufacture → Process → Sell. Three-stage criminal economy.
-- ═══════════════════════════════════════════════════════════════

SunsetDrugs = SunsetDrugs or {}

SunsetDrugs.Config = {
    -- Stage 1: Manufacture (harvest raw materials)
    manufacture = {
        -- Harvest spots (randomized per session)
        spots = {
            vector3(2230.00, 5578.00, 53.00),   -- Paleto Bay fields
            vector3(2400.00, 4900.00, 42.00),   -- Grapeseed
            vector3(-1200.00, 4800.00, 220.00),  -- Mount Chiliad
            vector3(1800.00, 3700.00, 33.00),   -- Sandy Shores
            vector3(-300.00, 6200.00, 31.00),   -- Paleto north
        },
        harvestTimeMs = 5000,
        yieldMin = 1,
        yieldMax = 3,
        cooldownMs = 30000,
    },

    -- Stage 2: Process (convert raw → product at a lab)
    process = {
        labs = {
            vector3(1089.00, -3100.00, -39.00),  -- Underground lab
            vector3(-1170.00, -1580.00, 4.00),   -- Del Perro warehouse
        },
        processTimeMs = 8000,
        ratio = 2, -- 2 raw → 1 product
    },

    -- Stage 3: Sell (dealers around the city)
    sell = {
        dealers = {
            vector3(-1170.00, -1580.00, 4.00),
            vector3(100.00, -1900.00, 20.00),
            vector3(-500.00, -300.00, 35.00),
            vector3(700.00, -1300.00, 26.00),
        },
        sellRadius = 5.0,
        priceVariance = { min = 0.8, max = 1.3 },
        cooldownMs = 10000,
    },

    -- Drug types
    drugs = {
        weed = {
            raw = 'weed_leaf',
            product = 'weed_brick',
            label = 'Weed',
            basePrice = 350,
        },
        coke = {
            raw = 'coke_leaf',
            product = 'coke_brick',
            label = 'Cocaine',
            basePrice = 800,
        },
        meth = {
            raw = 'meth_chemical',
            product = 'meth_bag',
            label = 'Meth',
            basePrice = 550,
        },
    },
}
