-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield (client/sampler.lua)
--  1 Hz telemetry batch — ONE TriggerServerEvent per tick (spec §10).
--  Client data is ADVISORY only; the server corroborates with its own
--  state (spec §1.5). Keep this file tiny and allocation-light.
--  Also carries the rotating heartbeat nonce (§4.14): server sends a
--  nonce in every tickAck; we echo it back on the next tick.
-- ═══════════════════════════════════════════════════════════════

local lastNonce = 0
local lastZ = nil
local frameTimeSum = 0.0
local frameTimeCount = 0
local tickCount = 0

RegisterNetEvent('sunset:anticheat:tickAck', function(nonce)
    lastNonce = tonumber(nonce) or 0
end)

-- [LEDGER] Enumerate the ped's ACTUAL weapons (not our tracked sync list —
-- injected weapons bypass sunset_inventory entirely, so we must read the ped).
-- Checked against a full GTA5 weapon-name list with HasPedGotWeapon; runs only
-- every 5 s (spec §4.6). Server diffs this against the inventory ledger.
local WEAPON_NAMES = {
    'WEAPON_PISTOL','WEAPON_COMBATPISTOL','WEAPON_APPISTOL','WEAPON_PISTOL50','WEAPON_SNSPISTOL',
    'WEAPON_HEAVYPISTOL','WEAPON_VINTAGEPISTOL','WEAPON_MARKSMANPISTOL','WEAPON_REVOLVER','WEAPON_DOUBLEACTION',
    'WEAPON_MICROSMG','WEAPON_SMG','WEAPON_ASSAULTSMG','WEAPON_COMBATPDW','WEAPON_MACHINEPISTOL','WEAPON_MINISMG',
    'WEAPON_PUMPSHOTGUN','WEAPON_SAWNOFFSHOTGUN','WEAPON_ASSAULTSHOTGUN','WEAPON_BULLPUPSHOTGUN','WEAPON_MUSKET',
    'WEAPON_HEAVYSHOTGUN','WEAPON_DBSHOTGUN','WEAPON_AUTOSHOTGUN','WEAPON_COMBATSHOTGUN',
    'WEAPON_ASSAULTRIFLE','WEAPON_CARBINERIFLE','WEAPON_ADVANCEDRIFLE','WEAPON_SPECIALCARBINE','WEAPON_BULLPUPRIFLE',
    'WEAPON_COMPACTRIFLE','WEAPON_MILITARYRIFLE','WEAPON_HEAVYRIFLE','WEAPON_TACTICALRIFLE',
    'WEAPON_MG','WEAPON_COMBATMG','WEAPON_GUSENBERG','WEAPON_SNIPERRIFLE','WEAPON_HEAVYSNIPER','WEAPON_MARKSMANRIFLE',
    'WEAPON_RPG','WEAPON_GRENADELAUNCHER','WEAPON_MINIGUN','WEAPON_FIREWORK','WEAPON_RAILGUN','WEAPON_HOMINGLAUNCHER',
    'WEAPON_GRENADE','WEAPON_STICKYBOMB','WEAPON_PROXMINE','WEAPON_SMOKEGRENADE','WEAPON_BZGAS','WEAPON_MOLOTOV',
    'WEAPON_PIPEBOMB','WEAPON_FLARE','WEAPON_STUNGUN','WEAPON_TASER',
}
local WEAPON_HASHES = {}
for _, name in ipairs(WEAPON_NAMES) do WEAPON_HASHES[#WEAPON_HASHES + 1] = joaat(name) end

local function collectWeapons()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return nil end
    local list = {}
    for _, hash in ipairs(WEAPON_HASHES) do
        if HasPedGotWeapon(ped, hash, false) then
            local ammo = 0
            local okA, a = pcall(GetAmmoInPedWeapon, ped, hash)
            if okA then ammo = tonumber(a) or 0 end
            list[#list + 1] = { hash = hash, ammo = ammo }
            if #list >= 40 then break end
        end
    end
    return list
end

CreateThread(function()
    while true do
        Wait(1000)
        tickCount = tickCount + 1

        -- FPS estimate via GetFrameTime rolling average (cheap, no hooks).
        local ft = GetFrameTime()
        if ft and ft > 0.0 then
            frameTimeSum = frameTimeSum + ft
            frameTimeCount = frameTimeCount + 1
        end
        local fps = 0
        if frameTimeCount >= 10 then
            local avg = frameTimeSum / frameTimeCount
            if avg > 0.0 then fps = math.floor(1.0 / avg + 0.5) end
            frameTimeSum = 0.0
            frameTimeCount = 0
        end

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local target = (veh ~= 0) and veh or ped
        local speed = GetEntitySpeed(target) or 0.0
        local coords = GetEntityCoords(ped)

        -- Z velocity: delta against previous sample position.
        local zVel = 0.0
        if lastZ then zVel = coords.z - lastZ end
        lastZ = coords.z

        local parachuteState = 0
        local okParachute, state = pcall(GetPedParachuteState, ped)
        if okParachute and type(state) == 'number' then parachuteState = state end

        local nonce = lastNonce
        lastNonce = 0
        local tick = {
            nonce = nonce,
            speed = speed,
            zVel = zVel,
            falling = IsPedFalling(ped),
            inVehicle = IsPedInAnyVehicle(ped, false),
            swimming = IsPedSwimming(ped),
            ragdoll = IsPedRagdoll(ped),
            parachute = parachuteState,
            health = GetEntityHealth(ped),
            armour = GetPedArmour(ped),
            weapon = GetSelectedPedWeapon(ped),
            fps = fps,
        }
        -- [LEDGER] weapon+ammo list every 5th tick (5 s, spec §4.6).
        if tickCount % 5 == 0 then
            local okW, weapons = pcall(collectWeapons)
            if okW and weapons then tick.weapons = weapons end
        end
        TriggerServerEvent('sunset:anticheat:clientTick', tick)
    end
end)
