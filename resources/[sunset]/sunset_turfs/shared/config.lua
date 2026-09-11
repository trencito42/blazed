SunsetTurfs = SunsetTurfs or {}

SunsetTurfs.WarDurationSec = 600 -- 10 minutes contested war
SunsetTurfs.NeutralCaptureSec = 180 -- 3 minutes solo hold to capture a free turf
SunsetTurfs.ScorePerSecond = 1
SunsetTurfs.ScorePerKill = 10
SunsetTurfs.TurfCooldownSec = 1800 -- 30 minutes cooldown after a war
SunsetTurfs.MinMembersToAttack = 1

-- SAMP-style coloured rectangles on pause map + minimap (AddBlipForArea)
SunsetTurfs.TurfBlipAlpha = 95
SunsetTurfs.TurfBlipAlphaWar = 140
SunsetTurfs.FreeTurfBlipColour = 27 -- purple, neutral gang zone

-- Optional per-turf map shape (width/height in world units, rotation in degrees)
-- Omit an id to auto-size a square from turf.radius * 2
SunsetTurfs.MapZones = {
    [1] = { width = 250.0, height = 200.0, rotation = 50.0 },
    [3] = { width = 240.0, height = 190.0, rotation = 48.0 },
    [11] = { width = 300.0, height = 170.0, rotation = 25.0 },
    [12] = { width = 260.0, height = 180.0, rotation = 35.0 },
    [15] = { width = 320.0, height = 220.0, rotation = 0.0 },
}

function SunsetTurfs.GetMapZone(turfId, turf)
    local custom = SunsetTurfs.MapZones and SunsetTurfs.MapZones[turfId]
    local radius = turf and (tonumber(turf.radius) or 110.0) or 110.0
    return {
        width = custom and custom.width or (radius * 2.0),
        height = custom and custom.height or (radius * 2.0),
        rotation = custom and custom.rotation or 0.0,
    }
end

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
