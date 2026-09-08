local jailed = false
local lastJailUi = 0
local jailReleaseAt = 0
local radarActive = false
local lastRadarLock = 0
local radarVehicle = 0
local radarLimitKmh = 0
local radarHits = {}

local function releaseRadarVehicle(veh)
    if veh == 0 or not DoesEntityExist(veh) then return end
    FreezeEntityPosition(veh, false)
    SetVehicleHandbrake(veh, false)
    SetEntityCollision(veh, true, true)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
end

local function drawRadarZoneText(x, y, z, lines, scale, r, g, b)
    scale = scale or 0.32
    SetDrawOrigin(x, y, z, 0)
    for i, line in ipairs(lines) do
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextCentre(true)
        SetTextColour(r or 255, g or 140, b or 0, 235)
        SetTextDropshadow(1, 0, 0, 0, 210)
        SetTextOutline()
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(line)
        EndTextCommandDisplayText(0.0, (i - 1) * 0.018)
    end
    ClearDrawOrigin()
end

local function drawRadarZoneMarkers(vehicle, cfg)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    cfg = cfg or {}
    local range = cfg.mobileRange or 45.0
    local coneDeg = cfg.mobileCone or 18.0
    local coords = GetEntityCoords(vehicle)
    local groundZ = coords.z - 0.95
    local heading = math.rad(GetEntityHeading(vehicle))
    local halfCone = math.rad(coneDeg * 0.5)

    DrawMarker(1, coords.x, coords.y, groundZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        3.0, 3.0, 1.1, 255, 140, 0, 150, false, false, 2, false, nil, nil, false)

    local steps = 6
    for i = 0, steps do
        local t = i / steps
        local angle = heading - halfCone + (2 * halfCone * t)
        local mx = coords.x - math.sin(angle) * range
        local my = coords.y + math.cos(angle) * range
        local alpha = math.floor(55 + 95 * (1 - math.abs(t - 0.5)))
        DrawMarker(1, mx, my, groundZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            3.2, 3.2, 0.35, 255, 110, 0, alpha, false, false, 2, false, nil, nil, false)
    end

    local fx = coords.x - math.sin(heading) * range
    local fy = coords.y + math.cos(heading) * range
    DrawMarker(1, fx, fy, groundZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        5.5, 5.5, 0.45, 255, 70, 0, 120, false, false, 2, false, nil, nil, false)

    drawRadarZoneText(coords.x, coords.y, coords.z + 1.35, {
        ('~o~RADAR ACTIVE~s~  %d km/h'):format(radarLimitKmh),
        ('Range %.0fm'):format(range),
    }, 0.30)
end

local function chatTimeStamp()
    return string.format('%02d:%02d:%02d', GetClockHours(), GetClockMinutes(), GetClockSeconds())
end

local function chatLine(name, message, messageType)
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        type = messageType or 'hq',
        name = name,
        message = message,
        time = chatTimeStamp(),
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
    local msgType = data.type or 'hq'
    if msgType == 'police_alert' or data.tag == 'STOP ORDER' or data.tag == 'POLICE ORDER' or data.tag == 'POLICE ALERT' then
        msgType = 'police_alert'
    elseif msgType ~= 'radar' then
        msgType = 'hq'
    end
    chatLine(data.tag or 'HQ', data.message or 'Police activity nearby.', msgType)
end)

local function kmhFromEntity(entity)
    return math.floor(GetEntitySpeed(entity) * 3.6 + 0.5)
end

local function isDepotFleetModel(depot, model)
    if not depot or not model then return false end
    if depot.vehicle and model == joaat(depot.vehicle) then return true end
    if depot.vehicles then
        for _, entry in ipairs(depot.vehicles) do
            if entry.model and model == joaat(entry.model) then return true end
        end
    end
    return false
end

local function isAuthorizedRadarVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local model = GetEntityModel(vehicle)
    local char = exports.sunset_core:GetCharacter()
    local factionId = char and Sunset.GetCharacterFaction(char)
    if factionId and Entity(vehicle).state.sunsetFactionVehicle == factionId then return true end
    local faction = factionId and Sunset.Factions[factionId]
    if faction and faction.depot and isDepotFleetModel(faction.depot, model) then return true end
    for _, name in ipairs((Sunset.Police and Sunset.Police.radar and Sunset.Police.radar.allowedModels) or {}) do
        if model == joaat(name) then return true end
    end
    return false
