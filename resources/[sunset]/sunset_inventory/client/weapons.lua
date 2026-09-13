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
    -- Daca jucatorul e on-duty intr-o factiune, are clearance pentru arme
    -- (armele de factiune sunt date/luate de sunset_factions/client/loadout.lua)
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
    -- [LICENSE GATE DISABLED] The firearm-license gate was flaky and is now
    -- disabled by owner decision. Carrying simply mirrors the inventory:
    -- the license is still enforced where it counts — buying (gunshop) and
    -- receiving weapons (inventory AddItem) both check it SERVER-side, so a
    -- weapon can only be in the inventory if it was obtained legally. Gating
    -- the client-side ped sync on an async license round-trip caused weapons
    -- to silently never appear on the weapon wheel until an ammo "use" forced
    -- GiveWeaponToPed.
    return true
end

function SyncInventoryWeapons(items)
    local ped = PlayerPedId()
    local preservedAmmo = {}
    for hash in pairs(syncedWeapons) do
        preservedAmmo[hash] = math.max(0, GetAmmoInPedWeapon(ped, hash))
    end
    clearSyncedWeapons(ped)
    ensureUnarmed(ped)

    for _, row in ipairs(items or {}) do
        local hash = weaponHashForItem(row.item)
        if hash and hash ~= UNARMED and mayCarryWeapon(row.item) then
            -- [AMMO PERSIST] Ammo lives in the weapon row's metadata (server
            -- persisted). Live ped ammo wins while the session is running;
            -- on relog/respawn the metadata restores it. Without this, ammo
            -- bought at the gunshop vanished on every reconnect.
            local metaAmmo = row.metadata and tonumber(row.metadata.ammo) or nil
            local ammo = preservedAmmo[hash] or metaAmmo or 0
            GiveWeaponToPed(ped, hash, ammo, false, false)
            syncedWeapons[hash] = true
        end
    end

    if hotbarEquippedHash and HasPedGotWeapon(ped, hotbarEquippedHash, false) then
        SetCurrentPedWeapon(ped, hotbarEquippedHash, true)
    else
        hotbarEquippedHash = nil
        SetCurrentPedWeapon(ped, UNARMED, true)
    end
end

-- [CARRY EXCEPTIONS] Weapons granted OUTSIDE the inventory (war loadouts,
-- license range tests, faction duty kits) must not be stripped by the
-- consistency loop. Owners register their hashes here and clear them when
-- the granting context ends.
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
        -- [GUNSHOP FIX] If the weapon isn't on the ped yet (fresh purchase race:
        -- inventory sync grants it separately), give it now. This event is only
        -- sent by the server after confirming the player owns the weapon/box.
        if not HasPedGotWeapon(ped, hash, false) then
            GiveWeaponToPed(ped, hash, amount, false, true)
            syncedWeapons[hash] = true
            return
        end
        AddAmmoToPed(ped, hash, amount)
        return
    end
end)

-- [AMMO PERSIST] Periodically report the live ammo of every inventory-synced
-- weapon to the server, which stores it in the weapon row's metadata. On
-- relog/respawn SyncInventoryWeapons restores it. Only sends when something
-- changed since the last report (cheap: one small payload per 10s max).
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
    local ped = PlayerPedId()
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

-- [LICENSE GATE DISABLED] The old loop here stripped all firearms from the ped
-- whenever the CLIENT-side license check said "no license". That check is an
-- async round-trip and could answer false transiently -> weapons vanished from
-- the wheel and shots got removed mid-fight. Carrying is now purely
-- inventory-driven (SyncInventoryWeapons mirrors the inventory onto the ped).
-- Banned/cheat weapons are still caught server-side by sunset_core security
-- (BANNED_WEAPONS scan); faction duty kits and war loadouts are managed by
-- their own resources, so nothing here strips them.

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
