local jailed = false
local jailReleaseAt = 0
local radarActive = false
local lastRadarLock = 0
local radarVehicle = 0
local radarLimitKmh = 0

local function chatLine(name, message, messageType)
    exports.sunset_ui:Send('chatMessage', {
        id = 0, type = messageType or 'police_alert', name = name, message = message, time = '',
    })
end

local function actionError(err, fallback)
    exports.sunset_ui:Notify(err or fallback or 'The action could not be completed. Check your duty, rank, target ID and distance.', 'error', 8000)
end

local function nearestBookingPoint(setWaypoint)
    local points = Sunset.Police and Sunset.Police.bookingPoints or {}
    local pos = GetEntityCoords(PlayerPedId())
    local nearest, distance
    for _, point in ipairs(points) do
        local current = #(pos - point.coords)
        if not distance or current < distance then nearest, distance = point, current end
    end
    if nearest and setWaypoint then SetNewWaypoint(nearest.coords.x, nearest.coords.y) end
    return nearest, distance
end

RegisterNetEvent('sunset:police:chatAlert', function(data)
    data = data or {}
    chatLine(data.tag or 'POLICE ALERT', data.message or 'Police activity nearby.', data.type)
end)

local function kmhFromEntity(entity)
    return math.floor(GetEntitySpeed(entity) * 3.6 + 0.5)
end

local function getVehicleInRadarCone()
    if radarVehicle == 0 or not DoesEntityExist(radarVehicle) then return 0, 0 end
    local origin = GetEntityCoords(radarVehicle)
    local forward = GetEntityForwardVector(radarVehicle)
    local cfg = Sunset.Police and Sunset.Police.radar or {}
    local range = cfg.mobileRange or 45.0
    local bestVeh, bestSpeed = 0, 0
    local bestDot = -1.0

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= radarVehicle and DoesEntityExist(veh) then
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
                        bestSpeed = kmhFromEntity(veh)
                    end
                end
            end
        end
    end

    return bestVeh, bestSpeed
end

local function stopRadar(showMessage)
    if radarVehicle ~= 0 and DoesEntityExist(radarVehicle) then
        FreezeEntityPosition(radarVehicle, false)
        SetVehicleHandbrake(radarVehicle, false)
    end
    if radarActive then Sunset.AwaitCallback('sunset:policeRadarStop') end
    radarActive, radarVehicle, radarLimitKmh = false, 0, 0
    if showMessage then exports.sunset_ui:Notify('Speed radar stopped — patrol vehicle unlocked.', 'info') end
end

RegisterNetEvent('sunset:police:summonAlert', function(data)
    data = data or {}
    TriggerEvent('sunset:ui:policeOrder', {
        officer = data.officer or 'Law Enforcement',
        officerId = data.officerId,
        message = data.message or 'You are being summoned — stop and comply',
        duration = 15000,
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
            local ped = PlayerPedId()
            local invalidRadarVehicle = radarVehicle == 0 or not DoesEntityExist(radarVehicle)
                or GetPedInVehicleSeat(radarVehicle, -1) ~= ped
                or Entity(radarVehicle).state.sunsetFactionVehicle ~= 'police'
            if invalidRadarVehicle then
                stopRadar(false)
                exports.sunset_ui:Notify('Radar stopped because you left the driver seat or patrol vehicle.', 'warning', 6000)
            else
                FreezeEntityPosition(radarVehicle, true)
                SetVehicleHandbrake(radarVehicle, true)
                local veh, speed = getVehicleInRadarCone()
                if veh ~= 0 and speed > 0 then
                    local cfg = Sunset.Police and Sunset.Police.radar or {}
                    local now = GetGameTimer()
                    if speed > radarLimitKmh and now - lastRadarLock >= (cfg.lockCooldownMs or 4000) then
                        lastRadarLock = now
                        local result = Sunset.AwaitCallback('sunset:policeRadarLock', NetworkGetNetworkIdFromEntity(veh))
                        if result and result.flagged then
                            exports.sunset_ui:Notify(result.message or ('Radar lock: %d km/h'):format(speed), 'warning', 5000)
                        end
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
        local reasons, err = Sunset.AwaitCallback('sunset:policeReasons')
        chatLine('LSPD', '=== Set Wanted (/su [id] [reason]) ===')
        if reasons then
            for _, row in ipairs(reasons) do
                chatLine('LSPD', ('%s — %s (★%d, %d min)'):format(row.code, row.label, row.stars, row.jailMinutes))
            end
        else
            actionError(err, 'Cannot view wanted reasons: go on duty as law enforcement first.')
        end
        return
    end

    if not reasonCode then
        exports.sunset_ui:Notify('Usage: /su [id] [reason_code] — type /su for reason list', 'error')
        return
    end

    local ok, err = Sunset.AwaitCallback('sunset:policeSetWanted', target, reasonCode)
    if not ok then actionError(err, 'Wanted charge was not added. Use /su without arguments to see valid reasons.') end
end, false)

RegisterCommand('so', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /so [id]', 'error')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:policeSummon', target)
    if not ok then actionError(err, 'Stop order was not sent.') end
end, false)

RegisterCommand('clear', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /clear [id]', 'error')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:policeClearWanted', target)
    if ok then exports.sunset_ui:Notify(('Cleared wanted for #%d'):format(target), 'success')
    else actionError(err, 'Wanted status was not cleared.') end
end, false)