end

local function radarFeedback(message, kind)
    local msgType = 'command_info'
    if kind == 'error' then
        msgType = 'command_error'
    elseif kind == 'warning' then
        msgType = 'command_warn'
    end
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        type = msgType,
        name = 'RADAR',
        message = message,
        time = chatTimeStamp(),
    })
    exports.sunset_ui:Notify(message, kind or 'info', 8000)
end

local function rotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function getVehicleInCameraView()
    local cfg = Sunset.Police and Sunset.Police.radar or {}
    local range = cfg.mobileRange or 45.0
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot)
    local dest = camCoord + (direction * range)

    local handle = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z,
        dest.x, dest.y, dest.z,
        10, radarVehicle, 7
    )
    local _, hit, _, _, entityHit = GetShapeTestResult(handle)
    if hit == 1 and entityHit and entityHit ~= 0 and IsEntityAVehicle(entityHit) and entityHit ~= radarVehicle then
        local driver = GetPedInVehicleSeat(entityHit, -1)
        if driver ~= 0 and IsPedAPlayer(driver) then
            return entityHit, kmhFromEntity(entityHit)
        end
    end

    local bestVeh, bestSpeed, bestDot = 0, 0, -1.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= radarVehicle and DoesEntityExist(veh) and IsEntityOnScreen(veh) then
            local vehCoords = GetEntityCoords(veh)
            local delta = vehCoords - camCoord
            local dist = #(delta)
            if dist <= range and dist > 2.0 then
                local dir = delta / dist
                local dot = direction.x * dir.x + direction.y * dir.y + direction.z * dir.z
                if dot >= 0.82 and dot > bestDot then
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

local function radarTargetInfo(veh, speed)
    if veh == 0 or not DoesEntityExist(veh) then
        return { plate = '--------', name = '—', speed = speed or 0 }
    end
    local plate = (GetVehicleNumberPlateText(veh) or '--------'):gsub('^%s+', ''):gsub('%s+$', '')
    local name = 'Unknown'
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= 0 and IsPedAPlayer(driver) then
        local player = NetworkGetPlayerIndexFromPed(driver)
        if player ~= -1 then
            local sid = GetPlayerServerId(player)
            local st = Player(sid) and Player(sid).state
            local display = st and st.sunsetDisplayName
            if type(display) == 'string' and display ~= '' then
                name = display
            else
                local tagged = st and st.sunsetName
                local base = (tagged and tagged ~= '' and tagged) or GetPlayerName(player) or 'Player'
                name = ('%s (%d)'):format(base, sid)
            end
        end
    end
    return { plate = plate ~= '' and plate or '--------', name = name, speed = speed or 0 }
end

local function pushRadarUi(extra)
    extra = extra or {}
    local info = extra.info or { plate = '--------', name = '—', speed = 0 }
    exports.sunset_ui:Send('radarShow', {
        state = extra.state or 'scan',
        title = extra.title or 'Mobile Radar',
        message = extra.message or 'Aim at a vehicle…',
        limit = radarLimitKmh,
        speed = info.speed or 0,
        plate = info.plate,
        name = info.name,
        hits = radarHits,
    })
end

local function stopRadar(showMessage)
    local veh = radarVehicle
    local wasActive = radarActive
    radarActive = false
    radarVehicle = 0
    radarLimitKmh = 0
    radarHits = {}
    lastRadarLock = 0
    exports.sunset_ui:Send('radarHide', {})
    releaseRadarVehicle(veh)
    if wasActive then
        CreateThread(function()
            Sunset.AwaitCallback('sunset:policeRadarStop')
        end)
    end
    if showMessage then
        exports.sunset_ui:Notify('Speed radar stopped — patrol vehicle unlocked.', 'info')
    end
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
    pcall(function() exports.sunset_death:ClearDead() end)
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
        local reviveAt = coords and coords.x and coords or GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(
            reviveAt.x, reviveAt.y, reviveAt.z,
            (coords and coords.w) or GetEntityHeading(ped), true, false
        )
        ped = PlayerPedId()
        SetEntityHealth(ped, 200)
        ClearPedBloodDamage(ped)
        SetEntityInvincible(ped, false)
        SetPlayerControl(PlayerId(), true, 0)
    end
    ClearPedTasksImmediately(ped)
    SetEnableHandcuffs(ped, false)
    TriggerEvent('sunset:faction:uncuff')
    if coords and coords.x then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        if coords.w then SetEntityHeading(ped, coords.w) end
    end

    exports.sunset_ui:Notify(('Sentenced — %d minutes remaining'):format(minutes), 'error', 8000)
    TriggerEvent('sunset:ui:jobObjective', {
        title = 'Prison sentence',
        subtitle = ('%d minutes remaining'):format(minutes),
        progress = 0,
    })
