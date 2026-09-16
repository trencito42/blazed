-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — The Diamond Casino (shared/config.lua)
-- ═══════════════════════════════════════════════════════════════

SunsetCasino = SunsetCasino or {}

SunsetCasino.Config = {
    -- Casino interior IPL — bob74_ipl auto-loads vw_casino_main on build >= 2060.
    -- 'casino_main' does NOT exist; RequestIpl('casino_main') is dead code.
    -- We keep the name for reference but do NOT call RequestIpl on it.
    ipl = 'vw_casino_main',

    -- Entry marker (outside the casino, street level)
    entrance = vector3(924.64, 46.16, 81.06),
    -- Exit marker (INSIDE the casino, near the interior exit door)
    -- Verified via /casinoprobe: interiorExit = 1089.63, 205.89, -49.00
    exit = vector3(1089.63, 205.89, -49.00),

    -- Game tables inside the casino (Z ≈ -50.5, verified via /casinoprobe)
    -- Slot machine positions from actual vw_prop_casino_slot_01a entities
    blackjackTables = {
        vector3(1111.55, 211.61, -50.44),
        vector3(1110.05, 211.08, -50.44),
    },
    slotMachines = {
        vector3(1114.12, 235.08, -50.84),
        vector3(1105.05, 230.84, -50.84),
        vector3(1120.85, 233.16, -50.84),
        vector3(1108.94, 239.48, -50.84),
    },
    rouletteTable = vector3(1117.67, 218.64, -50.44),

    -- Betting limits
    minBet = 100,
    maxBet = 50000,

    -- Blackjack rules
    blackjackPayout = 1.5,   -- 3:2 on blackjack
    dealerStandsOn = 17,     -- dealer stands on soft 17

    -- Slots payout table (multiplier of bet)
    slotsPayouts = {
        [3] = 10,   -- three matching = 10x
        [2] = 2,    -- two matching = 2x
    },

    -- Roulette payouts
    roulettePayouts = {
        straight = 35,    -- single number
        red_black = 1,    -- red/black
        odd_even = 1,     -- odd/even
        low_high = 1,     -- 1-18 / 19-36
        dozen = 2,        -- 1st/2nd/3rd dozen
        column = 2,       -- column bet
    },

    -- Cooldown between games (anti-spam)
    gameCooldownMs = 3000,

    -- Daily loss limit (responsible gambling)
    dailyLossLimit = 500000,

    -- Casino society (money sink)
    society = 'casino',
}
