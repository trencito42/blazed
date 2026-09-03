local jailed = false
local jailReleaseAt = 0
local radarActive = false
local lastRadarLock = 0

local function chatLine(name, message)
    exports.sunset_ui:Send('chatMessage', { id = 0, name = name, message = message, time = '' })
end

local function mphFromEntity(entity)
    return math.floor(GetEntitySpeed(entity) * 2.236936 + 0.5)
end

local function getVehicleInRadarCone()
    local ped = PlayerPedId()
    local origin = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local cfg = Sunset.Police and Sunset.Police.radar or {}
    local range = cfg.mobileRange or 45.0
    local bestVeh, bestSpeed, bestPlate = 0, 0, nil
    local bestDot = -1.0

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local vehCoords = GetEntityCoords(veh)
            local delta = vehCoords - origin
            local dist = #(delta)
            if dist <= range and dist > 2.0 then
                local dir = delta / dist
                local dot = forward.x * dir.x + forward.y * dir.y + forward.z * dir.z
                if dot >= 0.92 and dot > bestDot then
                    local driver = GetPedInVehicleSeat(veh, -1)
                    if driver ~= 0 and IsPedAPlayer(driver) then
                        bestDot = dot
                        bestVeh = veh
                        bestSpeed = mphFromEntity(veh)
                        bestPlate = GetVehicleNumberPlateText(veh)
                    end
                end
            end
        end
    end

    return bestVeh, bestSpeed, bestPlate
end

