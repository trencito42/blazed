local UNARMED = `WEAPON_UNARMED`
local syncedWeapons = {}
local hotbarEquippedHash = nil

local MELEE_WEAPONS = {
    WEAPON_UNARMED = true,
    WEAPON_KNIFE = true,
    WEAPON_SWITCHBLADE = true,
    WEAPON_BAT = true,
    WEAPON_CROWBAR = true,
    WEAPON_FLASHLIGHT = true,
    WEAPON_NIGHTSTICK = true,
    WEAPON_HAMMER = true,
    WEAPON_GOLFCLUB = true,
    WEAPON_BOTTLE = true,
    WEAPON_DAGGER = true,
    WEAPON_HATCHET = true,
    WEAPON_KNUCKLE = true,
    WEAPON_MACHETE = true,
    WEAPON_WRENCH = true,
    WEAPON_POOLCUE = true,
    WEAPON_BATTLEAXE = true,
    WEAPON_STONE_HATCHET = true,
    WEAPON_FIREEXTINGUISHER = true,
    WEAPON_PETROLCAN = true,
    WEAPON_HAZARDCAN = true,
    WEAPON_FERTILIZERCAN = true,
    WEAPON_BALL = true,
    WEAPON_SNOWBALL = true,
    GADGET_PARACHUTE = true,
}

local EXEMPT_WEAPON_HASHES = {}
for name in pairs(MELEE_WEAPONS) do EXEMPT_WEAPON_HASHES[joaat(name)] = true end

local function inWeaponTest()
    if GetResourceState('sunset_licenses') ~= 'started' then return false end
    local ok, active = pcall(function()
        return exports.sunset_licenses:IsInLicenseTest('weapon')
    end)
    return ok and active == true
end

local function hasWeaponLicense()
    if GetResourceState('sunset_factions') == 'started' then
        local ok, onDuty = pcall(function() return exports.sunset_factions:IsOnDuty() end)
        if ok and onDuty == true then
            return true
        end
    end
    if GetResourceState('sunset_licenses') ~= 'started' then return true end
    local ok, licensed = pcall(function()
        return exports.sunset_licenses:HasLicense('weapon')
    end)
    return ok and licensed == true
end

local function isFirearmWeapon(weaponName)
    if not weaponName or weaponName == '' then return false end
    weaponName = string.upper(weaponName)
    if MELEE_WEAPONS[weaponName] then return false end
    return weaponName:sub(1, 7) == 'WEAPON_'
end

local function weaponHashForItem(itemName)
    local def = Sunset.Items[itemName]
    return def and def.weapon and joaat(def.weapon) or nil
end

local function isFirearmItem(itemName)
    local def = Sunset.Items[itemName]
    return def and def.weapon and isFirearmWeapon(def.weapon)
end

local function clearSyncedWeapons(ped)
    for hash, _ in pairs(syncedWeapons) do
        if HasPedGotWeapon(ped, hash, false) then
            RemoveWeaponFromPed(ped, hash)
        end
    end
    syncedWeapons = {}
end

local function ensureUnarmed(ped)
    if not HasPedGotWeapon(ped, UNARMED, false) then
        GiveWeaponToPed(ped, UNARMED, 0, false, false)
    end
end

local function mayCarryWeapon(itemName)
    return true
end

-- ═══════════════════════════════════════════════════════════════
--  [AMMO FIX] Explicit ownership semantics for weapon/ammo sync.
--
--  FRESH SPAWN (relog, respawn, character switch, resource restart):
--    → persisted metadata ammo is AUTHORITATIVE
--    → live ped ammo is 0 (fresh ped) and must NOT override metadata
--
--  LIVE RESYNC (inventory update while same ped is alive):
--    → live ped ammo may be NEWER (shots fired since last DB flush)
--    → live ammo is authoritative IF the weapon was already on the ped
--
--  The old code used `preservedAmmo[hash] or metaAmmo or 0` which is
--  BROKEN because Lua 0 is truthy: a fresh ped reports 0, which
--  overrides the persisted 84 rounds.
-- ═══════════════════════════════════════════════════════════════

