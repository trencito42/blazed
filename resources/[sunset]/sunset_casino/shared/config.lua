-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — The Diamond Casino (shared/config.lua)
--  All coordinates verified via /casinoprobe (interior id=275201).
-- ═══════════════════════════════════════════════════════════════

SunsetCasino = SunsetCasino or {}

SunsetCasino.Config = {
    -- Casino interior IPL — bob74_ipl auto-loads vw_casino_main on build >= 2060.
    ipl = 'vw_casino_main',
    interiorId = 275201,

    -- Entry marker (outside the casino, street level)
    entrance = vector3(924.64, 46.16, 81.06),
    -- Exit marker (INSIDE the casino, verified interiorExit)
    exit = vector3(1089.63, 205.89, -49.00),

    -- ── GAME TABLES (verified positions from /casinoprobe) ──
    blackjackTables = {
        vector3(1111.55, 211.61, -50.44),
        vector3(1110.05, 211.08, -50.44),
    },
    -- Actual vw_prop_casino_slot_01a entity positions
    slotMachines = {
        vector3(1114.12, 235.08, -50.84),
        vector3(1105.05, 230.84, -50.84),
        vector3(1120.85, 233.16, -50.84),
        vector3(1108.94, 239.48, -50.84),
        vector3(1135.13, 256.70, -52.04),
    },
    rouletteTable = vector3(1117.67, 218.64, -50.44),

    -- ── LUCKY WHEEL (frame exists baked in IPL at 1115.5, 248.5) ──
    -- The prize disc does NOT exist as a spawnable prop on this build.
    -- We use a NUI wheel overlay for the spin animation.
    luckyWheel = vector3(1115.50, 248.50, -49.80),

    -- ── CASHIER (cash ↔ chips) ──
    cashier = vector3(1116.03, 219.69, -49.44),

    -- ── BAR ──
    bar = vector3(1108.45, 208.87, -49.44),

    -- ── CHIPS ──
    chipExchangeRate = 1,  -- $1 = 1 chip
    minChipExchange = 100,
    maxChipExchange = 100000,

    -- ── BETTING ──
    minBet = 100,
    maxBet = 50000,

    -- ── BLACKJACK ──
    blackjackPayout = 1.5,
    dealerStandsOn = 17,

    -- ── SLOTS ──
    slotsPayouts = {
        [3] = 10,
        [2] = 2,
    },
    slotsSymbols = { '🍒', '🍋', '🔔', '💎', '7️⃣', '🍇', '⭐', '🍀' },

    -- ── ROULETTE ──
    roulettePayouts = {
        straight = 35,
        red_black = 1,
        odd_even = 1,
        low_high = 1,
        dozen = 2,
        column = 2,
    },

    -- ── LUCKY WHEEL ──
    luckyWheelCooldownMs = 3600000, -- 1 hour
    luckyWheelPrizes = {
        { label = '$5,000',        type = 'cash',   value = 5000 },
        { label = '$10,000',       type = 'cash',   value = 10000 },
        { label = '$25,000',       type = 'cash',   value = 25000 },
        { label = '$50,000',       type = 'cash',   value = 50000 },
        { label = '$100,000',      type = 'cash',   value = 100000 },
        { label = '500 Chips',     type = 'chips',  value = 500 },
        { label = '1000 Chips',    type = 'chips',  value = 1000 },
        { label = '2500 Chips',    type = 'chips',  value = 2500 },
        { label = 'Vehicle Discount', type = 'discount', value = 20 },
        { label = 'Mystery Prize', type = 'mystery', value = 0 },
        { label = 'Nothing',       type = 'none',   value = 0 },
        { label = '$2,500',        type = 'cash',   value = 2500 },
    },

    -- ── BAR DRINKS ──
    barDrinks = {
        { id = 'beer',       label = 'Beer',        price = 50,  effect = 'thirst', value = 20 },
        { id = 'wine',       label = 'Wine',        price = 100, effect = 'thirst', value = 25 },
        { id = 'whiskey',    label = 'Whiskey',     price = 150, effect = 'thirst', value = 30 },
        { id = 'cocktail',   label = 'Cocktail',    price = 200, effect = 'thirst', value = 35 },
        { id = 'champagne',  label = 'Champagne',   price = 500, effect = 'thirst', value = 50 },
    },

    -- ── LIMITS ──
    gameCooldownMs = 3000,
    dailyLossLimit = 500000,
    society = 'casino',
}