RegisterNetEvent('sunset:police:summonAlert', function(data)
    data = data or {}
    exports.sunset_ui:Send('summonAlert', {
        officer = data.officer or 'Law Enforcement',
        officerId = data.officerId,
        message = data.message or 'You are being summoned — stop and comply',
    })
    exports.sunset_ui:Notify(data.message or 'You are being summoned by law enforcement — stop and comply', 'warning', 15000)
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('sunset:police:jail', function(payload)
    payload = type(payload) == 'table' and payload or { minutes = tonumber(payload) or 2 }
    local releaseAt = payload.releaseAt
    local minutes = payload.minutes or 2
    if not releaseAt then
        releaseAt = GetCloudTimeAsInt() + minutes * 60
    else
        minutes = math.max(1, math.ceil((releaseAt - GetCloudTimeAsInt()) / 60))
    end

    jailed = true
    jailReleaseAt = releaseAt
    local coords = payload.coords

    local ped = PlayerPedId()
    if coords and coords.x then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        if coords.w then SetEntityHeading(ped, coords.w) end
    end

    exports.sunset_ui:Notify(('Sentenced — %d minutes remaining'):format(minutes), 'error', 8000)
end)

RegisterNetEvent('sunset:police:release', function()
    jailed = false
    jailReleaseAt = 0
    local release = Sunset.Police and Sunset.Police.releaseCoords
    local ped = PlayerPedId()
    if release then
        SetEntityCoords(ped, release.x, release.y, release.z, false, false, false, false)
        SetEntityHeading(ped, release.w or 0.0)
    end
end)

CreateThread(function()
    while true do
        if jailed then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)

            if GetCloudTimeAsInt() >= jailReleaseAt then
                jailed = false
                jailReleaseAt = 0
                TriggerServerEvent('sunset:server:jailComplete')
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

CreateThread(function()
    while true do
        if radarActive then
            local veh, speed, plate = getVehicleInRadarCone()
            if veh ~= 0 and speed > 0 then
                local cfg = Sunset.Police and Sunset.Police.radar or {}
                local limit = cfg.defaultLimitMph or 55
                local now = GetGameTimer()
                if speed > limit and now - lastRadarLock >= (cfg.lockCooldownMs or 4000) then
                    lastRadarLock = now
                    local result = Sunset.AwaitCallback('sunset:policeRadarLock', speed, plate)
                    if result and result.flagged then
                        exports.sunset_ui:Notify(result.message or ('Radar lock: %d mph'):format(speed), 'warning', 5000)
                    end
                end
            end
            Wait((Sunset.Police and Sunset.Police.radar and Sunset.Police.radar.scanIntervalMs) or 750)
        else
            Wait(500)
        end
    end
end)

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

RegisterCommand('clear', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /clear [id]', 'error')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:policeClearWanted', target)
    if ok then exports.sunset_ui:Notify(('Cleared wanted for #%d'):format(target), 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('wanted', function()
    local list, err = Sunset.AwaitCallback('sunset:policeWantedList')
    if not list then
        exports.sunset_ui:Notify(err or 'Failed', 'error')
        return
    end

    chatLine('LSPD', '=== Active Wanted (persisted) ===')
    if #list == 0 then
        chatLine('LSPD', 'No active wanted records')
        return
    end

    for _, row in ipairs(list) do
        local mins = math.ceil((row.remainingSec or 0) / 60)
        local status = row.online and ('#' .. tostring(row.id)) or ('CID ' .. tostring(row.characterId) .. ' [offline]')
        chatLine('LSPD', ('%s %s — ★%d %s (%d min left)'):format(
            status, row.name or 'Unknown', row.level, row.reason or '—', mins))
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
    local violations = Sunset.AwaitCallback('sunset:policeViolations') or {}
    exports.sunset_ui:Send('ticketShow', { violations = violations })
    exports.sunset_ui:SetFocus(true, true)
end, false)

RegisterCommand('confiscate', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /confiscate [id]', 'error')
        return
    end
    local removed, err = Sunset.AwaitCallback('sunset:policeConfiscate', target)
    if not removed then return exports.sunset_ui:Notify(err or 'Confiscation failed', 'error') end
    chatLine('LSPD', ('=== Confiscated from #%d ==='):format(target))
    for _, row in ipairs(removed) do
        chatLine('LSPD', ('%s x%d'):format(row.label or row.item, row.count))
    end
    exports.sunset_ui:Notify('Contraband confiscated', 'success')
end, false)

RegisterCommand('startradar', function()
    local violations = Sunset.AwaitCallback('sunset:policeViolations')
    if violations == nil then
        return exports.sunset_ui:Notify('You must be on-duty law enforcement', 'error')
    end
    radarActive = true
    lastRadarLock = 0
    exports.sunset_ui:Notify('Speed radar active — aim at oncoming traffic', 'success')
end, false)

RegisterCommand('stopradar', function()
    radarActive = false
    exports.sunset_ui:Notify('Speed radar deactivated', 'info')
end, false)

RegisterCommand('radars', function()
    local list, err = Sunset.AwaitCallback('sunset:policeFixedRadars')
    if not list then return exports.sunset_ui:Notify(err or 'Unavailable', 'error') end
    chatLine('LSPD', '=== Fixed Speed Cameras ===')
    if #list == 0 then
        chatLine('LSPD', 'No fixed cameras configured')
        return
    end
    for _, row in ipairs(list) do
        chatLine('LSPD', ('%s — %d mph limit (%.0f, %.0f)'):format(row.label, row.limitMph, row.x, row.y))
    end
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
    exports.sunset_ui:Send('ticketHide', {})
    local amount = tonumber(data.amount)
    local reason = data.reason or ''
    if data.violationCode then
        for _, row in ipairs(Sunset.Police.violations or {}) do
            if row.code == data.violationCode then
                amount = row.amount
                reason = row.label
                break
            end
        end
    end
    local ok, err = Sunset.AwaitCallback('sunset:policeIssueTicket', tonumber(data.targetId), amount, reason, data.violationCode)
    if ok then exports.sunset_ui:Notify('Citation issued', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end)

AddEventHandler('sunset:ui:mdcSearchRequest', function(data)
    local result = Sunset.AwaitCallback('sunset:policeMdcLookup', tonumber(data and data.targetId))
    exports.sunset_ui:Send('mdcUpdate', { lookup = result })
end)

AddEventHandler('sunset:ui:ticketPayRequest', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:policePayTicket', tonumber(data and data.ticketId))
    if ok then
        exports.sunset_ui:Send('ticketReceiveHide', {})
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Notify('Citation paid', 'success')
    else
        exports.sunset_ui:Notify(err or 'Payment failed', 'error')
    end
end)

AddEventHandler('sunset:ui:ticketRefuseRequest', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:policeRefuseTicket', tonumber(data and data.ticketId))
    if ok then
        exports.sunset_ui:Send('ticketReceiveHide', {})
        exports.sunset_ui:SetFocus(false, false)
    else
        exports.sunset_ui:Notify(err or 'Could not refuse', 'error')
    end
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
    TriggerEvent('chat:addSuggestion', '/clear', 'Clear wanted status (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/wanted', 'List active wanted players (LSPD)')
    TriggerEvent('chat:addSuggestion', '/arrest', 'Arrest restrained suspect at jail zone (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/backup', 'Request LSPD backup')
    TriggerEvent('chat:addSuggestion', '/mdc', 'Mobile data terminal')
    TriggerEvent('chat:addSuggestion', '/ticket', 'Issue citation (UI)')
    TriggerEvent('chat:addSuggestion', '/confiscate', 'Confiscate contraband (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/startradar', 'Activate mobile speed radar')
    TriggerEvent('chat:addSuggestion', '/stopradar', 'Deactivate mobile speed radar')
    TriggerEvent('chat:addSuggestion', '/radars', 'List fixed speed cameras')
    TriggerEvent('chat:addSuggestion', '/m', 'Megaphone', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/handsup', 'Toggle hands up')
    TriggerEvent('chat:addSuggestion', '/escort', 'Escort restrained suspect', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/frisk', 'Frisk suspect', { { name = 'id' } })
end)

exports('IsJailed', function() return jailed end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    radarActive = false
end)
