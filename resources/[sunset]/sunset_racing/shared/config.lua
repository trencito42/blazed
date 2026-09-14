-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Street Racing (shared/config.lua)
-- ═══════════════════════════════════════════════════════════════

SunsetRacing = SunsetRacing or {}

SunsetRacing.Config = {
    -- Race start marker
    startMarker = vector3(-75.00, -826.00, 243.00), -- LS Customs area

    -- Entry fee and prize pool
    entryFee = 1000,
    prizeMultiplier = 0.8, -- 80% of total entry fees goes to winner

    -- Minimum players to start a race
    minPlayers = 2,

    -- Countdown before race starts
    countdownSeconds = 5,

    -- Race timeout (seconds) — auto-DNF if exceeded
    raceTimeout = 600,

    -- Predefined race routes (checkpoint arrays)
    routes = {
        {
            id = 'downtown',
            label = 'Downtown Sprint',
            description = 'Fast city circuit through Downtown LS',
            checkpoints = {
                vector3(-75.00, -826.00, 243.00),
                vector3(-200.00, -900.00, 30.00),
                vector3(-400.00, -800.00, 30.00),
                vector3(-500.00, -600.00, 32.00),
                vector3(-400.00, -400.00, 33.00),
                vector3(-200.00, -350.00, 34.00),
                vector3(-75.00, -826.00, 243.00),
            },
        },
        {
            id = 'vinewood',
            label = 'Vinewood Hills',
            description = 'Winding roads through the hills',
            checkpoints = {
                vector3(-75.00, -826.00, 243.00),
                vector3(100.00, -700.00, 100.00),
                vector3(200.00, -500.00, 150.00),
                vector3(300.00, -300.00, 180.00),
                vector3(200.00, -200.00, 160.00),
                vector3(0.00, -400.00, 120.00),
                vector3(-75.00, -826.00, 243.00),
            },
        },
        {
            id = 'airport',
            label = 'Airport Run',
            description = 'High-speed run to the airport and back',
            checkpoints = {
                vector3(-75.00, -826.00, 243.00),
                vector3(-500.00, -1200.00, 20.00),
                vector3(-1000.00, -2000.00, 13.00),
                vector3(-1200.00, -2800.00, 13.00),
                vector3(-1000.00, -2000.00, 13.00),
                vector3(-500.00, -1200.00, 20.00),
                vector3(-75.00, -826.00, 243.00),
            },
        },
    },
}
