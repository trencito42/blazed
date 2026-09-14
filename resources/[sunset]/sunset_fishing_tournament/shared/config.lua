-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Fishing Tournament (shared/config.lua)
-- ═══════════════════════════════════════════════════════════════

SunsetFishingTournament = SunsetFishingTournament or {}

SunsetFishingTournament.Config = {
    -- Tournament duration (seconds)
    duration = 3600,

    -- Rewards
    rewards = {
        [1] = { cash = 15000, xp = 500, label = '1st Place' },
        [2] = { cash = 7500, xp = 250, label = '2nd Place' },
        [3] = { cash = 3000, xp = 100, label = '3rd Place' },
    },

    -- Minimum fish to qualify
    minFish = 3,
}