-- Tracks whether this is a fresh ped (no weapons were on it before sync)
local isFreshPed = true

function SyncInventoryWeapons(items)
    local ped = PlayerPedId()

    -- [DIFFERENTIAL SYNC] Build the set of weapon hashes we SHOULD have
    local desiredWeapons = {}
    for _, row in ipairs(items or {}) do
        local hash = weaponHashForItem(row.item)
        if hash and hash ~= UNARMED and mayCarryWeapon(row.item) then
            desiredWeapons[hash] = row
        end
    end

    -- [DIFFERENTIAL SYNC] Remove weapons no longer owned
    for hash, _ in pairs(syncedWeapons) do
        if not desiredWeapons[hash] then
            if HasPedGotWeapon(ped, hash, false) then
                RemoveWeaponFromPed(ped, hash)
            end
            syncedWeapons[hash] = nil
        end
    end

    -- [DIFFERENTIAL SYNC] Add/update weapons
    for hash, row in pairs(desiredWeapons) do
        local alreadyOnPed = syncedWeapons[hash] == true and HasPedGotWeapon(ped, hash, false)

        if alreadyOnPed then
            -- LIVE RESYNC: weapon was already on this ped. Live ammo is newer
            -- (shots may have been fired since last DB flush). Do NOT re-give,
            -- do NOT reset ammo. Leave it alone.
            -- (The periodic saveWeaponAmmo loop handles persistence.)
        else
            -- FRESH GIVE: weapon was NOT on this ped (fresh spawn, or newly
            -- acquired). Use persisted metadata ammo as authoritative.
            local metaAmmo = 0
            if row.metadata and type(row.metadata) == 'table' then
                metaAmmo = math.max(0, math.floor(tonumber(row.metadata.ammo) or 0))
            end
            GiveWeaponToPed(ped, hash, metaAmmo, false, false)
            syncedWeapons[hash] = true
        end
    end

    ensureUnarmed(ped)

    if hotbarEquippedHash and HasPedGotWeapon(ped, hotbarEquippedHash, false) then
        SetCurrentPedWeapon(ped, hotbarEquippedHash, true)
    else
        hotbarEquippedHash = nil
        SetCurrentPedWeapon(ped, UNARMED, true)
    end

    isFreshPed = false
end

-- [CARRY EXCEPTIONS] Weapons granted OUTSIDE the inventory (war loadouts,
-- license range tests, faction duty kits) must not be stripped by the
-- consistency loop.
local carryExceptions = {}

function AddCarryException(hash, remove)
    hash = tonumber(hash) or (type(hash) == 'string' and joaat(hash) or nil)
    if not hash then return end
    carryExceptions[hash] = not remove and true or nil
end
exports('AddCarryException', AddCarryException)
exports('ClearCarryExceptions', function()
    carryExceptions = {}
end)

local function warWeaponException(hash)
    if inWeaponTest() then return true end
    return carryExceptions[hash] == true
end

RegisterNetEvent('sunset:client:addWeaponAmmo', function(weaponNames, rounds)
    if type(weaponNames) ~= 'table' then return end
    local ped = PlayerPedId()
    local amount = math.max(1, math.min(250, math.floor(tonumber(rounds) or 0)))
    for _, weaponName in ipairs(weaponNames) do
        local hash = joaat(tostring(weaponName))
        if not HasPedGotWeapon(ped, hash, false) then
            GiveWeaponToPed(ped, hash, amount, false, true)
            syncedWeapons[hash] = true
            return
        end
        AddAmmoToPed(ped, hash, amount)
        return
    end
end)