end)

RegisterNetEvent('sunset:police:release', function()
    jailed = false
    jailReleaseAt = 0
    TriggerEvent('sunset:ui:jobObjective', { hide = true })
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

            if GetGameTimer() - lastJailUi > 1000 then
                lastJailUi = GetGameTimer()
                local remaining = math.max(0, jailReleaseAt - GetCloudTimeAsInt())
                TriggerEvent('sunset:ui:jobObjective', {
                    title = 'Prison sentence',
                    subtitle = ('%d:%02d remaining'):format(math.floor(remaining / 60), remaining % 60),
                    progress = 0,
                })
            end
            if GetCloudTimeAsInt() >= jailReleaseAt then
                jailed = false
                jailReleaseAt = 0
                TriggerEvent('sunset:ui:jobObjective', { hide = true })
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
        if radarActive and radarVehicle ~= 0 and DoesEntityExist(radarVehicle) then
            drawRadarZoneMarkers(radarVehicle, Sunset.Police and Sunset.Police.radar)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if radarActive then
            local ped = PlayerPedId()
            local invalidRadarVehicle = radarVehicle == 0 or not DoesEntityExist(radarVehicle)
                or GetPedInVehicleSeat(radarVehicle, -1) ~= ped
                or not isAuthorizedRadarVehicle(radarVehicle)
            if invalidRadarVehicle then
                stopRadar(false)
                exports.sunset_ui:Notify('Radar stopped because you left the driver seat or patrol vehicle.', 'warning', 6000)
            else
                FreezeEntityPosition(radarVehicle, true)
                SetVehicleHandbrake(radarVehicle, true)
                local veh, speed = getVehicleInCameraView()
                if veh ~= 0 and speed > 0 then
                    local info = radarTargetInfo(veh, speed)
                    local cfg = Sunset.Police and Sunset.Police.radar or {}
                    local now = GetGameTimer()
                    if speed > radarLimitKmh then
                        pushRadarUi({
                            state = 'lock',
                            title = 'Radar Lock',
                            message = ('%s  %d km/h  +%d'):format(info.plate, speed, speed - radarLimitKmh),
                            info = info,
                        })
                        if now - lastRadarLock >= (cfg.lockCooldownMs or 4000) then
                            lastRadarLock = now
                            local result = Sunset.AwaitCallback('sunset:policeRadarLock', NetworkGetNetworkIdFromEntity(veh))
                            if result and result.flagged then
                                table.insert(radarHits, 1, {
                                    plate = result.plate or info.plate,
                                    name = info.name,
                                    speed = result.speed or speed,
                                    over = (result.speed or speed) - radarLimitKmh,
                                })
                                if #radarHits > 5 then radarHits[6] = nil end
                                pushRadarUi({
                                    state = 'lock',
                                    title = 'Radar Lock',
                                    message = result.message or ('%s caught at %d km/h'):format(info.plate, speed),
                                    info = info,
                                })
                            end
                        end
                    else
                        pushRadarUi({
                            state = 'track',
                            title = 'Mobile Radar',
                            message = ('%s in view — legal'):format(info.plate),
                            info = info,
                        })
                    end
                else
                    pushRadarUi({
                        state = 'scan',
                        title = 'Mobile Radar',
                        message = 'Aim at a vehicle…',
                    })
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
                chatLine('LSPD', ('%s — %s (★%d, %d min if arrested, %s)'):format(
                    row.code, row.label, row.stars, row.jailMinutes,
                    row.surrenderable == false and 'NO SURRENDER' or 'surrender allowed'))
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

RegisterCommand('unjail', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /unjail [id]', 'error')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:policeUnjail', target)
    if ok then exports.sunset_ui:Notify(('Released #%d from jail'):format(target), 'success')
    else actionError(err, 'Prisoner could not be released.') end
end, false)

