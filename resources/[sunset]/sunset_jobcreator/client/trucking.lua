JCTrucking = JCTrucking or {
    detachedSince = nil,
    destroySent = false,
    lastAutoAttach = 0,
}

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 3000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return NetworkHasControlOfEntity(entity)
end

function JCTrucking_RespawnTrailer(truck, trailerModel, spawnLoc)
    if not truck or truck == 0 or not DoesEntityExist(truck) then
        return nil, 'Camionul nu există.'
    end
    local hash = type(trailerModel) == 'string' and joaat(trailerModel) or trailerModel
    RequestModel(hash)
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(hash) then return nil, 'Model remorcă invalid.' end

    local coords = GetEntityCoords(truck)
    local heading = GetEntityHeading(truck)
    if spawnLoc and spawnLoc.x then
        coords = vector3(spawnLoc.x, spawnLoc.y, spawnLoc.z)
        heading = spawnLoc.heading or spawnLoc.w or heading
    else
        coords = GetOffsetFromEntityInWorldCoords(truck, 0.0, -12.0, 0.0)
    end

    local trailer = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not trailer or trailer == 0 then return nil, 'Nu s-a putut spawna remorca.' end

    SetEntityAsMissionEntity(trailer, true, true)
    SetVehicleOnGroundProperly(trailer)
    AttachVehicleToTrailer(truck, trailer, 1.0)
    JCEntities.vehicles[#JCEntities.vehicles + 1] = trailer

    local netId = NetworkGetNetworkIdFromEntity(trailer)
    Sunset.AwaitCallback('sunset:jobcreator:registerTrailer', netId)
    return trailer, netId
end

function JCTrucking_TryReattach(truck, trailer)
    if not requestControl(trailer) then return false end
    SetVehicleHandbrake(truck, true)
    SetEntityVelocity(trailer, 0.0, 0.0, 0.0)
    DetachVehicleFromTrailer(truck)
    Wait(100)

    local dist = #(GetEntityCoords(truck) - GetEntityCoords(trailer))
    if dist > 30.0 then
        local target = GetOffsetFromEntityInWorldCoords(truck, 0.0, -10.5, 1.0)
        local heading = GetEntityHeading(truck)
        SetEntityCoordsNoOffset(trailer, target.x, target.y, target.z, false, false, false)
        SetEntityHeading(trailer, heading)
        SetVehicleOnGroundProperly(trailer)
        Wait(200)
    end

    AttachVehicleToTrailer(truck, trailer, 1.0)
    SetVehicleHandbrake(truck, false)
    Wait(150)
    local attached, attachedEntity = GetVehicleTrailerVehicle(truck)
    return attached and attachedEntity == trailer
end

function JCTrucking_Tick(payload, syncHudFn, notifyFn)
    if not payload or not payload.variables then return end
    local vars = payload.variables
    local truckNet, trailerNet = vars.vehicle, vars.trailer
    if not truckNet or not trailerNet then return end

    local truck = NetworkGetEntityFromNetworkId(truckNet)
    if truck == 0 or not DoesEntityExist(truck) then return end

    local trailer = NetworkGetEntityFromNetworkId(trailerNet)
    if trailer == 0 or not DoesEntityExist(trailer) then
        if JCTrucking.destroySent then return end
        JCTrucking.destroySent = true
        return
    end
    JCTrucking.destroySent = false

    local attached, attachedEntity = GetVehicleTrailerVehicle(truck)
    if attached and attachedEntity == trailer then
        JCTrucking.detachedSince = nil
        return
    end

    local cfg = (payload.definition and payload.definition.trucking) or {}
    local maxDist = tonumber(cfg.autoReattachDistance) or 28.0
    local dist = #(GetEntityCoords(truck) - GetEntityCoords(trailer))
    local ped = PlayerPedId()
    local driving = GetPedInVehicleSeat(truck, -1) == ped

    if driving and dist <= maxDist and GetGameTimer() - JCTrucking.lastAutoAttach > 3000 then
        JCTrucking.lastAutoAttach = GetGameTimer()
        if JCTrucking_TryReattach(truck, trailer) then
            notifyFn('Remorcă reatașată automat.', 'success')
            return
        end
    end

    JCTrucking.detachedSince = JCTrucking.detachedSince or GetGameTimer()
    local elapsed = math.floor((GetGameTimer() - JCTrucking.detachedSince) / 1000)
    syncHudFn(payload, {
        state = 'failed',
        message = ('⚠ Remorcă pierdută! Apropie camionul sau /recovertrailer (%ds)'):format(
            math.max(0, (tonumber(cfg.trailerGraceSec) or 90) - elapsed)),
    })
end

function JCTrucking_Reset()
    JCTrucking.detachedSince = nil
    JCTrucking.destroySent = false
    JCTrucking.lastAutoAttach = 0
end

RegisterNetEvent('sunset:jobcreator:trailerRespawn', function(data)
    if not data or not data.trailerModel then return end
    local truck = data.truckNetId and NetworkGetEntityFromNetworkId(data.truckNetId) or 0
    if truck == 0 or not DoesEntityExist(truck) then
        truck = JCEntities_GetJobVehicle({}, 'vehicle')
    end
    local _, err = JCTrucking_RespawnTrailer(truck, data.trailerModel, data.trailerSpawn)
    if err then
        exports.sunset_ui:Notify(err, 'error', 6000)
    else
        exports.sunset_ui:Notify(
            ('Remorcă nouă spawn-ată. Recuperări rămase: %d'):format(data.remaining or 0),
            'success', 7000)
        JCTrucking_Reset()
    end
end)

RegisterNetEvent('sunset:jobcreator:trailerWarn', function(data)
    if not data or not data.seconds then return end
    exports.sunset_ui:Notify(
        ('Reatașează remorca în %d secunde!'):format(data.seconds),
        'warning', 5000)
end)

RegisterNetEvent('sunset:jobcreator:paid', function(data)
    if not data then return end
    local pay = tonumber(data.pay) or 0
    local done = tonumber(data.done) or 0
    local total = tonumber(data.total) or 0
    local xp = tonumber(data.xp) or 0
    local msg = ('Livrare completă! +$%d'):format(pay)
    if xp > 0 then msg = msg .. (' · +%d XP'):format(xp) end
    if total > 0 then msg = msg .. (' · %d/%d'):format(done, total) end
    exports.sunset_ui:Notify(msg, 'success', 7000)
    exports.sunset_ui:Send('chatMessage', {
        id = 0,
        name = 'SYSTEM',
        message = msg,
        time = string.format('%02d:%02d:%02d', GetClockHours(), GetClockMinutes(), GetClockSeconds()),
        type = 'command_info',
    })
end)
