-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Street Racing (shared/config.lua)
--  Race hub, routes, fees, timing, solo support.
-- ═══════════════════════════════════════════════════════════════

SunsetRacing = SunsetRacing or {}

SunsetRacing.Config = {
    -- Race hub: LS Customs parking — outdoor, flat, room for vehicles,
    -- safe access from public roads, no interior/MLO conflict.
    -- (Old location -75,-826,243 was INSIDE a skyscraper — Z=243.)
    raceHub = vector3(-1060.00, -2580.00, 20.00),

    -- Entry fee and prize pool
    entryFee = 1000,
    prizeMultiplier = 0.8, -- 80% of total entry fees goes to winner

    -- Minimum players to start a race (1 = solo time trial)
    minPlayers = 1,

    -- Solo time-trial reward (fixed, not player-funded)
    soloReward = 500,
    soloCooldownMs = 300000, -- 5 min between solo races

    -- Countdown before race starts
    countdownSeconds = 5,

    -- Race timeout (seconds) — auto-DNF if exceeded
    raceTimeout = 600,

    -- Checkpoint validation radius (meters)
    checkpointRadius = 25.0,

    -- Minimum time between checkpoint submissions (ms) — anti-speedhack
    minCheckpointIntervalMs = 1500,

    -- Race Night points
    pointsFinish = 10,
    pointsPlacement = { [1] = 15, [2] = 10, [3] = 5 }, -- bonus by placement
    pointsSoloFinish = 5,

    -- Race Night final rewards (based on points earned during the event)
    raceNightRewards = {
        { minPoints = 30, cash = 10000, xp = 300, label = 'Champion' },
        { minPoints = 15, cash = 5000, xp = 150, label = 'Veteran' },
        { minPoints = 5, cash = 2000, xp = 75, label = 'Participant' },
    },

    -- Predefined race routes (checkpoint arrays)
    -- All routes start/end at the race hub.
    routes = {
        {
            id = 'downtown',
            label = 'Downtown Sprint',
            description = 'Fast city circuit through Downtown LS',
            checkpoints = {
                vector3(-1060.00, -2580.00, 20.00),
                vector3(-800.00, -2400.00, 14.00),
                vector3(-500.00, -2200.00, 10.00),
                vector3(-300.00, -1800.00, 10.00),
                vector3(-400.00, -1400.00, 12.00),
                vector3(-600.00, -1600.00, 14.00),
                vector3(-800.00, -2000.00, 16.00),
                vector3(-1060.00, -2580.00, 20.00),
            },
        },
        {
            id = 'vinewood',
            label = 'Vinewood Hills',
            description = 'Winding roads through the hills',
            checkpoints = {
                vector3(-1060.00, -2580.00, 20.00),
                vector3(-800.00, -2400.00, 14.00),
                vector3(-500.00, -2000.00, 20.00),
                vector3(-300.00, -1500.00, 40.00),
                vector3(-200.00, -1000.00, 80.00),
                vector3(-400.00, -800.00, 100.00),
                vector3(-700.00, -1200.00, 60.00),
                vector3(-900.00, -1800.00, 30.00),
                vector3(-1060.00, -2580.00, 20.00),
            },
        },
        {
            id = 'airport',
            label = 'Airport Run',
            description = 'High-speed run to the airport and back',
            checkpoints = {
                vector3(-1060.00, -2580.00, 20.00),
                vector3(-1200.00, -2800.00, 14.00),
                vector3(-1400.00, -3000.00, 13.00),
                vector3(-1600.00, -3200.00, 13.00),
                vector3(-1400.00, -3000.00, 13.00),
                vector3(-1200.00, -2800.00, 14.00),
                vector3(-1060.00, -2580.00, 20.00),
            },
        },
    },
}