RegisterCommand('find', function(_, args)
    local target = tonumber(args[1])
    if not target then
        exports.sunset_ui:Notify('Usage: /find [id]', 'error')
        return
    end
    local result, err = Sunset.AwaitCallback('sunset:policeFindWanted', target)
    if not result then
        return actionError(err, 'Could not track that suspect. Go on duty as law enforcement and use a valid wanted player ID.')
    end
    SetNewWaypoint(result.x + 0.0, result.y + 0.0)
    exports.sunset_ui:Notify(
        ('GPS set on %s (%d) — wanted ★%d (%s).'):format(result.name or 'Suspect', target, result.level or 1, result.reason or 'active'),
        'success', 10000)
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
        chatLine('LSPD', ('%s %s — ★%d %s — %s (%d min to next star)'):format(
            status, row.name or 'Unknown', row.level, row.reason or '—',
            row.surrenderable == false and 'NO SURRENDER' or 'surrender allowed', mins))
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

local isMdtOpen = false

local function canAccessMdt(ped)
    ped = ped or PlayerPedId()
    if IsPedDeadOrDying(ped, true) or GetEntityHealth(ped) <= 0 then
        return false
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        if GetVehicleClass(vehicle) == 18 then return true end
        if isAuthorizedRadarVehicle(vehicle) then return true end
        local entState = Entity(vehicle).state.sunsetFactionVehicle
        if entState == 'police' or entState == 'sheriff' or entState == 'fib' then return true end
    end

    local pCoords = GetEntityCoords(ped)
    local terminals = {
        vector3(441.8, -982.5, 30.7),   -- MRPD Mission Row front desk
        vector3(459.7, -986.9, 30.7),   -- MRPD dispatch briefing
        vector3(1853.2, 3682.1, 34.3),  -- Sandy Shores Sheriff office
        vector3(-448.2, 6012.3, 31.7),  -- Paleto Bay Sheriff station
        vector3(136.1, -749.1, 262.9),  -- FIB HQ executive office
        vector3(94.2, -745.2, 45.8),    -- FIB ground floor lobby desk
    }
    for _, term in ipairs(terminals) do
        if #(pCoords - term) <= 8.0 then
            return true
        end
    end

    local char = exports.sunset_core:GetCharacter()
    local factionId = char and Sunset.GetCharacterFaction(char)
    local faction = factionId and Sunset.Factions[factionId]
    if faction and faction.hq and #(pCoords - vector3(faction.hq.x, faction.hq.y, faction.hq.z)) <= 15.0 then
        return true
    end

    return false
end

RegisterCommand('mdc', function()
    local ped = PlayerPedId()
    if not canAccessMdt(ped) then
        exports.sunset_ui:Notify('Access Denied: The MDT Toughbook can only be operated from inside an emergency vehicle or at a station terminal.', 'error', 6000)
        return
    end

    local mdcData, err = Sunset.AwaitCallback('sunset:policeMdcData')
    if not mdcData then
        return actionError(err, 'MDT could not open. Check duty and rank.')
    end

    exports.sunset_ui:Send('mdcShow', mdcData)
    exports.sunset_ui:SetFocus(true, true)
    isMdtOpen = true

    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

    CreateThread(function()
        while isMdtOpen do
            Wait(800)
            if not canAccessMdt(PlayerPedId()) then
                exports.sunset_ui:Send('mdcHide', {})
                exports.sunset_ui:SetFocus(false, false)
                isMdtOpen = false
                exports.sunset_ui:Notify('MDT connection lost (exited vehicle/terminal).', 'warning')
                break
            end
        end
    end)
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

local function tryStartRadar(requestedLimit)
    if radarActive then
        return radarFeedback(('Radar is already active at %d km/h. Use /stopradar first.'):format(radarLimitKmh), 'warning')
    end
    local cfg = Sunset.Police and Sunset.Police.radar or {}
    local limit = tonumber(requestedLimit) or cfg.defaultLimitKmh or 90
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return radarFeedback('Sit in the driver seat of an LSPD patrol car, then use /startradar 90.', 'error')
    end
    if not isAuthorizedRadarVehicle(vehicle) then
        return radarFeedback('This is not an LSPD patrol car. Use the MRPD garage or a marked cruiser.', 'error')
    end
    local result, err = Sunset.AwaitCallback('sunset:policeRadarStart', NetworkGetNetworkIdFromEntity(vehicle), limit)
    if not result then
        radarFeedback(err or 'Cannot start radar. Go on duty as LSPD first.', 'error')
        return
    end

    radarActive = true
    radarVehicle = vehicle
    radarLimitKmh = result.limitKmh
    lastRadarLock = 0
    FreezeEntityPosition(vehicle, true)
    SetVehicleHandbrake(vehicle, true)
    radarHits = {}
    pushRadarUi({
        state = 'scan',
        title = 'Mobile Radar',
        message = 'Scanning lane…',
    })
    radarFeedback(('Mobile radar active: %d km/h. Orange zone marks the scan lane ahead.'):format(radarLimitKmh), 'success')
end

RegisterNetEvent('sunset:police:tryStartRadar', function(limit)
    tryStartRadar(limit)
end)

RegisterNetEvent('sunset:police:tryStopRadar', function()
    if not radarActive then return radarFeedback('Radar is not active. Start it with /startradar 90.', 'info') end
    stopRadar(true)
end)

RegisterCommand('startradar', function(_, args)
    tryStartRadar(args[1])
end, false)

RegisterCommand('setradar', function(_, args)
    tryStartRadar(args[1])
end, false)

RegisterCommand('radar', function(_, args)
    tryStartRadar(args[1])
end, false)

RegisterCommand('stopradar', function()
    if not radarActive then return radarFeedback('Radar is not active. Start it with /startradar 90.', 'info') end
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

local function getPlayerMugshot(targetServerId)
    if not targetServerId then return nil end
    local player = GetPlayerFromServerId(tonumber(targetServerId))
    if not player or player == -1 then return nil end
    local targetPed = GetPlayerPed(player)
    if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then return nil end
    local handle = RegisterPedheadshot(targetPed)
    if not handle or handle == 0 then return nil end
    local timeout = GetGameTimer() + 2500
    while not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) do
        if GetGameTimer() > timeout then
            UnregisterPedheadshot(handle)
            return nil
        end
        Wait(40)
    end
    local txd = GetPedheadshotTxdString(handle)
    local url = ('https://nui-img/%s/%s'):format(txd, txd)
    SetTimeout(60000, function()
        pcall(function() UnregisterPedheadshot(handle) end)
    end)
    return url
end

AddEventHandler('sunset:ui:mdcSearchRequest', function(data)
    local query = data and (data.query or data.targetId or data.id)
    local result = Sunset.AwaitCallback('sunset:policeMdcLookup', query)
    if result and result.found and result.serverId then
        result.photoUrl = getPlayerMugshot(result.serverId)
    end
    exports.sunset_ui:Send('mdcUpdateCitizen', { citizen = result })
end)

AddEventHandler('sunset:ui:mdcVehicleSearch', function(data)
    local query = data and (data.query or data.plate or data.model)
    local result = Sunset.AwaitCallback('sunset:policeMdcVehicleLookup', query)
    exports.sunset_ui:Send('mdcUpdateVehicles', { vehicles = result and result.results or {} })
end)

AddEventHandler('sunset:ui:mdcToggleBolo', function(data)
    if not data or not data.key then return end
    local res, err = Sunset.AwaitCallback('sunset:policeMdcToggleBolo', data.type, data.key, data.reason, data.notes)
    if res and res.ok then
        exports.sunset_ui:Notify(res.active and ('BOLO issued for %s.'):format(res.key) or ('BOLO cleared for %s.'):format(res.key), 'success')
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err or (res and res.error), 'Failed to update BOLO.')
    end
end)

AddEventHandler('sunset:ui:mdcSetUnitStatus', function(data)
    if not data or not data.status then return end
    local res, err = Sunset.AwaitCallback('sunset:policeMdcSetUnitStatus', data.status)
    if res and res.ok then
        exports.sunset_ui:Notify(('Unit status updated: %s'):format(res.status), 'success')
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err or (res and res.error), 'Failed to update unit status.')
    end
end)

