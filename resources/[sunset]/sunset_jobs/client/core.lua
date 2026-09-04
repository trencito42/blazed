local JobClient = {
    state = 'IDLE',
    jobId = nil,
    sessionData = nil,
    vehicles = {},
    blips = {},
    threadActive = false,
}

function JobClient.notify(msg, typ, duration)
    exports.sunset_ui:Notify(msg, typ or 'info', duration)
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

function JobClient.deleteVehicles()
    for _, veh in ipairs(JobClient.vehicles) do
        if veh and DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
    end
    JobClient.vehicles = {}
end

function JobClient.spawnVehicle(model, spawn, warp)
    local hash = JobClient.loadModel(model)
    if not hash then
        JobClient.notify('Failed to load vehicle model', 'error')
        return nil
    end

    local s = spawn
    local veh = CreateVehicle(hash, s.x, s.y, s.z, s.w or 0.0, true, false)
    if veh == 0 then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetVehicleNumberPlateText(veh, 'JOB' .. math.random(100, 999))
    SetEntityAsMissionEntity(veh, true, true)
    Entity(veh).state:set('sunsetProtectedVehicle', true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetModelAsNoLongerNeeded(hash)

    JobClient.vehicles[#JobClient.vehicles + 1] = veh
    if warp then TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) end
    return veh
end

function JobClient.attachTrailer(truck, trailerModel, spawn)
    local thash = JobClient.loadModel(trailerModel)
    if not thash then return nil end
    local s = spawn
    local trailer = CreateVehicle(thash, s.x, s.y, s.z, s.w or 0.0, true, false)
    if trailer == 0 then return nil end
    SetEntityAsMissionEntity(trailer, true, true)
    Entity(trailer).state:set('sunsetProtectedVehicle', true, true)
    SetVehicleHasBeenOwnedByPlayer(trailer, true)
    AttachVehicleToTrailer(truck, trailer, 1.0)
    Entity(truck).state:set('sunsetTrailerAttached', true, true)
    Entity(truck).state:set('sunsetTrailerNetId', NetworkGetNetworkIdFromEntity(trailer), true)
    JobClient.vehicles[#JobClient.vehicles + 1] = trailer
    SetModelAsNoLongerNeeded(thash)
    return trailer
end

function JobClient.registerVehiclesWithServer()
    local truck = JobClient.vehicles[1]
    if not truck or not DoesEntityExist(truck) then return false, 'Work vehicle is missing' end
    local trailer = JobClient.vehicles[2]
    local tNet = trailer and DoesEntityExist(trailer) and NetworkGetNetworkIdFromEntity(trailer) or nil
    for _ = 1, 8 do
        local truckNet = NetworkGetNetworkIdFromEntity(truck)
        tNet = trailer and DoesEntityExist(trailer) and NetworkGetNetworkIdFromEntity(trailer) or nil
        if truckNet and truckNet ~= 0 and (not trailer or (tNet and tNet ~= 0)) then
            local ok, err = Sunset.AwaitCallback('sunset:jobs:registerVehicle', truckNet, tNet)
            if ok then return true end
            if err and err ~= 'Work vehicle not networked' and err ~= 'Work trailer is not networked' then
                return false, err
            end
        end
        Wait(400)
    end
    return false, 'Could not network the work vehicle'
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

function JobClient.monitorVehicles()
    CreateThread(function()
        while JobClient.state ~= 'IDLE' and #JobClient.vehicles > 0 do
            local anyAlive = false
            for _, veh in ipairs(JobClient.vehicles) do
                if veh and DoesEntityExist(veh) then anyAlive = true break end
            end
            local truck = JobClient.vehicles[1]
            local trailer = JobClient.vehicles[2]
            if truck and trailer and DoesEntityExist(truck) and DoesEntityExist(trailer) then
                local attached, attachedEntity = GetVehicleTrailerVehicle(truck)
                Entity(truck).state:set('sunsetTrailerAttached', attached and attachedEntity == trailer, true)
                Entity(truck).state:set('sunsetTrailerNetId', NetworkGetNetworkIdFromEntity(trailer), true)
            end
            if not anyAlive and JobClient.state ~= 'IDLE' then
                Sunset.AwaitCallback('sunset:jobs:vehicleLost')
                JobClient.cleanup()
                JobClient.notify('Work vehicle destroyed — shift failed', 'error')
                break
            end
            Wait(2000)
        end
    end)
end

function JobClient.cleanup()
    JobClient.deleteVehicles()
    JobClient.clearBlips()
    JobClient.state = 'IDLE'
    JobClient.jobId = nil
    JobClient.sessionData = nil
    JobClient.threadActive = false
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
    JobClient.showObjective(label, 'Shift started — follow GPS markers')
end)

RegisterNetEvent('sunset:jobs:stateChanged', function(state, data)
    JobClient.state = state
    if data then JobClient.sessionData = data end
end)

RegisterNetEvent('sunset:jobs:sessionEnded', function(jobId, state, reason)
    JobClient.hideObjective()
    JobClient.cleanup()
    if state == 'COMPLETED' then
        JobClient.notify('Shift complete!', 'success')
    elseif state == 'FAILED' then
        JobClient.notify(reason or 'Shift failed', 'error')
    elseif state == 'CANCELLED' then
        JobClient.notify(reason or 'Shift cancelled', 'info')
    end
end)

RegisterNetEvent('sunset:jobs:waypointToWork', function(jobId)
    if JobClient.waypointToJob(jobId) then
        local label = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId
        JobClient.notify('GPS set to ' .. label .. ' work location', 'info')
    end
end)

RegisterNetEvent('sunset:client:updateCharacter', function(char)
    Sunset.Character = char
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        JobClient.cleanup()
    end
end)

Sunset.JobClient = JobClient
