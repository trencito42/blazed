local chatOpen = false
local chatHistory = {}
local historyIndex = -1

local function inputBlocked()
    return chatOpen or IsNuiFocused()
end
exports('IsChatOpen', function() return chatOpen end)

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
RegisterKeyMapping('sunset_chat', 'Open chat', 'keyboard', 'T')

AddEventHandler('sunset:nui:chatSend', function(data)
    closeChat()

    local msg = (data.message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if msg == '' then return end

    chatHistory[#chatHistory + 1] = msg
    historyIndex = #chatHistory + 1

    if msg:sub(1, 1) == '/' then
        ExecuteCommand(msg:sub(2))
    else
        TriggerServerEvent('sunset:chat:send', msg)
    end
end)

AddEventHandler('sunset:nui:chatClose', function()
    closeChat()
end)

AddEventHandler('sunset:nui:chatHistory', function(data)
    if data.direction == 'up' then
        if #chatHistory == 0 then return end
        historyIndex = math.max(1, historyIndex - 1)
        exports.sunset_ui:Send('chatSetInput', { text = chatHistory[historyIndex] or '' })
    elseif data.direction == 'down' then
        if #chatHistory == 0 then return end
        historyIndex = math.min(#chatHistory + 1, historyIndex + 1)
        local text = historyIndex > #chatHistory and '' or (chatHistory[historyIndex] or '')
        exports.sunset_ui:Send('chatSetInput', { text = text })
    end
end)

RegisterNetEvent('sunset:chat:message', function(payload)
    exports.sunset_ui:Send('chatMessage', payload)
end)

AddEventHandler('sunset:client:playerSpawned', function()
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        name = 'SERVER',
        message = 'Welcome to SunsetMP! T = chat, /help for commands.',
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