AddEventHandler('sunset:ui:mdcSetCallStatus', function(data)
    if not data or not data.callId or not data.action then return end
    local res, err = Sunset.AwaitCallback('sunset:policeMdcSetCallStatus', data.callId, data.action)
    if res and res.ok then
        exports.sunset_ui:Notify(data.action == 'respond' and 'Attached to 112 emergency (10-97 En Route).' or '112 call cleared (10-98 Complete).', 'success')
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err or (res and res.error), 'Failed to update call status.')
    end
end)

AddEventHandler('sunset:ui:mdcSetWaypoint', function(data)
    if data and data.x and data.y then
        SetNewWaypoint(tonumber(data.x) + 0.0, tonumber(data.y) + 0.0)
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
        exports.sunset_ui:Notify('GPS route set to location.', 'success')
    end
end)

AddEventHandler('sunset:ui:mdcSetUnitWaypoint', function(data)
    if data and data.x and data.y then
        SetNewWaypoint(tonumber(data.x) + 0.0, tonumber(data.y) + 0.0)
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
        exports.sunset_ui:Notify(('GPS route set to Unit %s.'):format(data.name or 'Officer'), 'success')
    end
end)

AddEventHandler('sunset:ui:mdcBookingGps', function()
    local point, distance = nearestBookingPoint(true)
    if point then
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
        exports.sunset_ui:Notify(('GPS set to %s (%.0fm).'):format(point.label, distance or 0.0), 'info', 8000)
    else
        exports.sunset_ui:Notify('No booking points found.', 'error')
    end
end)

