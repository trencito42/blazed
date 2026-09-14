-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — The Diamond Casino (shared/config.lua)
-- ═══════════════════════════════════════════════════════════════

SunsetCasino = SunsetCasino or {}

SunsetCasino.Config = {
    -- Casino interior IPL
    ipl = 'casino_main',

    -- Entry marker (outside the casino)
    entrance = vector3(924.64, 46.16, 81.06),
    exit = vector3(925.50, 48.00, 80.90),

    -- Game tables inside the casino
    blackjackTables = {
        vector3(1122.40, 258.50, -52.00),
        vector3(1128.00, 258.50, -52.00),
    },
    slotMachines = {
        vector3(1115.00, 262.00, -52.00),
        vector3(1118.00, 262.00, -52.00),
        vector3(1121.00, 262.00, -52.00),
        vector3(1124.00, 262.00, -52.00),
    },
    rouletteTable = vector3(1130.00, 262.00, -52.00),

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
