-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Street Racing (shared/config.lua)
--  Race hub, routes, fees, timing, solo/multiplayer split.
-- ═══════════════════════════════════════════════════════════════

SunsetRacing = SunsetRacing or {}

SunsetRacing.Config = {
    -- Race hub: LS Customs parking — outdoor, flat, room for vehicles.
    raceHub = vector3(-1060.00, -2580.00, 20.00),

    -- ── MULTIPLAYER ──
    entryFee = 1000,
    prizeMultiplier = 0.8,       -- 80% of pot goes to winner
    minMultiPlayers = 2,         -- minimum players for multiplayer race
    lobbyAutoStartDelay = 5000,  -- ms after reaching minMultiPlayers before auto-start

    -- ── SOLO TIME TRIAL ──
    soloEntryFee = 0,            -- solo is free (no entry fee)
    soloReward = 500,            -- fixed reward per completed solo race
    soloCooldownMs = 300000,     -- 5 min between solo races (per character)

    -- ── RACE ──
    countdownSeconds = 5,
    raceTimeout = 600,           -- seconds — auto-end if exceeded
    checkpointRadius = 25.0,     -- meters
    minCheckpointIntervalMs = 1500,

    -- ── RACE NIGHT ──
    pointsFinish = 10,
    pointsPlacement = { [1] = 15, [2] = 10, [3] = 5 },
    pointsSoloFinish = 5,
    raceNightRewards = {
        { minPoints = 30, cash = 10000, xp = 300, label = 'Champion' },
        { minPoints = 15, cash = 5000, xp = 150, label = 'Veteran' },
        { minPoints = 5, cash = 2000, xp = 75, label = 'Participant' },
    },

    -- ── ROUTES ──
    -- start = race hub (start line, NOT a checkpoint)
    -- checkpoints = actual race progression (first CP is AWAY from hub)
    -- finish = last checkpoint (back at hub)
    routes = {
        {
            id = 'downtown',
            label = 'Downtown Sprint',
            description = 'Fast city circuit through South LS and Downtown',
            start = vector3(-1060.00, -2580.00, 20.00),
            checkpoints = {
                vector3(-1060.00, -2390.00, 14.00),  -- Dutch London St North
                vector3(-1040.00, -2000.00, 13.20),  -- Dutch London St / Signal St
                vector3(-920.00, -1530.00, 5.20),    -- Innocence Blvd entrance
                vector3(-500.00, -1250.00, 14.50),   -- Strawberry Ave / Innocence
                vector3(-100.00, -1000.00, 29.30),   -- Legion Square / Olympic on-ramp
                vector3(150.00, -1100.00, 29.20),    -- Olympic Fwy heading West
                vector3(-200.00, -1450.00, 31.00),   -- Olympic Fwy overpass
                vector3(-600.00, -1950.00, 10.00),   -- La Puerta Fwy South
                vector3(-900.00, -2350.00, 14.00),   -- Dutch London St approach
                vector3(-1060.00, -2580.00, 20.00),  -- Finish line at hub
            },
        },
        {
            id = 'airport',
            label = 'Airport High-Speed',
            description = 'High-speed loop around Los Santos International Airport',
            start = vector3(-1060.00, -2580.00, 20.00),
            checkpoints = {
                vector3(-1080.00, -2650.00, 19.80),  -- Exit LS Customs towards Greenwich
                vector3(-1200.00, -2800.00, 13.90),  -- Greenwich Parkway Westbound
                vector3(-1450.00, -2950.00, 13.90),  -- Exceptionalist Way / Airport approach
                vector3(-1600.00, -3150.00, 13.90),  -- LSIA Terminal Loop entrance
                vector3(-1400.00, -3250.00, 13.90),  -- LSIA Lower Terminal drive
                vector3(-1150.00, -3150.00, 13.90),  -- LSIA Terminal Loop exit
                vector3(-1000.00, -2950.00, 13.90),  -- New Empire Way Northbound
                vector3(-1030.00, -2700.00, 19.50),  -- Approaching Hub
                vector3(-1060.00, -2580.00, 20.00),  -- Finish line at hub
            },
        },
        {
            id = 'vinewood',
            label = 'Vinewood Boulevard',
            description = 'Sprint from docks through the heart of Vinewood and back',
            start = vector3(-1060.00, -2580.00, 20.00),
            checkpoints = {
                vector3(-1060.00, -2390.00, 14.00),  -- Dutch London North
                vector3(-800.00, -1800.00, 15.00),   -- La Puerta Freeway North
                vector3(-500.00, -1000.00, 24.00),   -- San Andreas Blvd
                vector3(-250.00, -400.00, 44.00),    -- Alta St / Hawick
                vector3(100.00, 200.00, 88.00),      -- Vinewood Blvd East
                vector3(350.00, 0.00, 75.00),        -- Power St Southbound
                vector3(200.00, -800.00, 31.00),     -- Olympic Freeway on-ramp
                vector3(-400.00, -1500.00, 18.00),   -- La Puerta Southbound
                vector3(-850.00, -2200.00, 14.00),   -- Dutch London approach
                vector3(-1060.00, -2580.00, 20.00),  -- Finish line at hub
            },
        },
    },
}
