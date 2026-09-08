local phoneOpen = false
local phoneOpening = false
local phoneProp = nil
local lastToggleAt = 0
local PHONE_MODEL = `prop_amb_phone`
local TOGGLE_COOLDOWN_MS = 450

local function isChatOpen()
    if GetResourceState('sunset_chat') ~= 'started' then return false end
    local ok, open = pcall(function()
        return exports.sunset_chat:IsChatOpen()
    end)
    return ok and open == true
end

local function playPhoneSound(name)
    if name == 'open' then
        PlaySoundFrontend(-1, 'Pin_Good', 'Phone_SoundSet_Michael', true)
    else
        PlaySoundFrontend(-1, 'Put_Away', 'Phone_SoundSet_Michael', true)
    end
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function attachPhoneProp(ped)
    if phoneProp and DoesEntityExist(phoneProp) then return end

    RequestModel(PHONE_MODEL)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(PHONE_MODEL) do
        if GetGameTimer() > timeout then return end
        Wait(10)
    end

    local coords = GetEntityCoords(ped)
    phoneProp = CreateObject(PHONE_MODEL, coords.x, coords.y, coords.z + 0.2, true, true, false)
    SetEntityCollision(phoneProp, false, false)
    local bone = GetPedBoneIndex(ped, 28422)
    AttachEntityToEntity(phoneProp, ped, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
    SetModelAsNoLongerNeeded(PHONE_MODEL)
end

local function removePhoneProp()
    if phoneProp and DoesEntityExist(phoneProp) then
        DeleteEntity(phoneProp)
    end
    phoneProp = nil
end

local function playPhoneAnim(open)
    local ped = PlayerPedId()
    local dict = 'cellphone@'

    if open then
        if not loadAnimDict(dict) then return end
        TaskPlayAnim(ped, dict, 'cellphone_text_in', 3.0, -1, -1, 50, 0, false, false, false)
        Wait(400)
        if not phoneOpen then return end
        attachPhoneProp(ped)
        TaskPlayAnim(ped, dict, 'cellphone_text_read_base', 3.0, 3.0, -1, 49, 0, false, false, false)
    else
        if loadAnimDict(dict) then
            TaskPlayAnim(ped, dict, 'cellphone_text_out', 3.0, -1, -1, 50, 0, false, false, false)
            Wait(300)
        end
        removePhoneProp()
        StopAnimTask(ped, dict, 'cellphone_text_read_base', 1.0)
        StopAnimTask(ped, dict, 'cellphone_text_in', 1.0)
        StopAnimTask(ped, dict, 'cellphone_text_out', 1.0)
    end
end

local function openPhone()
    if phoneOpen or phoneOpening then return end
    if IsNuiFocused() or isChatOpen() then
        return exports.sunset_ui:Notify('Close the current menu or chat before opening the phone.', 'info', 3500)
    end
    phoneOpening = true

    CreateThread(function()
        local data, err = Sunset.AwaitCallback('sunset:getPhoneData')
        if not data then
            phoneOpening = false
            exports.sunset_ui:Notify(err or 'Could not load phone data', 'error')
            return
        end

        -- Another UI may have opened while phone data was loading. Never steal
        -- its focus after the asynchronous callback completes.
        if IsNuiFocused() or isChatOpen() then
            phoneOpening = false
            return
        end

        phoneOpen = true
        phoneOpening = false
        DisablePlayerFiring(PlayerId(), true)
        playPhoneSound('open')
        playPhoneAnim(true)
        exports.sunset_ui:Send('phoneShow', data)
        exports.sunset_ui:SetFocus(true, true, false)
    end)
end

local function closePhone()
    local shouldAnimate = phoneOpen or (phoneProp and DoesEntityExist(phoneProp))
    phoneOpen = false
    phoneOpening = false
    if shouldAnimate then
        playPhoneSound('close')
        CreateThread(function()
            playPhoneAnim(false)
        end)
    else
        removePhoneProp()
    end
    exports.sunset_ui:SetFocus(false, false, false)
    exports.sunset_ui:Send('phoneHide', {})
end

local function togglePhone()
    local now = GetGameTimer()
    if now - lastToggleAt < TOGGLE_COOLDOWN_MS then return end
    lastToggleAt = now

    if phoneOpen then
        closePhone()
    else
        openPhone()
    end
end

RegisterCommand('phone', togglePhone, false)

CreateThread(function()
    while true do
        if phoneOpen and IsPauseMenuActive() then
            closePhone()
        end
        Wait(phoneOpen and 50 or 250)
    end
end)

-- P closes its own phone while focused, but never opens over chat or another NUI.
-- Without this guard, typing the letter P in chat is seen as pause-control 199
-- and the phone steals the chat cursor/focus.
CreateThread(function()
    while true do
        DisableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE (P)
        if IsDisabledControlJustReleased(0, 199) and not IsPauseMenuActive() then
            if phoneOpen or (not IsNuiFocused() and not isChatOpen()) then
                togglePhone()
            end
        end
        Wait(0)
    end
end)

AddEventHandler('sunset:nui:phoneClose', function()
    closePhone()
end)

AddEventHandler('sunset:nui:phoneSend', function(data)
    CreateThread(function()
        data = data or {}
        local location = nil
        if tonumber(data.targetCharacterId) == -112 or tostring(data.phone) == '112' then
            local coords = GetEntityCoords(PlayerPedId())
            local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local street = GetStreetNameFromHashKey(streetHash)
            if crossingHash and crossingHash ~= 0 then
                local crossing = GetStreetNameFromHashKey(crossingHash)
                if crossing and crossing ~= '' then street = street .. ' / ' .. crossing end
            end
            local zone = GetNameOfZone(coords.x, coords.y, coords.z)
            local area = GetLabelText(zone)
            if not area or area == '' or area == 'NULL' then area = zone end
            location = { street = street, area = area }
        end

        local callOk, sent, sendErr = pcall(function()
            return Sunset.AwaitCallback('sunset:phoneSend', tonumber(data.targetCharacterId), data.message, data.phone, location)
        end)
        if not callOk then
            exports.sunset_ui:Notify(tostring(sent) or 'Could not send the message', 'error')
            return
        end
        if not sent then
            exports.sunset_ui:Notify(sendErr or 'The server rejected this message. Check the recipient and try again.', 'error')
            return
        end
        local refreshed = Sunset.AwaitCallback('sunset:getPhoneData') or {}
        exports.sunset_ui:Send('phoneUpdate', refreshed)
    end)
end)

AddEventHandler('sunset:nui:phoneAddContact', function(data)
    CreateThread(function()
        data = data or {}
        local res, err = Sunset.AwaitCallback('sunset:phoneAddContact', data.name, data.phone)
        if res and res.ok then
            exports.sunset_ui:Notify(('Contact "%s" added.'):format(res.contact and res.contact.name or 'friend'), 'success')
            local refreshed = Sunset.AwaitCallback('sunset:getPhoneData') or {}
            exports.sunset_ui:Send('phoneUpdate', refreshed)
        else
            exports.sunset_ui:Notify(err or 'Could not save contact.', 'error')
        end
    end)
end)

AddEventHandler('sunset:nui:phoneDeleteContact', function(data)
    CreateThread(function()
        data = data or {}
        local res, err = Sunset.AwaitCallback('sunset:phoneDeleteContact', data.contactId)
        if res and res.ok then
            exports.sunset_ui:Notify('Contact deleted.', 'success')
            local refreshed = Sunset.AwaitCallback('sunset:getPhoneData') or {}
            exports.sunset_ui:Send('phoneUpdate', refreshed)
        else
            exports.sunset_ui:Notify(err or 'Could not delete contact.', 'error')
        end
    end)
end)

RegisterNetEvent('sunset:client:phoneMessage', function()
    if not phoneOpen then return end
    CreateThread(function()
        local refreshed = Sunset.AwaitCallback('sunset:getPhoneData') or {}
        exports.sunset_ui:Send('phoneUpdate', refreshed)
    end)
end)

CreateThread(function()
    while true do
        if phoneOpen then
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 47, true)  -- weapon
            DisableControlAction(0, 58, true)
            DisableControlAction(0, 140, true) -- melee
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisablePlayerFiring(PlayerId(), true)

            local ped = PlayerPedId()
            if not phoneProp or not DoesEntityExist(phoneProp) then
                attachPhoneProp(ped)
            end
            if not IsEntityPlayingAnim(ped, 'cellphone@', 'cellphone_text_read_base', 3) then
                if loadAnimDict('cellphone@') then
                    TaskPlayAnim(ped, 'cellphone@', 'cellphone_text_read_base', 3.0, 3.0, -1, 49, 0, false, false, false)
                end
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removePhoneProp()
end)

exports('Open', openPhone)
exports('Close', closePhone)
exports('IsOpen', function() return phoneOpen end)
