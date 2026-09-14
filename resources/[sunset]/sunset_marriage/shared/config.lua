-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Marriage System (shared/config.lua)
-- ═══════════════════════════════════════════════════════════════

SunsetMarriage = SunsetMarriage or {}

SunsetMarriage.Config = {
    -- Proposal cost
    proposalFee = 25000,

    -- Divorce cost
    divorceFee = 10000,

    -- Shared bank account
    sharedBankEnabled = true,

    -- Marriage location (chapel)
    chapel = vector3(-257.00, 6220.00, 31.00), -- Paleto Bay chapel area

    -- Proposal cooldown (seconds)
    proposalCooldown = 60,
}
