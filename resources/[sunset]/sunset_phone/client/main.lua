local phoneOpen = false
local phoneProp = nil
local phoneBusy = false
local PHONE_MODEL = `prop_amb_phone`

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

local function clearPhoneAnim(ped)
    local dict = 'cellphone@'
    StopAnimTask(ped, dict, 'cellphone_text_read_base', 1.0)
    StopAnimTask(ped, dict, 'cellphone_text_in', 1.0)
    StopAnimTask(ped, dict, 'cellphone_text_out', 1.0)
    ClearPedSecondaryTask(ped)
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
        removePhoneProp()
        clearPhoneAnim(ped)
        if loadAnimDict(dict) then
            TaskPlayAnim(ped, dict, 'cellphone_text_out', 3.0, 1000, -1, 50, 0, false, false, false)
            Wait(250)
            clearPhoneAnim(ped)
        end
    end
end

local function openPhone()
    if phoneOpen or phoneBusy then return end
    phoneBusy = true

    CreateThread(function()
        if IsNuiFocused() then
            exports.sunset_ui:Send('menuHide', {})
            exports.sunset_ui:SetFocus(false, false, false)
            Wait(200)
        end

        local char = exports.sunset_core:GetCharacter()
        if char then
            TriggerServerEvent('sunset:server:setCharacter', char)
        end

        local data, err = Sunset.AwaitCallback('sunset:getPhoneData')
        if not data then
            phoneBusy = false
            exports.sunset_ui:Notify(err or 'Could not load phone data', 'error')
            return
        end

        phoneOpen = true
        phoneBusy = false
        DisablePlayerFiring(PlayerId(), true)
        playPhoneSound('open')
        playPhoneAnim(true)
        exports.sunset_ui:Send('phoneShow', data)
        exports.sunset_ui:SetFocus(true, true, false)
    end)
end

local function closePhone()
    if phoneBusy then return end
    if not phoneOpen and not phoneProp then return end

    phoneBusy = true
    phoneOpen = false
    playPhoneSound('close')
    removePhoneProp()
    clearPhoneAnim(PlayerPedId())
    exports.sunset_ui:SetFocus(false, false, false)
    exports.sunset_ui:Send('phoneHide', {})

    CreateThread(function()
        playPhoneAnim(false)
        phoneBusy = false
    end)
end

local function togglePhone()
    if phoneBusy then return end
    if phoneOpen then closePhone() else openPhone() end
end

RegisterCommand('phone', togglePhone, false)

-- P opens/closes phone in-world only. When NUI has focus, the web UI handles P/Escape.
CreateThread(function()
    while true do
        DisableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE (P)
        if not IsNuiFocused() and IsDisabledControlJustReleased(0, 199) then
            togglePhone()
        end
        Wait(0)
    end
end)

AddEventHandler('sunset:nui:phoneClose', function()
    closePhone()
end)

AddEventHandler('sunset:nui:phoneSend', function(data)
    CreateThread(function()
        local ok, err = pcall(function()
            Sunset.AwaitCallback('sunset:phoneSend', tonumber(data.targetCharacterId), data.message)
        end)
        if not ok then
            exports.sunset_ui:Notify(tostring(err) or 'Could not send', 'error')
            return
        end
        local refreshed = Sunset.AwaitCallback('sunset:getPhoneData') or {}
        exports.sunset_ui:Send('phoneUpdate', refreshed)
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
    clearPhoneAnim(PlayerPedId())
end)

exports('Open', openPhone)
exports('Close', closePhone)
exports('IsOpen', function() return phoneOpen end)