-- [AMMO FIX] Server-authoritative ammo set. Unlike addWeaponAmmo (which adds),
-- this SETS the exact value the server computed. Used after ammo box use so
-- the client ped matches the persisted metadata immediately.
RegisterNetEvent('sunset:client:setWeaponAmmo', function(weaponNames, ammo)
    if type(weaponNames) ~= 'table' then return end
    local ped = PlayerPedId()
    local amount = math.max(0, math.min(3000, math.floor(tonumber(ammo) or 0)))
    for _, weaponName in ipairs(weaponNames) do
        local hash = joaat(tostring(weaponName))
        if HasPedGotWeapon(ped, hash, false) then
            -- Set exact ammo: remove all then give the exact amount
            RemoveWeaponFromPed(ped, hash)
            GiveWeaponToPed(ped, hash, amount, false, true)
            syncedWeapons[hash] = true
            return
        end
    end
end)

-- [AMMO PERSIST] Periodically report the live ammo of every inventory-synced
-- weapon to the server. The server CLAMPS the value (client can only report
-- decreases from shooting, never increases).
local lastReportedAmmo = {}
CreateThread(function()
    Wait(20000)
    while true do
        local ped = PlayerPedId()
        local payload = {}
        local dirty = false
        for itemName, def in pairs(Sunset.Items or {}) do
            if def.weapon then
                local hash = joaat(def.weapon)
                if syncedWeapons[hash] and HasPedGotWeapon(ped, hash, false) then
                    local ammo = math.max(0, GetAmmoInPedWeapon(ped, hash))
                    if lastReportedAmmo[itemName] ~= ammo then
                        payload[#payload + 1] = { item = itemName, ammo = ammo }
                        lastReportedAmmo[itemName] = ammo
                        dirty = true
                    end
                end
            end
        end
        if dirty and #payload > 0 then
            TriggerServerEvent('sunset:server:saveWeaponAmmo', payload)
        end
        Wait(10000)
    end
end)

local function equipHotbarWeapon(hash)
    if not hash or hash == UNARMED then return false end
    local ped = PlayerPedId()
    if not HasPedGotWeapon(ped, hash, false) then return false end
    exports.sunset_inventory:HolsterHotbarProp()
    SetCurrentPedWeapon(ped, hash, true)
    hotbarEquippedHash = hash
    return true
end

local function holsterHotbarWeapon()
    hotbarEquippedHash = nil
    SetCurrentPedWeapon(ped, UNARMED, true)
    return true
end

exports('EquipHotbarWeapon', equipHotbarWeapon)
exports('HolsterHotbarWeapon', holsterHotbarWeapon)
exports('GetHotbarEquippedHash', function() return hotbarEquippedHash end)

RegisterNetEvent('sunset:client:inventoryUpdate', function(items)
    SyncInventoryWeapons(items)
end)

AddEventHandler('sunset:client:playerSpawned', function()
    -- [FRESH SPAWN] Mark as fresh so SyncInventoryWeapons uses metadata ammo
    isFreshPed = true
    syncedWeapons = {}
    CreateThread(function()
        Wait(1500)
        local data = Sunset.AwaitCallback('sunset:getInventory')
        if data and data.items then
            SyncInventoryWeapons(data.items)
        else
            ensureUnarmed(PlayerPedId())
        end
    end)
end)

RegisterNetEvent('sunset:client:dutyState', function(state)
    local data = Sunset.AwaitCallback('sunset:getInventory')
    if data and data.items then
        SyncInventoryWeapons(data.items)
    else
        ensureUnarmed(PlayerPedId())
    end
end)

RegisterNetEvent('sunset:licenses:refresh', function()
    local data = Sunset.AwaitCallback('sunset:getInventory')
    if data and data.items then
        SyncInventoryWeapons(data.items)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        ensureUnarmed(ped)
        SetPedCanSwitchWeapon(ped, true)
        if hotbarEquippedHash and not HasPedGotWeapon(ped, hotbarEquippedHash, false) then
            hotbarEquippedHash = nil
            SetCurrentPedWeapon(ped, UNARMED, true)
        end
        Wait(5000)
    end
end)
