local JobClient = {
    state = 'IDLE',
    jobId = nil,
    sessionData = nil,
    vehicles = {},
    blips = {},
    threadActive = false,
    trailerLostSent = false,
}

local function protectJobVehicle(veh)
    if not veh or veh == 0 then return end
    -- Mission/network protection keeps the entity from being cleaned up, but
    -- job vehicles must still take normal damage and be recoverable gameplay.
    SetEntityInvincible(veh, false)
    SetVehicleCanBeVisiblyDamaged(veh, true)
    SetVehicleTyresCanBurst(veh, true)
    SetVehicleEngineCanDegrade(veh, true)
    SetVehicleExplodesOnHighExplosionDamage(veh, false)
    SetEntityProofs(veh, false, false, false, false, false, false, false, false)
end

function JobClient.notify(msg, typ, duration)
    exports.sunset_ui:Notify(msg, typ or 'info', duration)
end

function JobClient.chatSystem(msg, kind)
    local msgType = 'command_info'
    if kind == 'error' then
        msgType = 'command_error'
    elseif kind == 'warning' then
        msgType = 'command_warn'
    end
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        name = 'SYSTEM',
        message = tostring(msg or ''),
        time = string.format('%02d:%02d:%02d', GetClockHours(), GetClockMinutes(), GetClockSeconds()),
        type = msgType,
    })
end

function JobClient.workFeedback(msg, typ, duration)
    JobClient.notify(msg, typ, duration)
    JobClient.chatSystem(msg, typ)
end

function JobClient.showObjective(title, subtitle, progress)
    TriggerEvent('sunset:ui:jobObjective', {
        title = title or 'Job',
        subtitle = subtitle or '',
        progress = progress,
    })
end

function JobClient.hideObjective()
    TriggerEvent('sunset:ui:jobObjective', { hide = true })
end

function JobClient.setWaypoint(coords)
    if not coords then return end
    SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
end

