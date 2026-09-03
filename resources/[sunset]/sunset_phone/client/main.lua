local phoneOpen = false

local function openPhone()
    if phoneOpen or IsNuiFocused() then return end
    local data = Sunset.AwaitCallback('sunset:getPhoneData') or {}
    phoneOpen = true
    exports.sunset_ui:Send('phoneShow', data)
    exports.sunset_ui:SetFocus(true, true)
end

local function closePhone()
    if not phoneOpen then return end
    phoneOpen = false
    exports.sunset_ui:SetFocus(false, false)
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
    local ok, err = Sunset.AwaitCallback('sunset:phoneSend', tonumber(data.targetId), data.message)
    if ok then
        exports.sunset_ui:Notify('Message sent', 'success')
        local refreshed = Sunset.AwaitCallback('sunset:getPhoneData') or {}
        exports.sunset_ui:Send('phoneUpdate', refreshed)
    else
        exports.sunset_ui:Notify(err or 'Could not send', 'error')
    end
end)

AddEventHandler('sunset:nui:menuAction', function(data)
    if data and data.action == 'phone' then
        openPhone()
    end
end)

exports('Open', openPhone)
exports('Close', closePhone)
