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
            description = 'Fast city circuit through Downtown LS',
            start = vector3(-1060.00, -2580.00, 20.00),
            checkpoints = {
                vector3(-800.00, -2400.00, 14.00),
                vector3(-500.00, -2200.00, 10.00),
                vector3(-300.00, -1800.00, 10.00),
                vector3(-400.00, -1400.00, 12.00),
                vector3(-600.00, -1600.00, 14.00),
                vector3(-800.00, -2000.00, 16.00),
                vector3(-1060.00, -2580.00, 20.00),  -- finish at hub
            },
        },
        {
            id = 'vinewood',
            label = 'Vinewood Hills',
            description = 'Winding roads through the hills',
            start = vector3(-1060.00, -2580.00, 20.00),
            checkpoints = {
                vector3(-800.00, -2400.00, 14.00),
                vector3(-500.00, -2000.00, 20.00),
                vector3(-300.00, -1500.00, 40.00),
                vector3(-200.00, -1000.00, 80.00),
                vector3(-400.00, -800.00, 100.00),
                vector3(-700.00, -1200.00, 60.00),
                vector3(-900.00, -1800.00, 30.00),
                vector3(-1060.00, -2580.00, 20.00),  -- finish at hub
            },
        },
        {
            id = 'airport',
            label = 'Airport Run',
            description = 'High-speed run to the airport and back',
            start = vector3(-1060.00, -2580.00, 20.00),
            checkpoints = {
                vector3(-1200.00, -2800.00, 14.00),
                vector3(-1400.00, -3000.00, 13.00),
                vector3(-1600.00, -3200.00, 13.00),
                vector3(-1400.00, -3000.00, 13.00),
                vector3(-1200.00, -2800.00, 14.00),
                vector3(-1060.00, -2580.00, 20.00),  -- finish at hub
            },
        },
    },
}
