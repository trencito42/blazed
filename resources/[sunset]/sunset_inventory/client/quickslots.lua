local HOTBAR_SLOTS = 5
local activeHotbarSlot = nil
local hotbarSlots = {}
local emoteWheelOpen = false
local xHoldToken = 0
local X_HOLD_MS = 320

local UNARMED = `WEAPON_UNARMED`

local function blocked()
    if IsPauseMenuActive() then return true end
    if IsNuiFocused() and not emoteWheelOpen then return true end
    return false
end

local function isDriverInVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return false end
    return GetPedInVehicleSeat(veh, -1) == ped
end

local function getDutyWeaponsForUi()
    if GetResourceState('sunset_factions') ~= 'started' then return {} end
    local ok, list = pcall(function()
        return exports.sunset_factions:GetDutyWeaponsForUi()
    end)
    return ok and list or {}
end

local function enrichInventoryPayload(data)
    data = data or {}
    data.dutyWeapons = getDutyWeaponsForUi()
    data.quickslots = hotbarSlots
    data.activeHotbarSlot = activeHotbarSlot
    return data
end

local function enrichSlotsWithAmmo(slots)
    local ped = PlayerPedId()
    for _, slot in pairs(slots or {}) do
        if type(slot) == 'table' and slot.kind == 'duty_weapon' and slot.weapon then
            local hash = joaat(slot.weapon)
            if HasPedGotWeapon(ped, hash, false) then
                slot.ammo = GetAmmoInPedWeapon(ped, hash)
            end
        end
    end
    return slots
end

local function pushHotbarUpdate()
    enrichSlotsWithAmmo(hotbarSlots)
    exports.sunset_ui:Send('hotbarUpdate', {
        slots = hotbarSlots,
        activeSlot = activeHotbarSlot,
        visible = not blocked(),
    })
end

local function refreshHotbarFromServer()
    local data = Sunset.AwaitCallback('sunset:hotbar:get')
    if data and data.slots then
        hotbarSlots = data.slots
        pushHotbarUpdate()
    end
end

local function holsterActiveWeapon()
    activeHotbarSlot = nil
    exports.sunset_inventory:HolsterHotbarWeapon()
    pushHotbarUpdate()
end

local function executeHotbarResult(result, slot)
    if not result or not result.action then return end

    if result.action == 'empty' then
        exports.sunset_ui:Notify('Quick slot is empty.', 'info')
        return
    end

    if result.action == 'used_item' then
        if result.slots then hotbarSlots = result.slots end
        activeHotbarSlot = slot
        pushHotbarUpdate()
        return
    end

    if result.action == 'equip_weapon' then
        local hash = joaat(result.weapon)
        if exports.sunset_inventory:EquipHotbarWeapon(hash) then
            activeHotbarSlot = slot
            pushHotbarUpdate()
        end
        return
    end

    if result.action == 'equip_duty_weapon' then
        local hash = joaat(result.weapon)
        if exports.sunset_inventory:EquipHotbarWeapon(hash) then
            activeHotbarSlot = slot
            pushHotbarUpdate()
        else
            exports.sunset_ui:Notify('You do not have that duty weapon equipped.', 'error')
        end
        return
    end

    if result.action == 'play_emote' then
        if GetResourceState('sunset_emotes') == 'started' then
            exports.sunset_emotes:PlayEmote(result.name)
        end
        activeHotbarSlot = slot
        pushHotbarUpdate()
    end
end

local function activateHotbarSlot(slot)
    if blocked() then return end
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > HOTBAR_SLOTS then return end

    if slot == 2 and isDriverInVehicle() then return end

    if activeHotbarSlot == slot then
        holsterActiveWeapon()
        if GetResourceState('sunset_emotes') == 'started' then
            exports.sunset_emotes:StopEmote()
        end
        return
    end

    CreateThread(function()
        local result, err = Sunset.AwaitCallback('sunset:hotbar:use', { slot = slot })
        if not result then
            if err then exports.sunset_ui:Notify(err, 'error') end
            return
        end
        executeHotbarResult(result, slot)
    end)
