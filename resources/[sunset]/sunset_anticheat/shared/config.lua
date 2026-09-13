-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield anticheat (shared/config.lua)
--  Spec: docs/ANTICHEAT_SPEC.md §8. Mode starts at 'log_only'
--  per the rollout protocol (no FP bans; tune before enforce).
-- ═══════════════════════════════════════════════════════════════

SunsetAnticheat = SunsetAnticheat or {}

SunsetAnticheat.Config = {
    Enabled = true,
    Mode = 'log_only',           -- 'log_only' = record ticks, no GUI noise (Phase 1 rollout mode!)
    TickLifetimeSec = 1800,
    Heat = { watch = 3, suspect = 6, critical = 10 },
    AutoKickOnEconomyInjection = true,   -- the ONLY auto-action
    AutoBanAnything = false,             -- must stay false. ever.
    PingExemptMs = 250,
    Detectors = {
        speed    = { enabled = true, margin = 1.35, sustainSamples = 3, cooldown = 60 },
        teleport = { enabled = true, cooldown = 30 },
        fly      = { enabled = true, cooldown = 120 },
        damage   = { enabled = true, cooldown = 60 },
        health   = { enabled = true, cooldown = 60 },
        weapon   = { enabled = true, cooldown = 300 },
        ammo     = { enabled = true, cooldown = 600 },
        vehspawn = { enabled = true, cooldown = 120 },
        economy  = { enabled = true },
        spam     = { enabled = true, nuiPerMin = 30, chatPerMin = 20 },
        movement = { enabled = true, cooldown = 300 },
        ped      = { enabled = true, cooldown = 120 },
        plate    = { enabled = false },          -- off by default, cosmetic
        heartbeat= { enabled = true, cooldown = 300 },
        aimstats = { enabled = true, logOnly = true, locked = true },  -- can never tick
    },
    Hud = { enabled = true, defaultPos = 'topright' },
    Discord = { channel = 'anticheat', dailySummary = true },
}

-- Per-vehicle-class top speed ceiling in m/s (server GetVehicleClass).
-- Classes not listed here (boat 14, heli 15, plane 16, train 21) are
-- EXEMPT from speed/teleport-in-vehicle checks per spec §4.1.
SunsetAnticheat.ClassMaxSpeed = {
    [0]  = 42.0,  -- compact
    [1]  = 45.0,  -- sedan
    [2]  = 45.0,  -- SUV
    [3]  = 48.0,  -- coupe
    [4]  = 47.0,  -- muscle
    [5]  = 48.0,  -- sports classic
    [6]  = 55.0,  -- sports
    [7]  = 62.0,  -- super
    [8]  = 50.0,  -- motorcycle
    [9]  = 40.0,  -- off-road
    [10] = 35.0,  -- industrial
    [11] = 38.0,  -- utility
    [12] = 38.0,  -- van
    [13] = 15.0,  -- cycle
    [17] = 38.0,  -- service
    [18] = 50.0,  -- emergency
    [19] = 40.0,  -- military
    [20] = 35.0,  -- commercial
    [22] = 60.0,  -- open wheel
}
