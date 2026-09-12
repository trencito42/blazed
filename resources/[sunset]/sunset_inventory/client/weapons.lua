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
    if inWeaponTest() then return true end
    if isFirearmItem(itemName) and not hasWeaponLicense() then
        return false
    end
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
            GiveWeaponToPed(ped, hash, preservedAmmo[hash] or 0, false, false)
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

RegisterNetEvent('sunset:client:addWeaponAmmo', function(weaponNames, rounds)
    if type(weaponNames) ~= 'table' then return end
    local ped = PlayerPedId()
    local amount = math.max(1, math.min(250, math.floor(tonumber(rounds) or 0)))
    for _, weaponName in ipairs(weaponNames) do
        local hash = joaat(tostring(weaponName))
        if HasPedGotWeapon(ped, hash, false) then
            AddAmmoToPed(ped, hash, amount)
            return
        end
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

CreateThread(function()
    while true do
        if not inWeaponTest() and not hasWeaponLicense() then
            local ped = PlayerPedId()
            for _, def in pairs(Sunset.Items or {}) do
                if def.weapon and isFirearmWeapon(def.weapon) then
                    local hash = joaat(def.weapon)
                    if HasPedGotWeapon(ped, hash, false) then
                        RemoveWeaponFromPed(ped, hash)
                    end
                end
            end
            local testHash = joaat('WEAPON_PISTOL')
            if HasPedGotWeapon(ped, testHash, false) then
                RemoveWeaponFromPed(ped, testHash)
            end
            local selected = GetSelectedPedWeapon(ped)
            if selected ~= UNARMED and not EXEMPT_WEAPON_HASHES[selected] then
                RemoveWeaponFromPed(ped, selected)
            end
            SetCurrentPedWeapon(ped, UNARMED, true)
        end
        Wait(1500)
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