RegisterCommand('wanted', function()
    local list, err = Sunset.AwaitCallback('sunset:policeWantedList')
    if not list then
        actionError(err, 'Wanted list could not be opened.')
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
    if not ok then
        actionError(err, 'Arrest failed: cuff the wanted suspect, escort them into a booking marker, then retry.')
        if type(err) == 'string' and err:find('/booking', 1, true) then nearestBookingPoint(true) end
    end
end, false)

RegisterCommand('booking', function()
    local point, distance = nearestBookingPoint(true)
    if not point then
        return actionError(nil, 'No police booking locations are configured. Report this to staff.')
    end
    exports.sunset_ui:Notify(('GPS set to %s (%.0fm). Bring the cuffed wanted suspect into the blue marker, then use /arrest [id].'):format(
        point.label, distance or 0.0), 'info', 10000)
end, false)

RegisterCommand('backup', function()
    local ok, err = Sunset.AwaitCallback('sunset:policeBackup')
    if ok then exports.sunset_ui:Notify(('Backup request #%d sent — /cbackup to cancel'):format(ok), 'success')
    else actionError(err, 'Backup was not sent. Check duty, rank and Dispatch availability.') end
end, false)

RegisterCommand('cbackup', function()
    local ok, err = Sunset.AwaitCallback('sunset:policeCancelBackup')
    if ok then exports.sunset_ui:Notify('Backup request cancelled', 'success')
    else actionError(err, 'Backup could not be cancelled. You may not have an active request.') end
end, false)

RegisterCommand('mdc', function()
    local list, err = Sunset.AwaitCallback('sunset:policeWantedList')
    if not list then return actionError(err, 'MDC could not open. Check duty and rank.') end
    exports.sunset_ui:Send('mdcShow', { wanted = list })
    exports.sunset_ui:SetFocus(true, true)
end, false)

RegisterCommand('ticket', function(_, args)
    local violations, err = Sunset.AwaitCallback('sunset:policeViolations')
    if not violations then return actionError(err, 'Cannot open citations: go on duty as law enforcement first.') end
    exports.sunset_ui:Send('ticketShow', { violations = violations, targetId = tonumber(args[1]) })
    exports.sunset_ui:SetFocus(true, true)
end, false)

RegisterCommand('confiscate', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /confiscate [id]', 'error')
        return
    end
    local removed, err = Sunset.AwaitCallback('sunset:policeConfiscate', target)
    if not removed then return actionError(err, 'Confiscation failed. Check duty, rank, ID, distance and target inventory.') end
    chatLine('LSPD', ('=== Confiscated from #%d ==='):format(target))
    for _, row in ipairs(removed) do
        chatLine('LSPD', ('%s x%d'):format(row.label or row.item, row.count))
    end
    exports.sunset_ui:Notify('Contraband confiscated', 'success')
end, false)

RegisterCommand('startradar', function(_, args)
    if radarActive then
        return exports.sunset_ui:Notify(('Radar is already active at %d km/h. Use /stopradar first.'):format(radarLimitKmh), 'warning')
    end
    local cfg = Sunset.Police and Sunset.Police.radar or {}
    local limit = tonumber(args[1])
    if not limit then
        return exports.sunset_ui:Notify(('Usage: /startradar [limit_kmh] — example: /startradar %d'):format(cfg.defaultLimitKmh or 90), 'error', 8000)
    end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return exports.sunset_ui:Notify('You must be in the driver seat of an LSPD patrol vehicle.', 'error', 7000)
    end
    if Entity(vehicle).state.sunsetFactionVehicle ~= 'police' then
        return exports.sunset_ui:Notify('Mobile radar only works in an LSPD vehicle spawned at the MRPD garage.', 'error', 7000)
    end
    local result, err = Sunset.AwaitCallback('sunset:policeRadarStart', NetworkGetNetworkIdFromEntity(vehicle), limit)
    if not result then return actionError(err, 'Cannot start radar.') end

    radarActive = true
    radarVehicle = vehicle
    radarLimitKmh = result.limitKmh
    lastRadarLock = 0
    FreezeEntityPosition(vehicle, true)
    SetVehicleHandbrake(vehicle, true)
    chatLine('RADAR', ('Mobile radar active: %d km/h limit. Patrol vehicle is locked until /stopradar.'):format(radarLimitKmh), 'radar')
    exports.sunset_ui:Notify(('Radar active at %d km/h — vehicle locked. Use /stopradar before pursuing.'):format(radarLimitKmh), 'success', 8000)
end, false)

