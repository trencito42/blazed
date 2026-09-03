local isCuffed = false
local jailed = false
local jailEndMs = 0

local CUFF_DICT = 'mp_arresting'
local CUFF_ANIM = 'idle'

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function applyCuffState(state)
    isCuffed = state == true
    local ped = PlayerPedId()

    if isCuffed then
        SetEnableHandcuffs(ped, true)
        if loadAnimDict(CUFF_DICT) then
            TaskPlayAnim(ped, CUFF_DICT, CUFF_ANIM, 8.0, -8.0, -1, 49, 0, false, false, false)
        end
        exports.sunset_ui:Notify('You have been restrained', 'error')
    else
        SetEnableHandcuffs(ped, false)
        ClearPedTasks(ped)
        exports.sunset_ui:Notify('Restraints removed', 'success')
    end
end

RegisterNetEvent('sunset:faction:cuff', function()
    applyCuffState(true)
end)

RegisterNetEvent('sunset:faction:uncuff', function()
    applyCuffState(false)
end)

RegisterNetEvent('sunset:police:jail', function(minutes, coords)
    minutes = math.max(1, tonumber(minutes) or 2)
    jailed = true
    jailEndMs = GetGameTimer() + minutes * 60000

    if isCuffed then applyCuffState(false) end

    local ped = PlayerPedId()
    if coords and coords.x then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        if coords.w then SetEntityHeading(ped, coords.w) end
    end

    exports.sunset_ui:Notify(('Sentenced — %d minutes remaining'):format(minutes), 'error', 8000)
end)

CreateThread(function()
    while true do
        if isCuffed then
            local ped = PlayerPedId()
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 58, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)

            if IsPedInAnyVehicle(ped, false) then
                DisableControlAction(0, 75, true)
                DisableControlAction(0, 23, true)
            end

            SetPedCanPlayGestureAnims(ped, false)
            if not IsEntityPlayingAnim(ped, CUFF_DICT, CUFF_ANIM, 3) and loadAnimDict(CUFF_DICT) then
                TaskPlayAnim(ped, CUFF_DICT, CUFF_ANIM, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if jailed then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)

            if GetGameTimer() >= jailEndMs then
                jailed = false
                local release = Sunset.Police and Sunset.Police.releaseCoords
                local ped = PlayerPedId()
                if release then
                    SetEntityCoords(ped, release.x, release.y, release.z, false, false, false, false)
                    SetEntityHeading(ped, release.w or 0.0)
                end
                exports.sunset_ui:Notify('Your sentence is complete — you are free', 'success', 6000)
            end
            Wait(0)
        else
            Wait(800)
        end
    end
end)

local function chatLine(name, message)
    exports.sunset_ui:Send('chatMessage', { id = 0, name = name, message = message, time = '' })
end

RegisterCommand('su', function(_, args)
    local target = tonumber(args[1])
    local reasonCode = args[2]

    if not target then
        local reasons = Sunset.AwaitCallback('sunset:policeReasons')
        chatLine('LSPD', '=== Set Wanted (/su [id] [reason]) ===')
        if reasons then
            for _, row in ipairs(reasons) do
                chatLine('LSPD', ('%s — %s (★%d, %d min)'):format(row.code, row.label, row.stars, row.jailMinutes))
            end
        else
            exports.sunset_ui:Notify('You must be on-duty LSPD', 'error')
        end
        return
    end

    if not reasonCode then
        exports.sunset_ui:Notify('Usage: /su [id] [reason_code] — type /su for reason list', 'error')
        return
    end

    local ok, err = Sunset.AwaitCallback('sunset:policeSetWanted', target, reasonCode)
    if not ok then exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('so', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /so [id]', 'error')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:policeSummon', target)
    if not ok then exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('wanted', function()
    local list, err = Sunset.AwaitCallback('sunset:policeWantedList')
    if not list then
        exports.sunset_ui:Notify(err or 'Failed', 'error')
        return
    end

    chatLine('LSPD', '=== Active Wanted ===')
    if #list == 0 then
        chatLine('LSPD', 'No active wanted players online')
        return
    end

    for _, row in ipairs(list) do
        local mins = math.ceil((row.remainingSec or 0) / 60)
        chatLine('LSPD', ('#%d %s — ★%d %s (%d min left)'):format(
            row.id, row.name or 'Unknown', row.level, row.reason or '—', mins))
    end
end, false)

RegisterCommand('arrest', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /arrest [id]', 'error')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:policeArrest', target)
    if not ok then exports.sunset_ui:Notify(err or 'Arrest failed', 'error') end
end, false)

RegisterCommand('backup', function()
    local ok, err = Sunset.AwaitCallback('sunset:policeBackup')
    if ok then exports.sunset_ui:Notify(('Backup request sent to %d units'):format(ok), 'success')
    else exports.sunset_ui:Notify(err or 'Backup failed', 'error') end
end, false)

RegisterCommand('mdc', function()
    local list, err = Sunset.AwaitCallback('sunset:policeWantedList')
    if not list then return exports.sunset_ui:Notify(err or 'MDC unavailable', 'error') end
    exports.sunset_ui:Send('mdcShow', { wanted = list })
    exports.sunset_ui:SetFocus(true, true)
end, false)

RegisterCommand('ticket', function()
    exports.sunset_ui:Send('ticketShow', {})
    exports.sunset_ui:SetFocus(true, true)
end, false)

RegisterNetEvent('sunset:police:backupBlip', function(coords, officerId)
    if not coords then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 1.1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Backup #%d'):format(officerId or 0))
    EndTextCommandSetBlipName(blip)
    SetTimeout(60000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

AddEventHandler('sunset:nui:ticketIssue', function(data)
    exports.sunset_ui:SetFocus(false, false)
    local ok, err = Sunset.AwaitCallback('sunset:policeFine', tonumber(data.targetId), tonumber(data.amount), data.reason or '')
    if ok then exports.sunset_ui:Notify('Citation issued', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end)

AddEventHandler('sunset:nui:ticketClose', function()
    exports.sunset_ui:SetFocus(false, false)
end)

AddEventHandler('sunset:nui:mdcClose', function()
    exports.sunset_ui:SetFocus(false, false)
end)

CreateThread(function()
    Wait(3500)
    TriggerEvent('chat:addSuggestion', '/su', 'Set wanted level (LSPD)', { { name = 'id' }, { name = 'reason_code' } })
    TriggerEvent('chat:addSuggestion', '/so', 'Summon suspect nearby (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/wanted', 'List active wanted players (LSPD)')
    TriggerEvent('chat:addSuggestion', '/arrest', 'Arrest restrained suspect (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/backup', 'Request LSPD backup')
    TriggerEvent('chat:addSuggestion', '/mdc', 'Mobile data terminal')
    TriggerEvent('chat:addSuggestion', '/ticket', 'Issue citation (UI)')
    TriggerEvent('chat:addSuggestion', '/m', 'Megaphone', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/handsup', 'Toggle hands up')
    TriggerEvent('chat:addSuggestion', '/escort', 'Escort restrained suspect', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/frisk', 'Frisk suspect', { { name = 'id' } })
end)

exports('IsCuffedLocal', function() return isCuffed end)
exports('IsJailed', function() return jailed end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isCuffed then
        SetEnableHandcuffs(PlayerPedId(), false)
        ClearPedTasks(PlayerPedId())
    end
end)
