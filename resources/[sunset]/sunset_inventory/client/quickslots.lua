local HOTBAR_SLOTS = 5
local HOTBAR_PEEK_MS = 3500
local activeHotbarSlot = nil
local hotbarSlots = {}
local hotbarPeekUntil = 0
local emoteWheelOpen = false
local xWheelHeld = false

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
    data.driverReservesSlot2 = isDriverInVehicle()
    return data
end

local function weaponAmmoForHash(ped, hash)
    if not hash or hash == 0 or hash == UNARMED then return nil end
    if not HasPedGotWeapon(ped, hash, false) then return nil end
    local _, clip = GetAmmoInClip(ped, hash)
    local total = GetAmmoInPedWeapon(ped, hash)
    return {
        clip = math.max(0, tonumber(clip) or 0),
        total = math.max(0, tonumber(total) or 0),
    }
end

local function enrichSlotsWithAmmo(slots)
    local ped = PlayerPedId()
    for _, slot in pairs(slots or {}) do
        if type(slot) ~= 'table' then goto continue end
        local hash = nil
        if slot.kind == 'duty_weapon' and slot.weapon then
            hash = joaat(slot.weapon)
        elseif slot.kind == 'item' and slot.weapon then
            hash = joaat(slot.weapon)
        elseif slot.item then
            local def = Sunset.Items[slot.item]
            if def and def.weapon then hash = joaat(def.weapon) end
        end
        if hash then
            local ammo = weaponAmmoForHash(ped, hash)
            if ammo then
                slot.ammoClip = ammo.clip
                slot.ammoTotal = ammo.total
                slot.ammo = ammo.clip
            end
        end
        ::continue::
    end
    return slots
end

local function isHotbarHudVisible()
    if blocked() then return false end
    return hotbarPeekUntil > 0 and GetGameTimer() < hotbarPeekUntil
end

local function peekHotbarHud()
    hotbarPeekUntil = GetGameTimer() + HOTBAR_PEEK_MS
end

local function pushHotbarUpdate()
    enrichSlotsWithAmmo(hotbarSlots)
    exports.sunset_ui:Send('hotbarUpdate', {
        slots = hotbarSlots,
        activeSlot = activeHotbarSlot,
        visible = isHotbarHudVisible(),
        driverReservesSlot2 = isDriverInVehicle(),
    })
end

local function refreshHotbarFromServer()
    local data = Sunset.AwaitCallback('sunset:hotbar:get')
    if data and data.slots then
        hotbarSlots = data.slots
        if activeHotbarSlot then
            local slotData = hotbarSlots[tostring(activeHotbarSlot)] or hotbarSlots[activeHotbarSlot]
            if not slotData then
                activeHotbarSlot = nil
                exports.sunset_inventory:HolsterHotbarWeapon()
                exports.sunset_inventory:HolsterHotbarProp()
            end
        end
        pushHotbarUpdate()
    end
end

local function holsterActiveItem()
    activeHotbarSlot = nil
    exports.sunset_inventory:HolsterHotbarWeapon()
    exports.sunset_inventory:HolsterHotbarProp()
    pushHotbarUpdate()
end

local function getSlotData(slot)
    return hotbarSlots[tostring(slot)] or hotbarSlots[slot]
end

local function isUsableHotbarSlot(slotData)
    return type(slotData) == 'table'
        and slotData.kind == 'item'
        and slotData.usable == true
end

local function executeHotbarResult(result, slot)
    if not result or not result.action then return end
    peekHotbarHud()

    if result.action == 'empty' then
        exports.sunset_ui:Notify('Quick slot is empty.', 'info')
        return
    end

    if result.action == 'used_item' then
        if result.slots then hotbarSlots = result.slots end
        local slotData = getSlotData(slot)
        if slotData then
            activeHotbarSlot = slot
        else
            activeHotbarSlot = nil
        end
        pushHotbarUpdate()
        return
    end

    if result.action == 'equip_usable' then
        exports.sunset_inventory:HolsterHotbarWeapon()
        exports.sunset_inventory:HolsterHotbarProp()
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

    if result.action == 'equip_prop' then
        if exports.sunset_inventory:EquipHotbarProp(result.item) then
            activeHotbarSlot = slot
            pushHotbarUpdate()
        else
            exports.sunset_ui:Notify('Could not equip that item.', 'error')
        end
        return
    end

    if result.action == 'play_emote' then
        exports.sunset_inventory:HolsterHotbarProp()
        exports.sunset_inventory:HolsterHotbarWeapon()
        if GetResourceState('sunset_emotes') == 'started' then
            exports.sunset_emotes:PlayEmote(result.name)
        end
        activeHotbarSlot = slot
        pushHotbarUpdate()
    end