RegisterCommand('stopradar', function()
    if not radarActive then return exports.sunset_ui:Notify('Radar is not active. Start it with /startradar [limit_kmh].', 'info') end
    stopRadar(true)
end, false)

RegisterCommand('radars', function()
    local list, err = Sunset.AwaitCallback('sunset:policeFixedRadars')
    if not list then return actionError(err, 'Fixed radar locations could not be loaded. Go on duty as law enforcement.') end
    chatLine('LSPD', '=== Fixed Speed Cameras ===')
    if #list == 0 then
        chatLine('LSPD', 'No fixed cameras configured')
        return
    end
    for _, row in ipairs(list) do
        chatLine('LSPD', ('%s — %d mph limit (%.0f, %.0f)'):format(row.label, row.limitMph, row.x, row.y))
    end
end, false)

AddEventHandler('sunset:nui:ticketIssue', function(data)
    data = data or {}
    local reason = data.reason or ''
    if not data.violationCode or data.violationCode == '' then
        exports.sunset_ui:Notify('Select a violation from the citation list before pressing ISSUE CITATION.', 'error')
        return
    end
    if not tonumber(data.targetId) or tonumber(data.targetId) < 1 then
        exports.sunset_ui:Notify('Enter the player server ID shown in F10.', 'error')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:policeIssueTicket', tonumber(data.targetId), nil, reason, data.violationCode)
    if ok then
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Send('ticketHide', {})
        exports.sunset_ui:Notify('Citation issued', 'success')
    else actionError(err, 'Citation was not issued. Check the target ID, violation and distance.') end
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
        actionError(err, 'Citation payment failed. Check that it is still active and that you have enough bank or cash funds.')
    end
end)

AddEventHandler('sunset:ui:ticketRefuseRequest', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:policeRefuseTicket', tonumber(data and data.ticketId))
    if ok then
        exports.sunset_ui:Send('ticketReceiveHide', {})
        exports.sunset_ui:SetFocus(false, false)
    else
        actionError(err, 'Citation could not be refused. It may already have been handled.')
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
    TriggerEvent('chat:addSuggestion', '/booking', 'Set GPS to the nearest police booking marker')
    TriggerEvent('chat:addSuggestion', '/backup', 'Request emergency backup (LEO/EMS/Fire notified)')
    TriggerEvent('chat:addSuggestion', '/cbackup', 'Cancel your active backup request')
    TriggerEvent('chat:addSuggestion', '/mdc', 'Mobile data terminal')
    TriggerEvent('chat:addSuggestion', '/ticket', 'Issue citation (UI)', { { name = 'id', help = 'optional target ID' } })
    TriggerEvent('chat:addSuggestion', '/confiscate', 'Confiscate contraband (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/startradar', 'Lock an LSPD patrol vehicle and monitor speed', { { name = 'limit_kmh', help = '20-250' } })
    TriggerEvent('chat:addSuggestion', '/stopradar', 'Deactivate mobile speed radar')
    TriggerEvent('chat:addSuggestion', '/radars', 'List fixed speed cameras')
    TriggerEvent('chat:addSuggestion', '/m', 'Megaphone', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/handsup', 'Toggle hands up')
    TriggerEvent('chat:addSuggestion', '/escort', 'Escort restrained suspect', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/frisk', 'Frisk suspect', { { name = 'id' } })
end)

CreateThread(function()
    for _, point in ipairs((Sunset.Police and Sunset.Police.bookingPoints) or {}) do
        local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
        SetBlipSprite(blip, 60)
        SetBlipColour(blip, 29)
        SetBlipScale(blip, 0.65)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(point.label)
        EndTextCommandSetBlipName(blip)
    end

    while true do
        local char = exports.sunset_core:GetCharacter()
        local factionId = char and Sunset.GetCharacterFaction(char)
        local isPolice = factionId and Sunset.FactionTypeMatches(factionId, 'law_enforcement')
        local wait = 1200
        if isPolice then
            local pos = GetEntityCoords(PlayerPedId())
            for _, point in ipairs((Sunset.Police and Sunset.Police.bookingPoints) or {}) do
                local distance = #(pos - point.coords)
                if distance < 30.0 then
                    wait = 0
                    DrawMarker(1, point.coords.x, point.coords.y, point.coords.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.5, 2.5, 0.8, 35, 145, 255, 130,
                        false, false, 2, false, nil, nil, false)
                    if distance < 4.0 then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('Police booking: cuff + wanted + /arrest [id]')
                        EndTextCommandDisplayHelp(0, false, true, -1)
                    end
                end
            end
        end
        Wait(wait)
    end
end)

exports('IsJailed', function() return jailed end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    radarActive = false
end)
