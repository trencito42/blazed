local chatOpen = false
local chatHistory = {}
local historyIndex = -1

local function inputBlocked()
    return chatOpen or IsNuiFocused()
end
exports('IsChatOpen', function() return chatOpen end)

local lastPreview = nil

local function sendTypingPreview(text)
    text = tostring(text or '')
    if text == lastPreview then return end
    lastPreview = text
    TriggerServerEvent('sunset:chat:typing', text)
end

local function openChat()
    if chatOpen then return end
    chatOpen = true
    local myId = GetPlayerServerId(PlayerId())
    local myName = LocalPlayer.state.sunsetName or GetPlayerName(PlayerId()) or 'Player'
    local isAdmin = false
    pcall(function() isAdmin = (exports.sunset_admin:GetAdminLevel() or 0) > 0 end)
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('chatToggle', {
        open = true,
        playerId = myId,
        playerName = myName,
        isAdmin = isAdmin,
    })
end

local function closeChat()
    if not chatOpen then return end
    chatOpen = false
    sendTypingPreview('')
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('chatToggle', { open = false })
end

RegisterCommand('sunset_chat', function()
    openChat()
end, false)
RegisterKeyMapping('sunset_chat', 'Open chat', 'keyboard', 'T')

RegisterCommand('sunset_chat_close', function()
    if chatOpen then closeChat() end
end, false)
RegisterKeyMapping('sunset_chat_close', 'Close chat', 'keyboard', 'ESCAPE')

AddEventHandler('sunset:nui:chatPreview', function(data)
    if not chatOpen or not viewerCanSeeChatPreview() then return end
    sendTypingPreview(data and data.text or '')
end)

AddEventHandler('sunset:nui:chatSend', function(data)
    sendTypingPreview('')
    closeChat()

    local msg = (data.message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if msg == '' then return end

    chatHistory[#chatHistory + 1] = msg
    historyIndex = #chatHistory + 1

    if msg:sub(1, 1) == '/' then
        local command = msg:sub(2)
        TriggerServerEvent('sunset:chat:runCommand', command)
    else
        TriggerServerEvent('sunset:chat:send', msg)
    end
end)

RegisterNetEvent('sunset:chat:executeCommand', function(command)
    if type(command) ~= 'string' or command == '' then return end
    SetTimeout(0, function()
        ExecuteCommand(command)
    end)
end)

RegisterNetEvent('sunset:chat:system', function(message, kind)
    local msgType = 'command_info'
    if kind == 'error' then
        msgType = 'command_error'
    elseif kind == 'warning' then
        msgType = 'command_warn'
    end
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        name = 'SYSTEM',
        message = tostring(message or ''),
        time = os.date('%H:%M:%S'),
        type = msgType,
    })
end)

AddEventHandler('sunset:nui:chatClose', function()
    sendTypingPreview('')
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

local Typing = {}
local Overhead = {}
local OVERHEAD_MS = 5000

local function viewerCanSeeChatPreview()
    local ok, level = pcall(function() return exports.sunset_admin:GetAdminLevel() end)
    return ok and (tonumber(level) or 0) > 0
end

RegisterNetEvent('sunset:chat:message', function(payload)
    exports.sunset_ui:Send('chatMessage', payload)
    local msgType = payload and payload.type or 'say'
    local id = tonumber(payload and payload.id)
    local text = tostring(payload and payload.message or '')
    if not id or id <= 0 or text == '' then return end
    if msgType == 'me' then
        text = '* ' .. text
    elseif msgType == 'do' then
        text = '** ' .. text .. ' **'
    elseif msgType ~= 'say' then
        return
    end
    Overhead[id] = { text = text, untilAt = GetGameTimer() + OVERHEAD_MS }
end)

RegisterNetEvent('sunset:chat:typing', function(payload)
    local id = tonumber(payload and payload.id)
    if not id or id == GetPlayerServerId(PlayerId()) then return end
    local text = tostring(payload and payload.message or '')
    if text == '' then
        Typing[id] = nil
        return
    end
    Typing[id] = { text = text, untilAt = GetGameTimer() + 2500 }
end)

local function drawOverhead3d(x, y, z, text, r, g, b)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.30, 0.30)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r or 255, g or 230, b or 140, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function drawTyping3d(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.30, 0.30)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 230, 140, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    while true do
        local now = GetGameTimer()
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local drew = false

        for serverId, row in pairs(Overhead) do
            if not row or now > (row.untilAt or 0) then
                Overhead[serverId] = nil
            else
                local player = GetPlayerFromServerId(serverId)
                if player == -1 then
                    for _, pid in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(pid) == serverId then
                            player = pid
                            break
                        end
                    end
                end
                if player ~= -1 then
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 and DoesEntityExist(ped) then
                        local coords = GetEntityCoords(ped)
                        if #(myCoords - coords) < 22.0 then
                            local shown = row.text
                            if #shown > 72 then shown = shown:sub(1, 72) .. '...' end
                            drawOverhead3d(coords.x, coords.y, coords.z + 1.42, shown, 255, 255, 255)
                            drew = true
                        end
                    end
                end
            end
        end

        for serverId, row in pairs(Typing) do
            if not viewerCanSeeChatPreview() then
                Typing[serverId] = nil
            elseif not row or now > (row.untilAt or 0) then
                Typing[serverId] = nil
            elseif not Overhead[serverId] then
                local player = GetPlayerFromServerId(serverId)
                if player == -1 then
                    for _, pid in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(pid) == serverId then
                            player = pid
                            break
                        end
                    end
                end
                if player ~= -1 then
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 and DoesEntityExist(ped) then
                        local coords = GetEntityCoords(ped)
                        if #(myCoords - coords) < 22.0 then
                            local shown = row.text
                            if #shown > 72 then shown = shown:sub(1, 72) .. '...' end
                            drawTyping3d(coords.x, coords.y, coords.z + 1.36, shown)
                            drew = true
                        end
                    end
                end
            end
        end
        Wait(drew and 0 or 200)
    end
end)

AddEventHandler('sunset:client:playerSpawned', function()
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        name = 'SERVER',
        message = 'Welcome to SunsetMP! T = chat, /help for commands.',
        time = '',
    })
end)

-- NUI focus handles input; do not DisableAllControlActions here (breaks chat keys/copy).

CreateThread(function()
    while true do
        SetTextChatEnabled(false)
        if chatOpen then
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        else
            Wait(200)
        end
    end
end)