end

local function openEmoteWheel()
    if emoteWheelOpen or blocked() then return end
    emoteWheelOpen = true
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('emoteWheelShow', {
        emotes = GetResourceState('sunset_emotes') == 'started' and exports.sunset_emotes:GetEmoteWheelList() or {},
    })
end

local function closeEmoteWheel(playSelection)
    if not emoteWheelOpen then return end
    emoteWheelOpen = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('emoteWheelHide', {})
    if playSelection and playSelection ~= '' and GetResourceState('sunset_emotes') == 'started' then
        exports.sunset_emotes:PlayEmote(playSelection)
    end
end

for i = 1, HOTBAR_SLOTS do
    RegisterCommand(('sunset_hotbar_%d'):format(i), function()
        activateHotbarSlot(i)
    end, false)
    RegisterKeyMapping(('sunset_hotbar_%d'):format(i), ('Quick slot %d'):format(i), 'keyboard', tostring(i))
end

RegisterCommand('+sunset_emote_wheel', function()
    if blocked() or emoteWheelOpen then return end
    local token = xHoldToken + 1
    xHoldToken = token
    CreateThread(function()
        Wait(X_HOLD_MS)
        if xHoldToken ~= token then return end
        if blocked() or emoteWheelOpen then return end
        openEmoteWheel()
    end)
end, false)

RegisterCommand('-sunset_emote_wheel', function()
    xHoldToken = xHoldToken + 1
    if emoteWheelOpen then
        exports.sunset_ui:Send('emoteWheelRelease', {})
    end
end, false)

RegisterKeyMapping('+sunset_emote_wheel', 'Hold for emote wheel', 'keyboard', 'X')

CreateThread(function()
    while true do
        if not IsPauseMenuActive() then
            for control = 157, 164 do
                DisableControlAction(0, control, true)
            end
            DisableControlAction(0, 37, true)
            if not emoteWheelOpen then
                DisableControlAction(0, 73, true)
            end
        end
        Wait(0)
    end
end)

AddEventHandler('sunset:nui:hotbarAssign', function(data)
    CreateThread(function()
        local result, err = Sunset.AwaitCallback('sunset:hotbar:assign', data or {})
        if result and result.slots then
            hotbarSlots = result.slots
            pushHotbarUpdate()
            if data and data.fromInventory then
                local inv = Sunset.AwaitCallback('sunset:getInventory')
                if inv then
                    exports.sunset_ui:Send('inventoryUpdate', enrichInventoryPayload(inv))
                end
            end
        elseif err then
            exports.sunset_ui:Notify(err, 'error')
        end
    end)
end)

AddEventHandler('sunset:nui:emoteWheelClose', function(data)
    data = type(data) == 'table' and data or {}
    closeEmoteWheel(data.emote)
end)

AddEventHandler('sunset:client:playerSpawned', function()
    CreateThread(function()
        Wait(2000)
        refreshHotbarFromServer()
    end)
end)

RegisterNetEvent('sunset:client:updateCharacter', function()
    pushHotbarUpdate()
end)

RegisterNetEvent('sunset:client:inventoryUpdate', function()
    if activeHotbarSlot then
        CreateThread(function()
            Wait(100)
            refreshHotbarFromServer()
        end)
    end
end)

RegisterNetEvent('sunset:client:dutyState', function()
    CreateThread(function()
        Wait(300)
        refreshHotbarFromServer()
    end)
end)

CreateThread(function()
    Wait(4000)
    refreshHotbarFromServer()
end)

exports('GetHotbarSlots', function() return hotbarSlots end)
exports('EnrichInventoryPayload', enrichInventoryPayload)
exports('RefreshHotbar', refreshHotbarFromServer)
