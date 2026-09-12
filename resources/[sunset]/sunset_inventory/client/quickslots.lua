-- Weapon ammo HUD and X emote wheel. The numbered quick bar was removed:
-- GTA's weapon wheel is the single selector and items are used in inventory.
local AMMO_HUD_HOLD_MS = 4000
local UNARMED = `WEAPON_UNARMED`
local ammoHudUntil = 0
local emoteWheelOpen, xWheelHeld = false, false
local wheelSteerX, wheelSteerY = 0.0, 0.0
local wheelEmoteCount, lastWheelEmoteIndex = 0, -1
local WHEEL_STEER_MIN = 0.18

local function blocked()
    return IsPauseMenuActive() or (IsNuiFocused() and not emoteWheelOpen)
end

local function weaponAmmo(ped, hash)
    if not hash or hash == 0 or hash == UNARMED or not HasPedGotWeapon(ped, hash, false) then return nil end
    local _, clip = GetAmmoInClip(ped, hash)
    return { clip = math.max(0, tonumber(clip) or 0), total = math.max(0, tonumber(GetAmmoInPedWeapon(ped, hash)) or 0) }
end

local function isFiring(ped)
    return IsPedShooting(ped) or IsControlPressed(0, 24) or IsDisabledControlPressed(0, 24)
        or IsControlPressed(0, 257) or IsDisabledControlPressed(0, 257)
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

local function wheelIndex(count)
    if (tonumber(count) or 0) < 1 then return -1 end
    local magnitude = math.sqrt(wheelSteerX * wheelSteerX + wheelSteerY * wheelSteerY)
    if magnitude < WHEEL_STEER_MIN then return -1 end
    local angle = math.atan(wheelSteerX, -wheelSteerY)
    if angle < 0 then angle = angle + (2 * math.pi) end
    local slice = (2 * math.pi) / count
    local index = math.floor((angle + slice / 2) / slice)
    return index >= count and 0 or index
end

local function pushWheelSelection()
    local index = wheelIndex(wheelEmoteCount)
    if index == lastWheelEmoteIndex then return end
    lastWheelEmoteIndex = index
    exports.sunset_ui:Send('emoteWheelSelect', { index = index })
end

local function openEmoteWheel()
    if emoteWheelOpen or blocked() then return end
    local emotes = GetResourceState('sunset_emotes') == 'started' and exports.sunset_emotes:GetEmoteWheelList() or {}
    emoteWheelOpen = true
    wheelSteerX, wheelSteerY = 0.0, 0.0
    wheelEmoteCount = type(emotes) == 'table' and #emotes or 0
    lastWheelEmoteIndex = -1
    clearHandsUpAnim(PlayerPedId())
    exports.sunset_ui:Send('emoteWheelShow', { emotes = emotes })
    pushWheelSelection()
end

local function closeEmoteWheel(selection)
    if not emoteWheelOpen then return end
    emoteWheelOpen, xWheelHeld = false, false
    wheelSteerX, wheelSteerY = 0.0, 0.0
    wheelEmoteCount, lastWheelEmoteIndex = 0, -1
    exports.sunset_ui:Send('emoteWheelHide', {})
    if selection and selection ~= '' and GetResourceState('sunset_emotes') == 'started' then
        exports.sunset_emotes:PlayEmote(selection)
    end
end

local function setWheelHeld(held)
    if held then
        if xWheelHeld then return end
        xWheelHeld = true
        blockDefaultXControls()
        clearHandsUpAnim(PlayerPedId())
        openEmoteWheel()
    elseif xWheelHeld then
        xWheelHeld = false
        if emoteWheelOpen then exports.sunset_ui:Send('emoteWheelRelease', {}) end
    end
end

RegisterCommand('+sunset_emote_wheel', function() if not blocked() then setWheelHeld(true) end end, false)
RegisterCommand('-sunset_emote_wheel', function() setWheelHeld(false) end, false)
RegisterKeyMapping('+sunset_emote_wheel', 'Hold for emote wheel', 'keyboard', 'X')

CreateThread(function()
    local physicalXDown = false
    while true do
        if IsPauseMenuActive() or (IsNuiFocused() and not emoteWheelOpen) then
            if physicalXDown then physicalXDown = false setWheelHeld(false) end
            Wait(100)
        else
            blockDefaultXControls()
            local pressed = IsDisabledControlPressed(0, 73)
            if pressed and not physicalXDown then physicalXDown = true setWheelHeld(true)
            elseif not pressed and physicalXDown then physicalXDown = false setWheelHeld(false) end
            Wait(0)
        end
    end
end)

CreateThread(function()
    while true do
        if emoteWheelOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            blockDefaultXControls()
            local lookX, lookY = GetDisabledControlNormal(0, 1), GetDisabledControlNormal(0, 2)
            if math.abs(lookX) > 0.02 or math.abs(lookY) > 0.02 then
                wheelSteerX, wheelSteerY = wheelSteerX + lookX * 0.42, wheelSteerY + lookY * 0.42
                local magnitude = math.sqrt(wheelSteerX * wheelSteerX + wheelSteerY * wheelSteerY)
                if magnitude > 1.0 then wheelSteerX, wheelSteerY = wheelSteerX / magnitude, wheelSteerY / magnitude end
                pushWheelSelection()
            end
            Wait(0)
        else Wait(200) end
    end
end)

CreateThread(function()
    local lastClip, lastTotal, lastVisible = -1, -1, false
    while true do
        if blocked() then
            if lastVisible then exports.sunset_ui:Send('weaponAmmoUpdate', { visible = false }) end
            lastClip, lastTotal, lastVisible = -1, -1, false
            Wait(250)
        else
            local ped, selected = PlayerPedId(), GetSelectedPedWeapon(PlayerPedId())
            if selected == UNARMED or selected == 0 then
                if lastVisible then exports.sunset_ui:Send('weaponAmmoUpdate', { visible = false }) end
                lastClip, lastTotal, lastVisible = -1, -1, false
                Wait(200)
            else
                if isFiring(ped) or IsPlayerFreeAiming(PlayerId()) then ammoHudUntil = GetGameTimer() + AMMO_HUD_HOLD_MS end
                local ammo = weaponAmmo(ped, selected)
                local visible = ammo ~= nil and GetGameTimer() < ammoHudUntil
                if ammo and (ammo.clip ~= lastClip or ammo.total ~= lastTotal or visible ~= lastVisible) then
                    lastClip, lastTotal, lastVisible = ammo.clip, ammo.total, visible
                    exports.sunset_ui:Send('weaponAmmoUpdate', { visible = visible, clip = ammo.clip, total = ammo.total })
                end
                Wait(isFiring(ped) and 0 or 35)
            end
        end
    end
end)

AddEventHandler('sunset:nui:emoteWheelClose', function(data)
    data = type(data) == 'table' and data or {}
    closeEmoteWheel(data.emote)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and emoteWheelOpen then closeEmoteWheel() end
end)