end

local function requestHotbarSlot(slot, consume)
    if blocked() then return end
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > HOTBAR_SLOTS then return end
    if slot == 2 and isDriverInVehicle() then return end

    peekHotbarHud()
    pushHotbarUpdate()

    local slotData = getSlotData(slot)

    if consume then
        if activeHotbarSlot ~= slot then
            exports.sunset_ui:Notify('Select the quick slot first, then use it again.', 'info')
            return
        end
        if not isUsableHotbarSlot(slotData) then return end
    elseif activeHotbarSlot == slot then
        if isUsableHotbarSlot(slotData) then
            requestHotbarSlot(slot, true)
            return
        end
        holsterActiveItem()
        if GetResourceState('sunset_emotes') == 'started' then
            exports.sunset_emotes:StopEmote()
        end
        return
    elseif activeHotbarSlot then
        exports.sunset_inventory:HolsterHotbarWeapon()
        exports.sunset_inventory:HolsterHotbarProp()
    end

    CreateThread(function()
        local result, err = Sunset.AwaitCallback('sunset:hotbar:use', {
            slot = slot,
            consume = consume == true,
        })
        if not result then
            if err then exports.sunset_ui:Notify(err, 'error') end
            return
        end
        executeHotbarResult(result, slot)
    end)
end

local function activateHotbarSlot(slot)
    requestHotbarSlot(slot, false)
end

local function blockDefaultXControls()
    DisableControlAction(0, 73, true)
    DisableControlAction(1, 73, true)
    DisableControlAction(2, 73, true)
end

local function clearHandsUpAnim(ped)
    if IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3)
        or IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3) then
        ClearPedSecondaryTask(ped)
    end
end

local function openEmoteWheel()
    if emoteWheelOpen or blocked() then return end
    emoteWheelOpen = true
    clearHandsUpAnim(PlayerPedId())
    exports.sunset_ui:Send('emoteWheelShow', {
        emotes = GetResourceState('sunset_emotes') == 'started' and exports.sunset_emotes:GetEmoteWheelList() or {},
    })
end

local function closeEmoteWheel(playSelection)
    if not emoteWheelOpen then return end
    emoteWheelOpen = false
    exports.sunset_ui:Send('emoteWheelHide', {})
    if playSelection and playSelection ~= '' and GetResourceState('sunset_emotes') == 'started' then
        exports.sunset_emotes:PlayEmote(playSelection)
    end
end

local function setEmoteWheelHeld(held)
    if held then
        if not xWheelHeld then
            xWheelHeld = true
            blockDefaultXControls()
            clearHandsUpAnim(PlayerPedId())
            openEmoteWheel()
        end
        return
    end

    if not xWheelHeld then return end
    xWheelHeld = false
    if emoteWheelOpen then
        exports.sunset_ui:Send('emoteWheelRelease', {})
    end
end

for i = 1, HOTBAR_SLOTS do
    RegisterCommand(('sunset_hotbar_%d'):format(i), function()
        activateHotbarSlot(i)
    end, false)
    RegisterKeyMapping(('sunset_hotbar_%d'):format(i), ('Quick slot %d'):format(i), 'keyboard', tostring(i))
end

RegisterCommand('+sunset_emote_wheel', function()
    if blocked() then return end
    setEmoteWheelHeld(true)
end, false)

RegisterCommand('-sunset_emote_wheel', function()
    setEmoteWheelHeld(false)
end, false)

RegisterKeyMapping('+sunset_emote_wheel', 'Hold for emote wheel', 'keyboard', 'X')

