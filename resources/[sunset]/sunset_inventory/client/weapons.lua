local UNARMED = `WEAPON_UNARMED`
local syncedWeapons = {}

local function isOnDuty()
    if GetResourceState('sunset_factions') ~= 'started' then return false end
    local ok, onDuty = pcall(function()
        return exports.sunset_factions:IsOnDuty()
    end)
    return ok and onDuty == true
end

local function weaponHashForItem(itemName)
    local def = Sunset.Items[itemName]
    return def and def.weapon and joaat(def.weapon) or nil
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

function SyncInventoryWeapons(items)
    if isOnDuty() then return end

    local ped = PlayerPedId()
    clearSyncedWeapons(ped)
    ensureUnarmed(ped)

    for _, row in ipairs(items or {}) do
        local hash = weaponHashForItem(row.item)
        if hash and hash ~= UNARMED then
            GiveWeaponToPed(ped, hash, 0, false, false)
            syncedWeapons[hash] = true
        end
    end

    SetCurrentPedWeapon(ped, UNARMED, true)
end

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
    if state then
        clearSyncedWeapons(PlayerPedId())
        return
    end
    local data = Sunset.AwaitCallback('sunset:getInventory')
    if data and data.items then
        SyncInventoryWeapons(data.items)
    else
        ensureUnarmed(PlayerPedId())
    end
end)

CreateThread(function()
    while true do
        if not isOnDuty() then
            local ped = PlayerPedId()
            ensureUnarmed(ped)
            SetPedCanSwitchWeapon(ped, true)
        end
        Wait(5000)
    end
end)