AddEventHandler('sunset:ui:mdcRequestBackup', function(data)
    local priority = (data and data.priority) or 'code2'
    local isPanic = priority == 'panic' or priority == '10-99'
    local ok, err = Sunset.AwaitCallback('sunset:policeBackup', priority)
    if ok then
        if isPanic then
            PlaySoundFrontend(-1, 'Bed', 'WastedSounds', true)
            exports.sunset_ui:Notify('🚨 10-99 PANIC ALARM BROADCASTED! Code 3 distress active!', 'error', 10000)
        else
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            exports.sunset_ui:Notify(('Backup request #%d sent (%s)'):format(ok, priority == 'code3' and 'CODE 3' or 'Code 2'), 'success')
        end
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err, 'Backup was not sent. Check duty and availability.')
    end
end)

AddEventHandler('sunset:ui:mdcCancelBackup', function()
    local ok, err = Sunset.AwaitCallback('sunset:policeCancelBackup')
    if ok then
        PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        exports.sunset_ui:Notify('Backup request cancelled', 'success')
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err, 'No active backup request to cancel.')
    end
end)

AddEventHandler('sunset:ui:mdcSetWanted', function(data)
    if not data or not data.targetId or not data.reasonCode then return end
    local ok, err = Sunset.AwaitCallback('sunset:policeSetWanted', tonumber(data.targetId), data.reasonCode)
    if ok then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        exports.sunset_ui:Notify(('Wanted charge added to #%d (%s)'):format(tonumber(data.targetId), data.reasonCode), 'success')
        -- Refresh citizen dossier if open
        local citizenResult = Sunset.AwaitCallback('sunset:policeMdcLookup', tostring(data.targetId))
        if citizenResult then exports.sunset_ui:Send('mdcUpdateCitizen', { citizen = citizenResult }) end
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err, 'Could not add wanted charge.')
    end
end)

AddEventHandler('sunset:ui:mdcClearWanted', function(data)
    if not data or not data.targetId then return end
    local ok, err = Sunset.AwaitCallback('sunset:policeClearWanted', tonumber(data.targetId))
    if ok then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        exports.sunset_ui:Notify(('Cleared wanted for #%d'):format(tonumber(data.targetId)), 'success')
        local citizenResult = Sunset.AwaitCallback('sunset:policeMdcLookup', tostring(data.targetId))
        if citizenResult then exports.sunset_ui:Send('mdcUpdateCitizen', { citizen = citizenResult }) end
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err, 'Wanted status could not be cleared.')
    end
end)

AddEventHandler('sunset:ui:mdcSummon', function(data)
    if not data or not data.targetId then return end
    local ok, err = Sunset.AwaitCallback('sunset:policeSummon', tonumber(data.targetId))
    if ok then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else
        actionError(err, 'Stop order failed to send.')
    end
end)