-- Physical X fallback (control 73) — same hold-to-show pattern as Z player list.
CreateThread(function()
    local physicalXDown = false
    while true do
        if IsPauseMenuActive() or (IsNuiFocused() and not emoteWheelOpen) then
            if physicalXDown then
                physicalXDown = false
                setEmoteWheelHeld(false)
            end
            Wait(100)
        else
            blockDefaultXControls()
            local pressed = IsDisabledControlPressed(0, 73)
            if pressed and not physicalXDown then
                physicalXDown = true
                if not blocked() then setEmoteWheelHeld(true) end
            elseif not pressed and physicalXDown then
                physicalXDown = false
                setEmoteWheelHeld(false)
            end
            Wait(0)
        end
    end
end)

CreateThread(function()
    while true do
        if not IsPauseMenuActive() then
            for control = 157, 164 do
                DisableControlAction(0, control, true)
            end
            DisableControlAction(0, 37, true)
            blockDefaultXControls()
        end
        Wait(0)
    end
end)

AddEventHandler('sunset:nui:hotbarUse', function(data)
    data = type(data) == 'table' and data or {}
    local slot = tonumber(data.slot)
    if not slot then return end
    requestHotbarSlot(slot, data.consume == true)
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

CreateThread(function()
    local lastDriver = false
    while true do
        local driver = isDriverInVehicle()
        if driver ~= lastDriver then
            lastDriver = driver
            pushHotbarUpdate()
        end
        Wait((driver or lastDriver) and 250 or 600)
    end
end)

CreateThread(function()
    while true do
        if hotbarPeekUntil > 0 and GetGameTimer() >= hotbarPeekUntil then
            hotbarPeekUntil = 0
            pushHotbarUpdate()
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)
            if weapon ~= UNARMED and weapon ~= 0 then
                local ammo = weaponAmmoForHash(ped, weapon)
                if ammo then
                    exports.sunset_ui:Send('weaponAmmoUpdate', {
                        visible = IsPedShooting(ped),
                        clip = ammo.clip,
                        total = ammo.total,
                    })
                end
            end
        end
        Wait(150)
    end
end)

CreateThread(function()
    local lastClip, lastTotal = -1, -1
    local lastAmmoVisible = false
    while true do
        if blocked() then
            if lastClip ~= -1 or lastAmmoVisible then
                exports.sunset_ui:Send('weaponAmmoUpdate', { visible = false })
                lastClip, lastTotal = -1, -1
                lastAmmoVisible = false
            end
            Wait(250)
        else
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)
            if weapon == UNARMED or weapon == 0 then
                if lastClip ~= -1 or lastAmmoVisible then
                    exports.sunset_ui:Send('weaponAmmoUpdate', { visible = false })
                    lastClip, lastTotal = -1, -1
                    lastAmmoVisible = false
                end
                Wait(200)
            else
                local ammo = weaponAmmoForHash(ped, weapon)
                if ammo then
                    local showAmmo = isHotbarHudVisible() or IsPedShooting(ped)
                    if ammo.clip ~= lastClip or ammo.total ~= lastTotal or showAmmo ~= lastAmmoVisible then
                        lastClip, lastTotal = ammo.clip, ammo.total
                        lastAmmoVisible = showAmmo
                        exports.sunset_ui:Send('weaponAmmoUpdate', {
                            visible = showAmmo,
                            clip = ammo.clip,
                            total = ammo.total,
                        })
                        if isHotbarHudVisible() then
                            enrichSlotsWithAmmo(hotbarSlots)
                            exports.sunset_ui:Send('hotbarUpdate', {
                                slots = hotbarSlots,
                                activeSlot = activeHotbarSlot,
                                visible = true,
                                driverReservesSlot2 = isDriverInVehicle(),
                            })
                        end
                    end
                end
                Wait(IsPedShooting(ped) and 0 or 35)
            end
        end
    end
end)

exports('GetHotbarSlots', function() return hotbarSlots end)
exports('EnrichInventoryPayload', enrichInventoryPayload)
exports('RefreshHotbar', refreshHotbarFromServer)
