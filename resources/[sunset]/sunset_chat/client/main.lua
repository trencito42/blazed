local chatOpen = false

local function openChat()
    if chatOpen then return end
    chatOpen = true
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('chatToggle', { open = true })
end

local function closeChat()
    if not chatOpen then return end
    chatOpen = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('chatToggle', { open = false })
end

RegisterCommand('sunset_chat', function()
    openChat()
end, false)
RegisterKeyMapping('sunset_chat', 'Deschide chat', 'keyboard', 'T')

AddEventHandler('sunset:nui:chatSend', function(data)
    closeChat()

    local msg = (data.message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if msg == '' then return end

    if msg:sub(1, 1) == '/' then
        ExecuteCommand(msg:sub(2))
    else
        TriggerServerEvent('sunset:chat:send', msg)
    end
end)

AddEventHandler('sunset:nui:chatClose', function()
    closeChat()
end)

RegisterNetEvent('sunset:chat:message', function(payload)
    exports.sunset_ui:Send('chatMessage', payload)
end)

AddEventHandler('sunset:client:playerSpawned', function()
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        name = 'SERVER',
        message = 'Bine ai venit pe SunsetMP! T = chat, /comandă pentru comenzi.',
        time = '',
    })
end)

CreateThread(function()
    while true do
        if chatOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- push to talk
        end
        Wait(chatOpen and 0 or 500)
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        SetTextChatEnabled(false)
        HideHudComponentThisFrame(19)
    end
end)
