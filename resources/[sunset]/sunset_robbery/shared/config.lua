SunsetRobbery = SunsetRobbery or {}

SunsetRobbery.Debug = false

SunsetRobbery.MinPolice = 3
SunsetRobbery.PlayerCooldownSec = 30 * 60
SunsetRobbery.LocationCooldownSec = 45 * 60
SunsetRobbery.RobPointsPerPayday = 1
SunsetRobbery.RobPointsToStart = 1
SunsetRobbery.HackTimeSec = 34
SunsetRobbery.HackTraceFail = 100
SunsetRobbery.HackWrongClickTrace = 18
SunsetRobbery.PerfectHackDelaySec = 20
SunsetRobbery.NormalHackDelaySec = 5
SunsetRobbery.FailedHackDelaySec = 0
SunsetRobbery.BagCapacity = 12
SunsetRobbery.EscapeRadius = 300.0
SunsetRobbery.StoreInteractRadius = 2.0
SunsetRobbery.StartRadius = 18.0
SunsetRobbery.DisplayLootCount = { min = 6, max = 10 }
SunsetRobbery.PoliceEscalateSec = 20
SunsetRobbery.PoliceVehicleSec = 40
SunsetRobbery.RateLimitMs = 220
SunsetRobbery.RequiredItem = 'lockpick'
SunsetRobbery.BlockedFactions = { police = true, sheriff = true, fib = true }

SunsetRobbery.Fence = {
    label = 'Fence',
    coords = vector3(153.18, -3211.72, 5.91),
    heading = 90.0,
    interact = 2.0,
    blip = { sprite = 500, color = 5, scale = 0.8, label = 'Fence — Black Market' },
    demand = {
        watch = 1.12,
        jewelry = 0.94,
        gold = 0.90,
    },
}

SunsetRobbery.LootTables = {
    watches = {
        { id = 'stolen_silver_watch', label = 'Silver Watch', tier = 'COMMON', weight = 1, baseValue = 850, rarity = 45, family = 'watch' },
        { id = 'stolen_luxury_watch', label = 'Luxury Watch', tier = 'RARE', weight = 1, baseValue = 4200, rarity = 28, family = 'watch' },
        { id = 'stolen_gold_watch', label = 'Gold Watch', tier = 'RARE', weight = 1, baseValue = 3600, rarity = 18, family = 'watch' },
        { id = 'stolen_diamond_watch', label = 'Diamond Watch', tier = 'EPIC', weight = 2, baseValue = 7800, rarity = 7, family = 'watch' },
        { id = 'stolen_collector_watch', label = 'Collector Watch', tier = 'VERY_RARE', weight = 2, baseValue = 12500, rarity = 2, family = 'watch' },
    },
    jewelry = {
        { id = 'stolen_bracelet', label = 'Basic Bracelet', tier = 'COMMON', weight = 1, baseValue = 620, rarity = 42, family = 'jewelry' },
        { id = 'stolen_gold_chain', label = 'Gold Chain', tier = 'RARE', weight = 1, baseValue = 2900, rarity = 26, family = 'gold' },
        { id = 'stolen_gold_bracelet', label = 'Gold Bracelet', tier = 'RARE', weight = 1, baseValue = 2400, rarity = 20, family = 'gold' },
        { id = 'stolen_diamond_jewelry', label = 'Designer Jewelry', tier = 'EPIC', weight = 2, baseValue = 6900, rarity = 9, family = 'jewelry' },
        { id = 'stolen_collector_watch', label = 'Collector Piece', tier = 'VERY_RARE', weight = 2, baseValue = 11000, rarity = 3, family = 'jewelry' },
    },
}

SunsetRobbery.SellVariance = { min = 0.72, max = 0.88 }

SunsetRobbery.Animations = {
    hack = { dict = 'anim@heists@keypad@', clip = 'idle_a', flag = 49 },
    smash = { dict = 'missheist_jewel', clip = 'smash_case', flag = 0 },
    grab = { dict = 'missheist_jewel', clip = 'pickup_necklace_e', flag = 0 },
    bag = { dict = 'anim@heists@ornate_bank@ig_4_grab_gold', clip = 'idle', flag = 49 },
    fence = { dict = 'mp_common', clip = 'givetake1_a', flag = 0 },
}

SunsetRobbery.Sounds = {
    terminal = { name = 'PIN_BUTTON', set = 'ATM_SOUNDS' },
    hackOk = { name = 'Hack_Success', set = 'DLC_HEIST_FLEECA_SOUNDSET' },
    hackFail = { name = 'Hack_Failed', set = 'DLC_HEIST_FLEECA_SOUNDSET' },
    glass = { name = 'Glass_Smash', set = 'BREATHING_SWIM_SOUNDSET' },
    pickup = { name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    bag = { name = 'PICK_UP_WEAPON', set = 'HUD_FRONTEND_CUSTOM_SOUNDSET' },
    alarm = { name = 'CHECKPOINT_MISSED', set = 'HUD_MINI_GAME_SOUNDSET' },
    complete = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },
}

SunsetRobbery.BagProp = {
    model = `prop_cs_heist_bag_02`,
    bone = 24818,
    pos = vector3(0.06, -0.22, -0.02),
    rot = vector3(0.0, 90.0, 180.0),
}

SunsetRobbery.Locations = {
    luxury_store = {
        id = 'luxury_store',
        label = 'Vangelico Luxury Watches',
        street = 'Rockford Drive',
        zone = 'Rockford Hills',
        coords = vector3(-622.25, -230.93, 38.06),
        radius = 22.0,
        minPolice = nil,
        startHint = '[E] Start robbery',
        blip = { sprite = 617, color = 1, scale = 0.9, label = 'Robbery — Vangelico' },
        entrance = {
            coords = vector3(-631.04, -237.76, 38.08),
            radius = 5.0,
        },
        doors = {
            { model = `p_jewel_door_l`, coords = vector3(-631.96, -236.33, 38.21) },
            { model = `p_jewel_door_r`, coords = vector3(-630.43, -238.44, 38.21) },
        },
        hackTerminal = {
            coords = vector3(-631.02, -230.06, 38.06),
            heading = 35.0,
            label = '[E] Bypass security',
        },
        displays = {
            { id = 'd1', coords = vector3(-626.73, -235.42, 38.06), lootTable = 'watches', label = 'Luxury Watches' },
            { id = 'd2', coords = vector3(-625.68, -237.46, 38.06), lootTable = 'watches', label = 'Display Watches' },
            { id = 'd3', coords = vector3(-623.08, -232.96, 38.06), lootTable = 'jewelry', label = 'Diamond Jewelry' },
            { id = 'd4', coords = vector3(-620.24, -234.38, 38.06), lootTable = 'jewelry', label = 'Designer Case' },
            { id = 'd5', coords = vector3(-617.86, -230.48, 38.06), lootTable = 'watches', label = 'Gold Watches' },
            { id = 'd6', coords = vector3(-619.20, -227.28, 38.06), lootTable = 'jewelry', label = 'Gold Bracelets' },
        },
    },
}
