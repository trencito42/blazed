local phoneOpen = false

local function playPhoneAnim(open)
    local ped = PlayerPedId()
    local dict = 'cellphone@'
    if open then
        RequestAnimDict(dict)
        local t = GetGameTimer() + 2000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, 'cellphone_text_in', 3.0, -1, -1, 50, 0, false, false, false)
        end
    else
        StopAnimTask(ped, dict, 'cellphone_text_in', 1.0)
        StopAnimTask(ped, dict, 'cellphone_text_out', 1.0)
    end
end

local function openPhone()
    if phoneOpen then return end

    CreateThread(function()
        if IsNuiFocused() then
            exports.sunset_ui:Send('menuHide', {})
            exports.sunset_ui:SetFocus(false, false, false)
            Wait(200)
        end

        local data = Sunset.AwaitCallback('sunset:getPhoneData') or {}
        phoneOpen = true
        playPhoneAnim(true)
        exports.sunset_ui:Send('phoneShow', data)
        exports.sunset_ui:SetFocus(true, true, false)
    end)
end

local function closePhone()
    if not phoneOpen then return end
    phoneOpen = false
    playPhoneAnim(false)
    exports.sunset_ui:SetFocus(false, false, false)
    exports.sunset_ui:Send('phoneHide', {})
end

RegisterCommand('phone', function()
    if phoneOpen then closePhone() else openPhone() end
end, false)
RegisterKeyMapping('phone', 'Open phone', 'keyboard', 'P')

AddEventHandler('sunset:nui:phoneClose', function()
    closePhone()
end)

AddEventHandler('sunset:nui:phoneSend', function(data)
    CreateThread(function()
        local ok, err = pcall(function()
            Sunset.AwaitCallback('sunset:phoneSend', tonumber(data.targetId), data.message)
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

AddEventHandler('sunset:nui:menuAction', function(data)
    if data and data.action == 'phone' then
        openPhone()
    end
end)

exports('Open', openPhone)
exports('Close', closePhone)
exports('IsOpen', function() return phoneOpen end)
