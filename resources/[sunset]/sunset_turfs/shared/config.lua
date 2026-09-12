SunsetTurfs = SunsetTurfs or {}

SunsetTurfs.WarDurationSec = 600 -- 10 minutes contested war
SunsetTurfs.NeutralCaptureSec = 180 -- 3 minutes solo hold to capture a free turf
SunsetTurfs.ScorePerSecond = 1
SunsetTurfs.ScorePerKill = 10
-- [WAR REDESIGN] Kill-based contested war: first clan to WarScoreTarget wins
-- instantly; otherwise higher score at timer end wins (defender wins ties).
SunsetTurfs.WarScoreTarget = 300
SunsetTurfs.RespawnDelaySec = 5
SunsetTurfs.TurfCooldownSec = 1800 -- 30 minutes cooldown after a war
SunsetTurfs.MinMembersToAttack = 1

-- [WAR REDESIGN] Armory loadout packages (clanwars.html UI 1:1).
-- Weapons are REAL GTA weapon hashes; no RPG/minigun/launcher (WeaponBlacklist
-- still enforced by core security). rank = minimum clan rank, cost = cash.
SunsetTurfs.Loadouts = {
    {
        id = 'standard', name = 'Pachet Standard', rank = 1, cost = 0,
        weapons = {
            { weapon = 'WEAPON_PISTOL', ammo = 150, label = 'Pistol', tag = 'PISTOL' },
            { weapon = 'WEAPON_ASSAULTRIFLE', ammo = 300, label = 'Assault Rifle', tag = 'ASALT' },
        },
        armor = 100,
    },
    {
        id = 'advanced', name = 'Pachet Avansat', rank = 3, cost = 0,
        weapons = {
            { weapon = 'WEAPON_HEAVYPISTOL', ammo = 200, label = 'Heavy Pistol', tag = 'PISTOL' },
            { weapon = 'WEAPON_ADVANCEDRIFLE', ammo = 400, label = 'Advanced Rifle', tag = 'ASALT' },
        },
        armor = 100,
    },
    {
        id = 'sniper', name = 'Pachet Sniper', rank = 1, cost = 5000,
        weapons = {
            { weapon = 'WEAPON_PISTOL', ammo = 100, label = 'Pistol', tag = 'PISTOL' },
            { weapon = 'WEAPON_HEAVYSNIPER', ammo = 50, label = 'Heavy Sniper', tag = 'SNIPER' },
        },
        armor = 100,
    },
}

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

SunsetTurfs.TurfBlipAlpha = 80
SunsetTurfs.TurfBlipAlphaWar = 120
SunsetTurfs.FreeTurfBlipColour = 27
