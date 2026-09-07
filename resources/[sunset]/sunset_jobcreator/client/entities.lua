JCEntities = JCEntities or {
    vehicles = {},
    peds = {},
    objects = {},
    propByVar = {},
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
    JCEntities.propByVar = {}
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

function JCEntities_SpawnProp(stage, variables, definition)
    local loc = SunsetJobCreator.StageLocation(definition, stage, variables)
    if not loc then return nil, 'No prop location.' end
    local model = stage.model or 'prop_tree_pine_02'
    local hash = loadModel(model)
    if not hash then return nil, 'Invalid prop model.' end

    local x, y, z = loc.x, loc.y, loc.z
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
    if found then z = groundZ end

    local heading = stage.heading or loc.heading or math.random(0, 359) + 0.0
    local obj = CreateObject(hash, x, y, z - 0.15, true, true, false)
    if not obj or obj == 0 then return nil, 'Could not spawn prop.' end

    SetEntityAsMissionEntity(obj, true, true)
    PlaceObjectOnGroundProperly(obj)
    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)

    JCEntities.objects[#JCEntities.objects + 1] = obj
    local storeKey = stage.storeAs or stage.propVar or 'prop'
    JCEntities.propByVar[storeKey] = obj
    return {
        x = x, y = y, z = z,
        radius = tonumber(stage.radius) or tonumber(loc.radius) or 3.0,
        zTolerance = tonumber(loc.zTolerance) or 4.0,
        label = stage.label or loc.label or 'Target',
        entity = obj,
        model = model,
        poolKey = loc.poolKey,
    }
end

function JCEntities_RemoveProp(variables, propVar)
    propVar = propVar or 'prop'
    local ent = JCEntities.propByVar[propVar]
    if ent and DoesEntityExist(ent) then
        DeleteObject(ent)
    end
    local data = variables and variables[propVar]
    if data and data.entity and DoesEntityExist(data.entity) then
        DeleteObject(data.entity)
    end
    JCEntities.propByVar[propVar] = nil
    for i = #JCEntities.objects, 1, -1 do
        local obj = JCEntities.objects[i]
        if not DoesEntityExist(obj) then
            table.remove(JCEntities.objects, i)
        end
    end
    return true
end

function JCEntities_PlayChopAnim(swings, durationMs)
    local ped = PlayerPedId()
    local axeHash = loadModel('prop_tool_fireaxe')
    local axe = nil
    if axeHash then
        local coords = GetEntityCoords(ped)
        axe = CreateObject(axeHash, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(axe, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.02, 0.0, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(axeHash)
    end

    local dict = 'melee@hatchet@streamed_core'
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(10) end

    local count = math.max(1, tonumber(swings) or 4)
    local perSwing = math.max(800, math.floor((tonumber(durationMs) or 5000) / count))
    for _ = 1, count do
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, 'plyr_rear_takedown_b', 8.0, -8.0, perSwing, 0, 0, false, false, false)
        end
        Wait(perSwing)
    end
    ClearPedTasks(ped)
    if axe and DoesEntityExist(axe) then DeleteObject(axe) end
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