AddEventHandler('sunset:ui:mdcFindWanted', function(data)
    if not data or not data.targetId then return end
    local result, err = Sunset.AwaitCallback('sunset:policeFindWanted', tonumber(data.targetId))
    if result then
        SetNewWaypoint(result.x + 0.0, result.y + 0.0)
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
        exports.sunset_ui:Notify(('GPS set on %s (#%d) — ★%d %s'):format(result.name or 'Suspect', tonumber(data.targetId), result.level or 1, result.reason or ''), 'success', 10000)
    else
        actionError(err, 'Could not locate suspect.')
    end
end)

AddEventHandler('sunset:ui:mdcUnjail', function(data)
    if not data or not data.targetId then return end
    local ok, err = Sunset.AwaitCallback('sunset:policeUnjail', tonumber(data.targetId))
    if ok then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        exports.sunset_ui:Notify(('Released #%d from custody'):format(tonumber(data.targetId)), 'success')
        local citizenResult = Sunset.AwaitCallback('sunset:policeMdcLookup', tostring(data.targetId))
        if citizenResult then exports.sunset_ui:Send('mdcUpdateCitizen', { citizen = citizenResult }) end
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err, 'Prisoner could not be released.')
    end
end)

AddEventHandler('sunset:ui:mdcIssueCitation', function(data)
    if not data or not data.targetId or not data.reasonCode then return end
    local ok, err = Sunset.AwaitCallback('sunset:policeIssueTicket', tonumber(data.targetId), tonumber(data.amount) or 100, data.reason, data.reasonCode)
    if ok then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        exports.sunset_ui:Notify(('Citation #%d issued to #%d'):format(ok, tonumber(data.targetId)), 'success')
        local citizenResult = Sunset.AwaitCallback('sunset:policeMdcLookup', tostring(data.targetId))
        if citizenResult then exports.sunset_ui:Send('mdcUpdateCitizen', { citizen = citizenResult }) end
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err, 'Failed to issue citation.')
    end
end)

AddEventHandler('sunset:ui:mdcStartRadar', function(data)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        exports.sunset_ui:Notify('You must be inside an authorized patrol car to start mobile radar.', 'error')
        return
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local limit = tonumber(data and data.limitKmh) or 90
    local res, err = Sunset.AwaitCallback('sunset:policeRadarStart', netId, limit)
    if res then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        exports.sunset_ui:Notify(('Mobile radar active (Limit: %d km/h).'):format(res.limitKmh), 'success')
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    else
        actionError(err, 'Could not start mobile radar.')
    end
end)

AddEventHandler('sunset:ui:mdcStopRadar', function()
    local ok = Sunset.AwaitCallback('sunset:policeRadarStop')
    if ok then
        PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        exports.sunset_ui:Notify('Mobile radar deactivated.', 'info')
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    end
end)

RegisterNetEvent('sunset:dispatch:112CallAlert', function(callData)
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
    exports.sunset_ui:Notify(('🚨 112 CALL: %s at %s (%s)'):format(callData.category or 'Emergency', callData.street or 'Unknown', callData.caller or 'Citizen'), 'warning', 10000)
    if isMdtOpen then
        local freshData = Sunset.AwaitCallback('sunset:policeMdcData')
        if freshData then exports.sunset_ui:Send('mdcRefresh', freshData) end
    end
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
    isMdtOpen = false
    exports.sunset_ui:SetFocus(false, false)
end)

