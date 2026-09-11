SunsetTurfs = SunsetTurfs or {}

SunsetTurfs.WarDurationSec = 600 -- 10 minutes contested war
SunsetTurfs.NeutralCaptureSec = 180 -- 3 minutes solo hold to capture a free turf
SunsetTurfs.ScorePerSecond = 1
SunsetTurfs.ScorePerKill = 10
SunsetTurfs.TurfCooldownSec = 1800 -- 30 minutes cooldown after a war
SunsetTurfs.MinMembersToAttack = 1

-- Turf zone circles: pause map (M) only — matches in-world capture radius, hidden on minimap
SunsetTurfs.TurfBlipAlpha = 80
SunsetTurfs.TurfBlipAlphaWar = 120
SunsetTurfs.FreeTurfBlipColour = 27

SunsetTurfs.WeaponBlacklist = {
    [`WEAPON_RPG`] = true,
    [`WEAPON_HOMINGLAUNCHER`] = true,
    [`WEAPON_MINIGUN`] = true,
    [`WEAPON_RAILGUN`] = true,
    [`WEAPON_GRENADE`] = true,
    [`WEAPON_STICKYBOMB`] = true,
    [`WEAPON_MOLOTOV`] = true,
    [`WEAPON_COMPACTLAUNCHER`] = true,
}