function JobClient.clearBlips()
    for _, blip in ipairs(JobClient.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    JobClient.blips = {}
end

function JobClient.addBlip(coords, preset, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, preset.sprite or 1)
    SetBlipColour(blip, preset.color or 0)
    SetBlipScale(blip, preset.scale or 0.7)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Job')
    EndTextCommandSetBlipName(blip)
    JobClient.blips[#JobClient.blips + 1] = blip
    return blip
end

function JobClient.isNear(coords, radius)
    local p = GetEntityCoords(PlayerPedId())
    local t = type(coords) == 'vector3' and coords or vector3(coords.x, coords.y, coords.z)
    return #(p - t) <= (radius or 3.0)
end

function JobClient.drawMarker(coords, r, g, b)
    DrawMarker(1, coords.x, coords.y, coords.z - 0.95, 0, 0, 0, 0, 0, 0,
        2.0, 2.0, 1.0, r or 255, g or 140, b or 0, 160, false, false, 2, false, nil, nil, false)
end

function JobClient.drawFishingMarker(coords, r, g, b, size)
    local diameter = tonumber(size) or 2.0
    DrawMarker(1, coords.x, coords.y, coords.z - 0.95, 0, 0, 0, 0, 0, 0,
        diameter, diameter, 0.22, r or 52, g or 152, b or 219, 150,
        false, false, 2, false, nil, nil, false)
end

function JobClient.showHelp(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function JobClient.loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

function JobClient.deleteVehicles(keepTruck)
    local startIdx = keepTruck and 2 or 1
    for i = startIdx, #JobClient.vehicles do
        local veh = JobClient.vehicles[i]
        if veh and DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
    end
    if keepTruck and JobClient.vehicles[1] then
        JobClient.vehicles = { JobClient.vehicles[1] }
    else
        JobClient.vehicles = {}
    end
    JobClient.trailerLostSent = false
end

-- [NETWORK FIX] Make a freshly spawned entity explicitly networked and wait
-- until its network ID is stable and non-zero. Under OneSync a client-created
-- vehicle with networked=true normally registers immediately, but the net ID
-- can be 0 for the first frames; asking the server to resolve it during that
-- window is what produced the blind-retry "Could not network" loop.
local function ensureNetworked(veh, timeoutMs)
    if not veh or veh == 0 then return false end
    timeoutMs = timeoutMs or 4000
    local deadline = GetGameTimer() + timeoutMs
    while GetGameTimer() < deadline do
        if not DoesEntityExist(veh) then return false end
        if not NetworkGetEntityIsNetworked(veh) then
            NetworkRegisterEntityAsNetworked(veh)
        else
            local netId = NetworkGetNetworkIdFromEntity(veh)
            if netId and netId ~= 0 then
                -- Let the ID migrate normally under OneSync; do NOT force
                -- ExistsOnAllMachines (that is for script-created persistent
                -- entities and can stall scope updates).
                SetNetworkIdCanMigrate(netId, true)
                return true
            end
        end
        Wait(50)
    end
    return false
end

local function jobsDebug()
    return GetConvar('sv_sunset_jobs_debug', '0') == '1'
end

local function dlog(msg)
    if jobsDebug() then
        print(('[JOBS REG CLIENT] ' .. msg))
    end
end

function JobClient.spawnVehicle(model, spawn, warp)
    local hash = JobClient.loadModel(model)
    if not hash then
        JobClient.notify('Failed to load vehicle model', 'error')
        return nil
    end

    local s = spawn
    local slot = #JobClient.vehicles
    local ox = (slot % 3) * 4.2
    -- [ANTICHEAT] whitelist for the vehspawn ledger detector
    TriggerServerEvent('sunset:anticheat:markLegitLocal', 'vehicle_spawn', 15)
    local veh = CreateVehicle(hash, s.x + ox, s.y, s.z, s.w or 0.0, true, false)
    if veh == 0 then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetVehicleNumberPlateText(veh, 'JOB' .. math.random(100, 999))
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    protectJobVehicle(veh)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetModelAsNoLongerNeeded(hash)

    -- [NETWORK FIX] Do not return the vehicle until it is actually networked
    -- with a stable non-zero net ID.
    if not ensureNetworked(veh) then
        dlog(('spawnVehicle: entity %d never became networked'):format(veh))
    end

    JobClient.vehicles[#JobClient.vehicles + 1] = veh
    if warp then
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        -- [WARP FIX] TaskWarpPedIntoVehicle is async — the ped is NOT
        -- immediately in the seat. Wait until the ped is actually inside
        -- before returning, otherwise registerVehicle fails with
        -- "player is not in the driver seat".
        local warpDeadline = GetGameTimer() + 3000
        while GetPedInVehicle(PlayerPedId(), false) ~= veh and GetGameTimer() < warpDeadline do
            Wait(10)
        end
    end
    return veh
end

function JobClient.attachTrailer(truck, trailerModel, spawn)
    local thash = JobClient.loadModel(trailerModel)
    if not thash then return nil end
    local heading = GetEntityHeading(truck)
    local rearPos = GetOffsetFromEntityInWorldCoords(truck, 0.0, -10.5, 0.5)

    TriggerServerEvent('sunset:anticheat:markLegitLocal', 'vehicle_spawn', 15)
    local trailer = CreateVehicle(thash, rearPos.x, rearPos.y, rearPos.z, heading, true, false)
    if trailer == 0 then return nil end
    SetEntityAsMissionEntity(trailer, true, true)
    SetVehicleHasBeenOwnedByPlayer(trailer, true)
    protectJobVehicle(trailer)

    SetEntityCoordsNoOffset(trailer, rearPos.x, rearPos.y, rearPos.z, false, false, false)
    SetEntityRotation(trailer, 0.0, 0.0, heading, 2, true)
    SetEntityHeading(trailer, heading)
    SetVehicleOnGroundProperly(trailer)
    Wait(200)

    AttachVehicleToTrailer(truck, trailer, 1.1)
    Wait(200)
    if not (IsVehicleAttachedToTrailer(truck) == 1 or IsVehicleAttachedToTrailer(truck) == true) then
        AttachVehicleToTrailer(truck, trailer, 2.5)
    end

    if not ensureNetworked(trailer) then
        dlog(('attachTrailer: entity %d never became networked'):format(trailer))
    end
    JobClient.vehicles[#JobClient.vehicles + 1] = trailer
    SetModelAsNoLongerNeeded(thash)
    return trailer
end

-- [NETWORK FIX] Registration handshake with error taxonomy:
--   RETRYABLE: entity/trailer not propagated yet (server could not resolve)
--   FATAL: everything else (session, driver, model, invalid entity)
-- Bounded total window with small backoff; client-side readiness gate first.
local RETRYABLE_ERRORS = {
    ['Work vehicle not networked'] = true,
    ['Work trailer is not networked'] = true,
    ['You must drive the work vehicle'] = true,
}

function JobClient.registerVehiclesWithServer()
    local truck = JobClient.vehicles[1]
    if not truck or not DoesEntityExist(truck) then return false, 'Work vehicle is missing' end

    -- Client-side readiness: both entities networked with stable IDs before
    -- the first server round-trip.
    if not ensureNetworked(truck) then
        dlog('registration aborted: truck never networked client-side')
        return false, 'Work vehicle did not become server-visible. Check OneSync/entity networking.'
    end
    local trailer = JobClient.vehicles[2]
    if trailer and DoesEntityExist(trailer) then
        if not ensureNetworked(trailer) then
            dlog('registration aborted: trailer never networked client-side')
            return false, 'Work trailer did not become server-visible. Check OneSync/entity networking.'
        end
    end

    local totalDeadline = GetGameTimer() + 8000
    local attempt, delay = 0, 200
    local lastErr = nil
    while GetGameTimer() < totalDeadline do
        attempt = attempt + 1
        if not DoesEntityExist(truck) then
            return false, 'Work vehicle was destroyed'
        end
        local truckNet = NetworkGetNetworkIdFromEntity(truck)
        local tNet = nil
        if trailer and DoesEntityExist(trailer) then
            tNet = NetworkGetNetworkIdFromEntity(trailer)
        end
        if truckNet and truckNet ~= 0 and (not (trailer and DoesEntityExist(trailer)) or (tNet and tNet ~= 0)) then
            local ok, err = Sunset.AwaitCallback('sunset:jobs:registerVehicle', truckNet, tNet)
            if ok then
                dlog(('registered on attempt %d'):format(attempt))
                return true
            end
            lastErr = err
            dlog(('attempt %d rejected: %s'):format(attempt, tostring(err)))
            -- FATAL errors: do not retry.
            if not err or not RETRYABLE_ERRORS[err] then
                return false, err or 'Registration failed unexpectedly. Check F8/server logs.'
            end
        end
        Wait(delay)
        -- Small backoff: 200ms for the first attempts, then 500ms.
        if attempt >= 4 then delay = 500 end
    end
    return false, (lastErr and RETRYABLE_ERRORS[lastErr])
        and 'Work vehicle has not propagated to the server yet. Check OneSync/entity networking.'
        or (lastErr or 'Could not network the work vehicle')
end

function JobClient.playAnim(dict, anim, duration)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration or -1, 1, 0, false, false, false)
    if duration and duration > 0 then
        Wait(duration)
        ClearPedTasks(PlayerPedId())
    end
    return true
end

function JobClient.progress(label, duration)
    exports.sunset_ui:Send('progress', { label = label, duration = duration })
    Wait(duration)
end

function JobClient.respawnTrailer(truck, trailerModel)
    if not truck or not DoesEntityExist(truck) then return nil, 'Truck is missing' end

    local oldTrailer = JobClient.vehicles[2]
    if oldTrailer and DoesEntityExist(oldTrailer) then
        DetachVehicleFromTrailer(truck)
        SetEntityAsMissionEntity(oldTrailer, true, true)
        DeleteVehicle(oldTrailer)
    end
    if #JobClient.vehicles >= 2 then
        table.remove(JobClient.vehicles, 2)
    end

    local offset = GetOffsetFromEntityInWorldCoords(truck, 0.0, -12.0, 0.5)
    local heading = GetEntityHeading(truck)
    local spawn = vector4(offset.x, offset.y, offset.z, heading)
    local trailer = JobClient.attachTrailer(truck, trailerModel, spawn)
    if not trailer then return nil, 'Could not spawn replacement trailer' end

    -- [NETWORK FIX] attachTrailer already ensures the entity is networked;
    -- retry loop only covers server-side propagation delay, with taxonomy:
    -- retryable = not propagated yet, fatal = anything else.
    if not ensureNetworked(trailer) then
        return nil, 'Replacement trailer did not become server-visible. Check OneSync/entity networking.'
    end
    local totalDeadline = GetGameTimer() + 8000
    local delay = 200
    while GetGameTimer() < totalDeadline do
        local tNet = NetworkGetNetworkIdFromEntity(trailer)
        if tNet and tNet ~= 0 then
            local ok, err = Sunset.AwaitCallback('sunset:jobs:registerTrailer', tNet)
            if ok then
                JobClient.trailerLostSent = false
                return trailer
            end
            if err ~= 'Trailer is not networked' then
                return nil, err
            end
        end
        Wait(delay)
        delay = 500
    end
    return nil, 'Work trailer has not propagated to the server yet. Check OneSync/entity networking.'
end

function JobClient.monitorVehicles()
    CreateThread(function()
        while JobClient.state ~= 'IDLE' and #JobClient.vehicles > 0 do
            local truck = JobClient.vehicles[1]
            local trailer = JobClient.vehicles[2]
            local truckAlive = truck and DoesEntityExist(truck)
            local trailerAlive = trailer and DoesEntityExist(trailer)

            if truck and trailer and truckAlive and trailerAlive then
                local isAttached = IsVehicleAttachedToTrailer(truck) == 1 or IsVehicleAttachedToTrailer(truck) == true
                local hasTrailer, attachedEntity = GetVehicleTrailerVehicle(truck)
                local dist = #(GetEntityCoords(truck) - GetEntityCoords(trailer))
                local attachedStatus = isAttached or (hasTrailer and dist <= 22.0) or dist <= 18.0
                TriggerServerEvent('sunset:jobs:syncTrailerStatus', attachedStatus)
            end

            if truckAlive and trailer and not trailerAlive and JobClient.jobId == 'trucker'
                and not JobClient.trailerLostSent then
                JobClient.trailerLostSent = true
                local result = Sunset.AwaitCallback('sunset:jobs:trailerDestroyed')
                if result and result.failed then
                    -- session ended server-side
                elseif result and result.respawn and result.trailerModel then
                    local truckEntity = truck
                    if result.truckNetId then
                        local netTruck = NetworkGetEntityFromNetworkId(result.truckNetId)
                        if netTruck ~= 0 and DoesEntityExist(netTruck) then
                            truckEntity = netTruck
                        end
                    end
                    local cfg = Sunset.GetJobConfig('trucker')
                    local spawned, spawnErr = JobClient.respawnTrailer(truckEntity, result.trailerModel)
                    if spawned then
                        JobClient.notify(('Replacement trailer spawned. %d recoveries remain.'):format(
                            result.remaining or 0), 'success', 7000)
                    elseif spawnErr then
                        JobClient.notify(spawnErr, 'error')
                    end
                else
                    JobClient.trailerLostSent = false
                end
            end

            if not truckAlive and JobClient.state ~= 'IDLE' then
                Sunset.AwaitCallback('sunset:jobs:vehicleLost')
                JobClient.cleanup()
                JobClient.notify('Work vehicle destroyed — shift failed', 'error')
                break
            end
            Wait(2000)
        end
    end)
end

function JobClient.clearWorkHud()
    JobClient.hideObjective()
    exports.sunset_ui:Send('fishingHide', {})
    exports.sunset_ui:Send('jobShiftHide', {})
    exports.sunset_ui:Send('jobSkillHide', {})
end

function JobClient.cleanup(options)
    options = options or {}
    JobClient.deleteVehicles(options.keepTruck == true)
    JobClient.clearBlips()
    JobClient.state = 'IDLE'
    JobClient.jobId = nil
    JobClient.sessionData = nil
    JobClient.threadActive = false
    JobClient.clearWorkHud()
end

function JobClient.getWorkLocation(jobId)
    local cfg = Sunset.GetJobConfig(jobId)
    if not cfg then return nil end
    if cfg.depot and cfg.depot.coords then return cfg.depot.coords end
    if cfg.warehouse and cfg.warehouse.coords then return cfg.warehouse.coords end
    if cfg.spots and cfg.spots[1] and cfg.spots[1].coords then return cfg.spots[1].coords end
    return nil
end

function JobClient.waypointToJob(jobId)
    local coords = JobClient.getWorkLocation(jobId)
    if coords then
        JobClient.setWaypoint(coords)
        return true
    end
    return false
end

function JobClient.setRouteTarget(coords, preset, label, keepDepotBlip)
    if not keepDepotBlip then
        JobClient.clearBlips()
    end
    if coords then
        JobClient.addBlip(coords, preset or { sprite = 1, color = 5 }, label or 'Objective')
        JobClient.setWaypoint(coords)
    end
end

function JobClient.syncSessionState()
    local data = Sunset.AwaitCallback('sunset:jobs:getPanelData')
    if not data then return false end
    if data.session and data.session.jobId then
        JobClient.jobId = data.session.jobId
        JobClient.state = data.session.state or 'ACTIVE'
        JobClient.sessionData = data.session.data
        if data.session.jobId == 'fisherman' then
            JobClient.hideObjective()
            if Sunset.Jobs and Sunset.Jobs.EnsureFishermanShift then
                Sunset.Jobs.EnsureFishermanShift()
            end
        end
        return true
    end
    if JobClient.state ~= 'IDLE' then
        JobClient.cleanup()
    end
    return false
end

function JobClient.getCharacterJob()
    local char = Sunset.Character or {}
    return select(1, Sunset.GetCharacterJob(char))
end

RegisterNetEvent('sunset:jobs:sessionStarted', function(jobId, session)
    JobClient.jobId = jobId
    JobClient.state = session.state or 'STARTING'
    JobClient.sessionData = session.data
    local label = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId
    if jobId == 'fisherman' then
        JobClient.hideObjective()
        if Sunset.Jobs and Sunset.Jobs.EnsureFishermanShift then
            Sunset.Jobs.EnsureFishermanShift()
        end
    else
        JobClient.showObjective(label, 'Shift started — follow GPS markers')
    end
end)

RegisterNetEvent('sunset:jobs:stateChanged', function(state, data)
    JobClient.state = state
    if data then JobClient.sessionData = data end
end)

RegisterNetEvent('sunset:jobs:sessionEnded', function(jobId, state, reason, options)
    JobClient.hideObjective()
    JobClient.cleanup(options or {})
    if state == 'COMPLETED' then
        JobClient.notify('Shift complete!', 'success')
    elseif state == 'FAILED' then
        JobClient.notify(reason or 'Shift failed', 'error')
    elseif state == 'CANCELLED' then
        JobClient.notify(reason or 'Shift cancelled', 'info')
    end
end)

RegisterNetEvent('sunset:jobs:trailerRespawn', function(data)
    if JobClient.jobId ~= 'trucker' or not data or not data.trailerModel then return end
    local truck = JobClient.vehicles[1]
    if data.truckNetId then
        local netTruck = NetworkGetEntityFromNetworkId(data.truckNetId)
        if netTruck ~= 0 and DoesEntityExist(netTruck) then truck = netTruck end
    end
    local spawned, err = JobClient.respawnTrailer(truck, data.trailerModel)
    if spawned then
        JobClient.notify(('Replacement trailer spawned. %d recoveries remain.'):format(
            data.remaining or 0), 'success', 7000)
    elseif err then
        JobClient.notify(err, 'error')
    end
end)

RegisterNetEvent('sunset:jobs:waypointToWork', function(jobId, coords)
    if coords and coords.x then
        JobClient.setWaypoint(coords)
        local label = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId
        JobClient.notify('GPS set to ' .. label .. ' work location', 'info')
    elseif JobClient.waypointToJob(jobId) then
        local label = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId
        JobClient.notify('GPS set to ' .. label .. ' work location', 'info')
    end
end)

RegisterNetEvent('sunset:client:updateCharacter', function(char)
    Sunset.Character = char
end)

RegisterNetEvent('sunset:jobs:forceClearHud', function()
    JobClient.clearWorkHud()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        JobClient.cleanup()
    end
end)

Sunset.JobClient = JobClient
