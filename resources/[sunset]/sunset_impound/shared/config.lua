-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Vehicle Impound (shared/config.lua)
-- ═══════════════════════════════════════════════════════════════

SunsetImpound = SunsetImpound or {}

SunsetImpound.Config = {
    -- Impound lot location (marker + recovery point)
    lot = vector3(409.30, -1623.00, 29.30),
    lotHeading = 230.0,

    -- Fees
    baseFee = 500,
    dailyFee = 100,

    -- Auto-sell after N days if not recovered
    autoSellDays = 7,

    -- Impound reasons (police select from these)
    reasons = {
        { id = 'no_license', label = 'Driving without a license', fee = 500 },
        { id = 'reckless', label = 'Reckless driving', fee = 750 },
        { id = 'stolen', label = 'Stolen vehicle', fee = 1000 },
        { id = 'illegal_mods', label = 'Illegal modifications', fee = 600 },
        { id = 'evading', label = 'Evading police', fee = 1500 },
        { id = 'other', label = 'Other', fee = 500 },
    },
}
