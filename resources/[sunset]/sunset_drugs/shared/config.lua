-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Drug Pipeline (shared/config.lua)
--  Manufacture → Process → Sell. Three-stage criminal economy.
--
--  DESIGN (OPTION A): each harvest spot grows ONE specific drug type.
--  The drug type is derived SERVER-SIDE from the spot config — the client
--  never chooses the authoritative type.
-- ═══════════════════════════════════════════════════════════════

SunsetDrugs = SunsetDrugs or {}

SunsetDrugs.Config = {
    -- Stage 1: Manufacture (harvest raw materials).
    -- Each spot has an explicit drug type (Option A — no random harvest).
    -- NOTE: coords require in-game accessibility QA (Z values were not
    -- verified against terrain; see CASINO-style discovery discipline).
    manufacture = {
        spots = {
            { coords = vector3(2230.00, 5578.00, 53.00),  drug = 'weed', label = 'Paleto Bay fields' },
            { coords = vector3(2400.00, 4900.00, 42.00),  drug = 'weed', label = 'Grapeseed' },
            { coords = vector3(-1200.00, 4800.00, 220.00), drug = 'meth', label = 'Mount Chiliad' },
            { coords = vector3(1800.00, 3700.00, 33.00),  drug = 'coke', label = 'Sandy Shores' },
            { coords = vector3(-300.00, 6200.00, 31.00),  drug = 'coke', label = 'Paleto north' },
        },
        harvestTimeMs = 5000,
        yieldMin = 1,
        yieldMax = 3,
        cooldownMs = 30000,
        spotRadius = 10.0,
    },

    -- Stage 2: Process (convert raw → product at a lab)
    -- NOTE: lab #1 (1089,-3100,-39) is an underground coordinate —
    -- requires in-game accessibility QA (may be inside an un-loaded MLO).
    process = {
        labs = {
            vector3(1089.00, -3100.00, -39.00),  -- Underground lab (QA required)
            vector3(-1170.00, -1580.00, 4.00),   -- Del Perro warehouse
        },
        processTimeMs = 8000,
        ratio = 2, -- 2 raw → 1 product
        labRadius = 10.0,
        cooldownMs = 5000,
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
        maxAmount = 10,
    },

    -- Drug types with EXPLICIT raw/product labels (no blind ' Leaf'/' Brick'
    -- concatenation — 'Meth Leaf' was wrong for meth_chemical).
    drugs = {
        weed = {
            raw = 'weed_leaf',
            product = 'weed_brick',
            label = 'Weed',
            rawLabel = 'Weed Leaves',
            productLabel = 'Weed Brick',
            basePrice = 350,
        },
        coke = {
            raw = 'coke_leaf',
            product = 'coke_brick',
            label = 'Cocaine',
            rawLabel = 'Coca Leaves',
            productLabel = 'Cocaine Brick',
            basePrice = 800,
        },
        meth = {
            raw = 'meth_chemical',
            product = 'meth_bag',
            label = 'Meth',
            rawLabel = 'Meth Chemicals',
            productLabel = 'Meth Bag',
            basePrice = 550,
        },
    },
}
