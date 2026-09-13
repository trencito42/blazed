local chatOpen = false
local chatHistory = {}
local historyIndex = -1

local function inputBlocked()
    return chatOpen or IsNuiFocused()
end
exports('IsChatOpen', function() return chatOpen end)

local function fetchChatChannels()
    local ok, channels = pcall(function()
        return Sunset.AwaitCallback('sunset:getChatChannels')
    end)
    if ok and type(channels) == 'table' then return channels end
    return nil
end

local function openChat()
    if chatOpen then return end
    TriggerEvent('sunset:phone:forceClose')
    chatOpen = true
    TriggerEvent('sunset:client:chatFocusChanged', true)
    local myId = GetPlayerServerId(PlayerId())
    local myName = LocalPlayer.state.sunsetName or GetPlayerName(PlayerId()) or 'Player'
    exports.sunset_ui:SetFocus(true, true, false, 'chat')
    exports.sunset_ui:Send('chatToggle', {
        open = true,
        playerId = myId,
        playerName = myName,
        channels = fetchChatChannels(),
    })
    exports.sunset_chat:SyncChatSuggestions()
    SetTimeout(75, function()
        if chatOpen then exports.sunset_ui:SetFocus(true, true, false, 'chat') end
    end)
end

local function closeChat()
    if not chatOpen then return end
    chatOpen = false
    TriggerEvent('sunset:client:chatFocusChanged', false)
    exports.sunset_ui:SetFocus(false, false, false, 'chat')
    exports.sunset_ui:Send('chatToggle', { open = false })
end

RegisterCommand('sunset_chat', function()
    if exports.sunset_ui and exports.sunset_ui:IsOpen() then return end
    openChat()
end, false)
RegisterKeyMapping('sunset_chat', 'Open chat', 'keyboard', 'T')

RegisterCommand('sunset_chat_close', function()
    if chatOpen then closeChat() end
end, false)
RegisterKeyMapping('sunset_chat_close', 'Close chat', 'keyboard', 'ESCAPE')

AddEventHandler('sunset:nui:chatSend', function(data)
    closeChat()

    local msg = (data.message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if msg == '' then return end

    chatHistory[#chatHistory + 1] = msg
    historyIndex = #chatHistory + 1

    if msg:sub(1, 1) == '/' then
        local command = msg:sub(2)
        TriggerServerEvent('sunset:chat:runCommand', command)
    else
        local channel = tostring(data.channel or 'all'):lower()
        TriggerServerEvent('sunset:chat:send', msg, channel)
    end
end)

RegisterNetEvent('sunset:chat:executeCommand', function(command)
    if type(command) ~= 'string' or command == '' then return end
    SetTimeout(0, function()
        ExecuteCommand(command)
    end)
end)

local function chatTimeStamp()
    return string.format('%02d:%02d:%02d', GetClockHours(), GetClockMinutes(), GetClockSeconds())
end

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
        time = chatTimeStamp(),
        type = msgType,
    })
end)

-- /cc admin wipe (server broadcasts to -1)
RegisterNetEvent('sunset:chat:clear', function()
    exports.sunset_ui:Send('chatClear', {})
end)

AddEventHandler('sunset:nui:chatClose', function()
    closeChat()
end)

AddEventHandler('sunset:nui:chatHistory', function(data)
    if data.direction == 'up' then
        if #chatHistory == 0 then return end
        historyIndex = math.max(1, historyIndex - 1)
        exports.sunset_ui:Send('chatSetInput', { text = chatHistory[historyIndex] or '', history = true })
    elseif data.direction == 'down' then
        if #chatHistory == 0 then return end
        historyIndex = math.min(#chatHistory + 1, historyIndex + 1)
        local text = historyIndex > #chatHistory and '' or (chatHistory[historyIndex] or '')
        exports.sunset_ui:Send('chatSetInput', { text = text, history = true })
    end
end)

local Overhead = {}
local OVERHEAD_MS = 5000
local OVERHEAD_Z = 1.56

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
    if id == GetPlayerServerId(PlayerId()) then return end
    Overhead[id] = { text = text, untilAt = GetGameTimer() + OVERHEAD_MS }
end)

local function drawOverhead3d(x, y, z, text, r, g, b)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.28, 0.28)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r or 255, g or 255, b or 255, 230)
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
        local myServerId = GetPlayerServerId(PlayerId())
        local drew = false

        for serverId, row in pairs(Overhead) do
            if serverId == myServerId then
                Overhead[serverId] = nil
            elseif not row or now > (row.untilAt or 0) then
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
                            drawOverhead3d(coords.x, coords.y, coords.z + OVERHEAD_Z, shown, 255, 255, 255)
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
        message = 'Welcome to blaze.mp! T = chat, /help for commands.',
        time = '',
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- [CHAT SHIM] The stock FiveM chat resource is DISABLED on this
-- server (SetTextChatEnabled(false), no default chat NUI), so
-- every TriggerClientEvent('chat:addMessage', ...) emitted by
-- resources (turf war announcements, /profiler output, dice,
-- lottery, /trunk listings, cinematic tool, ...) went nowhere.
-- Bridge it into the custom sunset_ui chat feed.
-- ═══════════════════════════════════════════════════════════════
RegisterNetEvent('chat:addMessage')
AddEventHandler('chat:addMessage', function(msg)
    if type(msg) == 'string' then
        exports.sunset_ui:Send('chatMessage', {
            id = 0, name = 'SYSTEM', message = msg, time = chatTimeStamp(),
        })
        return
    end
    if type(msg) ~= 'table' then return end
    local name = 'SYSTEM'
    local text = msg.message
    if type(msg.args) == 'table' then
        name = tostring(msg.args[1] or name)
        text = msg.args[2]
    elseif msg.args ~= nil then
        text = msg.args
    end
    text = tostring(text or '')
    if text == '' then return end
    -- Stock chat args may carry ^N color codes; strip them, the UI themes lines itself.
    text = text:gsub('%^%d', '')
    local msgType = 'command_info'
    local color = msg.color
    if type(color) == 'table' then
        local r, g, b = color[1] or 0, color[2] or 0, color[3] or 0
        if r > 180 and g < 110 and b < 110 then msgType = 'command_error'
        elseif r > 180 and g > 140 and b < 110 then msgType = 'command_warn' end
    end
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        name = name,
        message = text,
        time = chatTimeStamp(),
        type = msgType,
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
