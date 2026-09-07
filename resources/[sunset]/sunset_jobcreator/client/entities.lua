JCEntities = JCEntities or {
    vehicles = {},
    peds = {},
    objects = {},
}

local function loadModel(model)
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

local function vec4From(loc, heading)
    if not loc then return nil end
    local h = heading or loc.heading or loc.w or 0.0
    return vector4(loc.x, loc.y, loc.z, h)
end

function JCEntities_Cleanup()
    for _, veh in ipairs(JCEntities.vehicles) do
        if veh and DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
    end
    for _, ped in ipairs(JCEntities.peds) do
        if ped and DoesEntityExist(ped) then
            DeletePed(ped)
        end
    end
    for _, obj in ipairs(JCEntities.objects) do
        if obj and DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    JCEntities.vehicles = {}
    JCEntities.peds = {}
    JCEntities.objects = {}
end

function JCEntities_SpawnVehicle(stage, variables, definition)
    local model = stage.model or 'phantom'
    local loc = SunsetJobCreator.StageLocation(definition, stage, variables)
    if not loc then return nil, 'No spawn location.' end
    local spawn = vec4From(loc, stage.heading)
    local hash = loadModel(model)
    if not hash then return nil, 'Invalid vehicle model.' end

    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    if not veh or veh == 0 then return nil, 'Could not spawn vehicle.' end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, ('JC%03d'):format(math.random(100, 999)))
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetModelAsNoLongerNeeded(hash)

    if stage.warp then
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    end

    JCEntities.vehicles[#JCEntities.vehicles + 1] = veh
    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdCanMigrate(netId, true)
    return netId
end

function JCEntities_AttachTrailer(stage, variables, definition)
    local vehicleVar = stage.vehicleVar or 'vehicle'
    local netId = variables[vehicleVar]
    local truck = netId and NetworkGetEntityFromNetworkId(netId) or JCEntities.vehicles[1]
    if not truck or truck == 0 or not DoesEntityExist(truck) then
        return nil, 'Job truck not found.'
    end

    local loc = SunsetJobCreator.StageLocation(definition, stage, variables)
    if not loc then return nil, 'No trailer spawn location.' end
    local spawn = vec4From(loc, stage.heading)
    local hash = loadModel(stage.trailerModel or 'trailers2')
    if not hash then return nil, 'Invalid trailer model.' end

    local trailer = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    if not trailer or trailer == 0 then return nil, 'Could not spawn trailer.' end
    SetEntityAsMissionEntity(trailer, true, true)
    SetVehicleOnGroundProperly(trailer)
    AttachVehicleToTrailer(truck, trailer, 1.0)
    SetModelAsNoLongerNeeded(hash)

    JCEntities.vehicles[#JCEntities.vehicles + 1] = trailer
    return NetworkGetNetworkIdFromEntity(trailer)
end

function JCEntities_DeleteVehicles()
    JCEntities_Cleanup()
    return true
end

function JCEntities_SpawnNpc(stage, variables, definition)
    local loc = SunsetJobCreator.StageLocation(definition, stage, variables)
    if not loc then return nil, 'No NPC location.' end
    local hash = loadModel(stage.model or 's_m_m_dockwork_01')
    if not hash then return nil, 'Invalid ped model.' end

    local heading = stage.heading or loc.heading or 0.0
    local ped = CreatePed(4, hash, loc.x, loc.y, loc.z - 1.0, heading, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, stage.invincible ~= false)
    FreezeEntityPosition(ped, stage.frozen ~= false)
    if stage.scenario then
        TaskStartScenarioInPlace(ped, stage.scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(hash)

    JCEntities.peds[#JCEntities.peds + 1] = ped
    return {
        x = loc.x, y = loc.y, z = loc.z,
        radius = tonumber(stage.radius) or 2.5,
        zTolerance = tonumber(loc.zTolerance) or 4.0,
        label = stage.label or loc.label or 'NPC',
        entity = ped,
    }
end

function JCEntities_RemoveNpc(variables, npcVar)
    npcVar = npcVar or 'npc'
    local data = variables[npcVar]
    if data and data.entity and DoesEntityExist(data.entity) then
        DeletePed(data.entity)
    end
    for i, ped in ipairs(JCEntities.peds) do
        if not DoesEntityExist(ped) then
            table.remove(JCEntities.peds, i)
        end
    end
    return true
end

function JCEntities_GetJobVehicle(variables, vehicleVar)
    vehicleVar = vehicleVar or 'vehicle'
    local netId = variables[vehicleVar]
    if netId then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    end
    return JCEntities.vehicles[1]
end

function JCEntities_IsInJobVehicle(variables, vehicleVar)
    local veh = JCEntities_GetJobVehicle(variables, vehicleVar)
    if not veh then return false end
    return GetVehiclePedIsIn(PlayerPedId(), false) == veh
end

RegisterNetEvent('sunset:jobcreator:cleanupEntities', function()
    JCEntities_Cleanup()
end)