CreateThread(function()
    Wait(3500)
    TriggerEvent('chat:addSuggestion', '/su', 'Set wanted level (LSPD)', { { name = 'id' }, { name = 'reason_code' } })
    TriggerEvent('chat:addSuggestion', '/so', 'Summon suspect nearby (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/clear', 'Clear wanted status (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/find', 'Set GPS on a wanted player (LSPD on duty)', { { name = 'id', help = 'Server ID from /wanted or F10' } })
    TriggerEvent('chat:addSuggestion', '/wanted', 'List active wanted players (LSPD)')
    TriggerEvent('chat:addSuggestion', '/arrest', 'Arrest restrained suspect at jail zone (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/booking', 'Set GPS to the nearest police booking marker')
    TriggerEvent('chat:addSuggestion', '/backup', 'Request emergency backup (LEO/EMS/Fire notified)')
    TriggerEvent('chat:addSuggestion', '/cbackup', 'Cancel your active backup request')
    TriggerEvent('chat:addSuggestion', '/mdc', 'Mobile data terminal')
    TriggerEvent('chat:addSuggestion', '/ticket', 'Issue citation (UI)', { { name = 'id', help = 'optional target ID' } })
    TriggerEvent('chat:addSuggestion', '/confiscate', 'Confiscate contraband (LSPD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/startradar', 'Lock an LSPD patrol vehicle and monitor speed', { { name = 'limit_kmh', help = '20-250, default 90' } })
    TriggerEvent('chat:addSuggestion', '/setradar', 'Alias for /startradar', { { name = 'limit_kmh', help = '20-250, default 90' } })
    TriggerEvent('chat:addSuggestion', '/radar', 'Alias for /startradar', { { name = 'limit_kmh', help = '20-250, default 90' } })
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
    releaseRadarVehicle(radarVehicle)
    radarActive = false
    radarVehicle = 0
end)

-- ====================================================================
-- FIXED SPEED CAMERAS (RADARE FIXE)
-- ====================================================================
local fixedRadarBlips = {}
local clientRadarCooldowns = {}

local function isEmergencyExempt(ped, veh)
    if exports.sunset_factions and exports.sunset_factions:IsOnDuty() then
        local char = exports.sunset_core and exports.sunset_core:GetCharacter()
        local factionId = char and char.metadata and char.metadata.faction
        local faction = factionId and Sunset.Factions and Sunset.Factions[factionId]
        if faction and (faction.type == 'legal' or faction.factionType == 'law_enforcement' or faction.factionType == 'ems' or faction.factionType == 'fire_rescue') then
            return true
        end
    end
    if GetVehicleClass(veh) == 18 or IsVehicleSirenOn(veh) then
        return true
    end
    return false
end

CreateThread(function()
    Wait(3000)
    for idx, radar in ipairs(Sunset.Police and Sunset.Police.fixedRadars or {}) do
        local blip = AddBlipForCoord(radar.coords.x, radar.coords.y, radar.coords.z)
        SetBlipSprite(blip, 184)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.65)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        local limit = radar.limitKmh or math.floor((radar.limitMph or 50) * 1.60934)
        AddTextComponentSubstringPlayerName(('Radar Fix [%d km/h]'):format(limit))
        EndTextCommandSetBlipName(blip)
        fixedRadarBlips[idx] = blip
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then
            local pCoords = GetEntityCoords(veh)
            local speedKmh = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)
            local radars = Sunset.Police and Sunset.Police.fixedRadars or {}
            local now = GetGameTimer()

            for idx, radar in ipairs(radars) do
                local dist = #(pCoords - radar.coords)
                local rad = radar.radius or 25.0
                if dist <= rad then
                    local limit = radar.limitKmh or math.floor((radar.limitMph or 50) * 1.60934)
                    if speedKmh > limit then
                        local lastTrigger = clientRadarCooldowns[idx] or 0
                        if (now - lastTrigger) >= 15000 then
                            clientRadarCooldowns[idx] = now

                            if isEmergencyExempt(ped, veh) then
                                exports.sunset_ui:Notify(('RADAR FIX: Vehicul de intervenție autorizat (%d km/h — exceptat de la amendă).'):format(speedKmh), 'info', 4000)
                            else
                                CreateThread(function()
                                    PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_SoundSet_Default', true)
                                    local start = GetGameTimer()
                                    while GetGameTimer() - start < 100 do
                                        DrawRect(0.5, 0.5, 1.0, 1.0, 255, 255, 255, 220)
                                        Wait(0)
                                    end
                                end)

                                local plate = GetVehicleNumberPlateText(veh)
                                local modelHash = GetEntityModel(veh)
                                local modelName = GetDisplayNameFromVehicleModel(modelHash) or 'Vehicul'

                                TriggerServerEvent('sunset:police:fixedRadarTrigger', idx, speedKmh, plate, modelName)
                            end
                        end
                    end
                end
            end
            Wait(300)
        else
            Wait(1200)
        end
    end
end)
