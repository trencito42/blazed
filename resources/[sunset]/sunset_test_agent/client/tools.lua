-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (client/tools.lua)
--  Client-side RPC handlers. IMPORTANT DISTINCTION (kept honest):
--
--  * REAL runtime effects: teleport, setHeading, vitals, vehicle ops,
--    entity scans, screenshots — these run actual natives on the client.
--
--  * press_control / hold_control: FiveM's scripting runtime provides NO
--    native to inject physical control presses (no SetControlNormal).
--    These handlers are implemented as SEMANTIC actions where a mapping
--    exists and return OPERATION_NOT_ALLOWED otherwise — they never
--    pretend to be physical key presses. See docs/testing/FIVEM_MCP.md.
--
--  * invoke_callback: documented BYPASS — calls an allowlisted
--    sunset_core callback directly, skipping world interaction.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

local function err(code, message, retryable)
    return { code = code, message = message, retryable = retryable == true }
end

-- ── ping ──
ClientRpc.register('ping', function()
    return { pong = true, resource = GetCurrentResourceName(), gameTimer = GetGameTimer() }
end)

-- ── teleport / heading / vitals (REAL effects) ──
ClientRpc.register('teleport', function(payload)
    local ped = PlayerPedId()
    local x, y, z = tonumber(payload.x), tonumber(payload.y), tonumber(payload.z)
    if not x or not y or not z then return nil end
    -- Request collision so we do not fall through the world.
    RequestCollisionAtCoord(x, y, z)
    local deadline = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(25) end
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    if tonumber(payload.heading) then
        SetEntityHeading(ped, tonumber(payload.heading))
    end
    SetGameplayCamRelativeHeading(0.0)
    ClientLog.action('teleport', { x = x, y = y, z = z })
    return { x = x, y = y, z = z, heading = GetEntityHeading(ped) }
end)

ClientRpc.register('setHeading', function(payload)
    local heading = tonumber(payload.heading)
    if not heading then return nil end
    SetEntityHeading(PlayerPedId(), heading)
    return { heading = GetEntityHeading(PlayerPedId()) }
end)

ClientRpc.register('setVitals', function(payload)
    local ped = PlayerPedId()
    local health = math.floor(tonumber(payload.health) or 0)
    local armour = math.floor(tonumber(payload.armour) or 0)
    SetEntityHealth(ped, math.max(0, math.min(1000, health)))
    SetPedArmour(ped, math.max(0, math.min(100, armour)))
    return { health = GetEntityHealth(ped), armour = GetPedArmour(ped) }
end)

-- ── vehicle state / control ──
ClientRpc.register('vehicleState', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return { inVehicle = false } end
    return {
        inVehicle = true,
        netId = NetworkGetNetworkIdFromEntity(veh),
        model = GetEntityModel(veh),
        isDriver = GetPedInVehicleSeat(veh, -1) == ped,
        coords = (function()
            local c = GetEntityCoords(veh)
            return { x = c.x, y = c.y, z = c.z }
        end)(),
        heading = GetEntityHeading(veh),
        engineRunning = GetIsVehicleEngineRunning(veh),
        speed = GetEntitySpeed(veh),
        fuelLevel = GetVehicleFuelLevel(veh),
        bodyHealth = GetVehicleBodyHealth(veh),
        plate = GetVehicleNumberPlateText(veh),
        networked = NetworkGetEntityIsNetworked(veh),
    }
end)

ClientRpc.register('enterVehicle', function(payload)
    local netId = tonumber(payload.netId)
    if not netId then return nil end
    local veh = NetToVeh(netId)
    if veh == 0 or not DoesEntityExist(veh) then
        return nil, err('ENTITY_NOT_FOUND', 'vehicle not found')
    end
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, payload.driver ~= false and -1 or 0)
    return { entered = true, isDriver = GetPedInVehicleSeat(veh, -1) == PlayerPedId() }
end)

ClientRpc.register('exitVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return { exited = false, reason = 'not in vehicle' } end
    TaskLeaveVehicle(ped, veh, 0)
    return { exited = true }
end)

-- ── world scans ──
local function describeEntity(ent)
    local c = GetEntityCoords(ent)
    local model = GetEntityModel(ent)
    return {
        entity = ent,
        netId = NetworkGetNetworkIdFromEntity(ent),
        model = model,
        type = GetEntityType(ent),   -- 1 ped, 2 vehicle, 3 object
        coords = { x = c.x, y = c.y, z = c.z },
        heading = GetEntityHeading(ent),
        collisionEnabled = not GetEntityCollisionDisabled(ent),
        frozen = IsEntityPositionFrozen(ent),
        visible = IsEntityVisible(ent),
        networked = NetworkGetEntityIsNetworked(ent),
        stateBagKeys = (function()
            local out = {}
            local bag = Entity(ent).state
            for _, key in ipairs({ Cfg.testEntityStateKey, 'sunsetProtectedVehicle' }) do
                if bag[key] ~= nil then out[key] = bag[key] end
            end
            return out
        end)(),
    }
end

ClientRpc.register('nearbyEntities', function(payload)
    local radius = math.min(tonumber(payload.radius) or 25.0, Cfg.maxNearbyRadius)
    local kind = tostring(payload.kind or 'all')
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local out = {}
    local pools = {}
    if kind == 'all' or kind == 'objects' then pools[#pools + 1] = 'CObject' end
    if kind == 'all' or kind == 'vehicles' then pools[#pools + 1] = 'CVehicle' end
    if kind == 'all' or kind == 'peds' then pools[#pools + 1] = 'CPed' end
    for _, poolName in ipairs(pools) do
        for _, ent in ipairs(GetGamePool(poolName) or {}) do
            if ent ~= ped and #out < Cfg.maxNearbyEntities then
                local okC, ec = pcall(GetEntityCoords, ent)
                if okC and ec and #(ec - pos) <= radius then
                    local d = describeEntity(ent)
                    d.distance = #(ec - pos)
                    out[#out + 1] = d
                end
            end
        end
    end
    table.sort(out, function(a, b) return (a.distance or 0) < (b.distance or 0) end)
    return { entities = out, count = #out, radius = radius, kind = kind }
end)

ClientRpc.register('inspectEntity', function(payload)
    local netId = tonumber(payload.netId)
    if not netId then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) then
        -- Also try direct handle (payload may carry a local handle for map props)
        ent = tonumber(payload.netId) or 0
        if ent == 0 or not DoesEntityExist(ent) then
            return nil, err('ENTITY_NOT_FOUND', ('entity for netId %d not found'):format(netId))
        end
    end
    local info = describeEntity(ent)
    -- Extra useful fields for door/vault debugging
    info.doorHeading = GetEntityHeading(ent)
    info.attachedTo = GetEntityAttachedTo(ent)
    info.health = GetEntityHealth(ent)
    info.modelNameHint = tostring(payload.modelHint or '')
    info.hashMatchesHint = payload.modelHint ~= '' and GetEntityModel(ent) == GetHashKey(tostring(payload.modelHint))
    local pc = GetEntityCoords(PlayerPedId())
    info.distanceFromPlayer = #(GetEntityCoords(ent) - pc)
    return info
end)

-- Find the closest object of a model name (helper for vault/door debugging).
ClientRpc.register('findObjectByModel', function(payload)
    local name = tostring(payload.name or '')
    if name == '' then return nil end
    local hash = GetHashKey(name)
    local c = payload.coords and vector3(tonumber(payload.coords.x) or 0, tonumber(payload.coords.y) or 0, tonumber(payload.coords.z) or 0)
        or GetEntityCoords(PlayerPedId())
    local radius = tonumber(payload.radius) or 10.0
    local obj = GetClosestObjectOfType(c.x, c.y, c.z, radius, hash, false, false, false)
    if obj == 0 or not DoesEntityExist(obj) then
        return { found = false, model = name, hash = hash, near = { x = c.x, y = c.y, z = c.z } }
    end
    local info = describeEntity(obj)
    info.found = true
    info.model = name
    return info
end)

-- ── test vehicle spawn/delete (tagged) ──
ClientRpc.register('spawnTestVehicle', function(payload)
    local model = tostring(payload.model or '')
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        return nil, err('INVALID_ARGUMENT', 'model not in cdimage: ' .. model)
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(25) end
    if not HasModelLoaded(hash) then
        return nil, err('TIMEOUT', 'model load timeout: ' .. model)
    end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerServerEvent('sunset:anticheat:markLegitLocal', 'vehicle_spawn', 15)
    local veh = CreateVehicle(hash, pos.x + 2.0, pos.y, pos.z, heading, true, false)
    SetModelAsNoLongerNeeded(hash)
    if veh == 0 then
        return nil, err('INTERNAL', 'CreateVehicle returned 0')
    end
    -- TAG as test-spawned so deletion is policy-checked.
    Entity(veh).state:set(Cfg.testEntityStateKey, true, true)
    SetEntityAsMissionEntity(veh, true, true)
    if payload.warp == true then
        TaskWarpPedIntoVehicle(ped, veh, -1)
    end
    ClientLog.action('spawnTestVehicle', { model = model, netId = NetworkGetNetworkIdFromEntity(veh) })
    return {
        netId = NetworkGetNetworkIdFromEntity(veh),
        entity = veh,
        model = model,
        hash = hash,
        networked = NetworkGetEntityIsNetworked(veh),
    }
end)

ClientRpc.register('deleteTestEntity', function(payload)
    local netId = tonumber(payload.netId)
    if not netId then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) then
        return nil, err('ENTITY_NOT_FOUND', 'entity not found')
    end
    -- POLICY: only entities tagged as test-spawned may be deleted.
    if Entity(ent).state[Cfg.testEntityStateKey] ~= true then
        return nil, err('OPERATION_NOT_ALLOWED',
            'entity is not tagged as test-spawned; refusing to delete production entities')
    end
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
    ClientLog.action('deleteTestEntity', { netId = netId })
    return { deleted = true }
end)

-- ── input / interaction (SEMANTIC — see header comment) ──
ClientRpc.register('pressControl', function(payload)
    -- Honest limitation: FiveM exposes no native to inject a physical control
    -- press. We do NOT fake IsControlJustPressed results for other resources.
    return nil, err('OPERATION_NOT_ALLOWED',
        'Physical control injection is not supported by the FiveM scripting runtime. ' ..
        'Use invoke_callback (semantic bypass) or interact_near_marker instead.')
end)

ClientRpc.register('holdControl', function()
    return nil, err('OPERATION_NOT_ALLOWED',
        'Physical control injection is not supported; use invoke_callback for semantic actions.')
end)

-- Semantic: fires the E-context for the closest known interaction by
-- triggering the same server event the marker would (documented bypass).
ClientRpc.register('interactNearMarker', function(payload)
    local eventName = tostring(payload.event or '')
    local allowed = {
        ['sunset:robbery:tryStart'] = true,
        ['sunset:robbery:hackOpen'] = true,
    }
    if not allowed[eventName] then
        return nil, err('OPERATION_NOT_ALLOWED', 'event not on the semantic-interact allowlist: ' .. eventName)
    end
    TriggerServerEvent(eventName, payload.arg)
    ClientLog.action('interactNearMarker (bypass)', { event = eventName })
    return { fired = eventName, bypass = true }
end)

ClientRpc.register('invokeCallback', function(payload)
    local name = tostring(payload.name or '')
    local args = type(payload.args) == 'table' and payload.args or {}
    -- The server already allowlisted the name; re-check locally as defense
    -- in depth (a spoofed server event cannot invoke arbitrary callbacks
    -- because the RPC event is only sent by our own server resource... but
    -- net events CAN be spoofed by a malicious server admin tool, so keep
    -- the client allowlist authoritative for what THIS client will run).
    local CLIENT_ALLOWED = {
        ['sunset:racing:status'] = true,
        ['sunset:drugs:status'] = true,
        ['sunset:events:status'] = true,
        ['sunset:jobs:status'] = true,
        ['sunset:getInventory'] = true,
        ['sunset:robbery:doorSync'] = true,
        ['sunset:marriage:status'] = true,
        ['sunset:impound:status'] = true,
        ['sunset:racing:leave'] = true,
        ['sunset:drugs:cancelAction'] = true,
    }
    if not CLIENT_ALLOWED[name] then
        return nil, err('OPERATION_NOT_ALLOWED', 'callback not on client allowlist: ' .. name)
    end
    local result, cbErr = Sunset.AwaitCallback(name, table.unpack(args))
    ClientLog.action('invokeCallback', { name = name, ok = result ~= nil })
    return { name = name, result = result, error = cbErr }
end)

-- ── client logs ──
ClientRpc.register('clientLogs', function(payload)
    return { logs = ClientLog.tail(tonumber(payload.limit) or 200) }
end)

ClientRpc.register('clearClientLogs', function()
    ClientLog.clear()
    return { cleared = true }
end)

-- ── NUI state (normalized via NuiDebug — instrumentation with fallback) ──
ClientRpc.register('nuiState', function()
    return NuiDebug.state()
end)

ClientRpc.register('nuiHistory', function(payload)
    return { history = NuiDebug.history(tonumber(payload.limit) or 40) }
end)

ClientRpc.register('nuiErrors', function(payload)
    return { errors = NuiDebug.errors(tonumber(payload.limit) or 40) }
end)

-- ── screenshot (screenshot-basic requestScreenshot -> base64 -> JSON upload) ──
-- [TOKEN HYGIENE] The master bearer token is NEVER sent to the game client.
-- The upload route authenticates with the server-issued ONE-SHOT requestId
-- (capability model: player-bound, single-use, 30s TTL). We capture base64
-- via screenshot-basic and POST it as JSON.
ClientRpc.register('screenshot', function(payload)
    if GetResourceState('screenshot_basic') ~= 'started' then
        return nil, err('SCREENSHOT_FAILED', 'screenshot_basic resource not started')
    end
    local requestId = tostring(payload.requestId or '')
    if requestId == '' then
        return nil, err('INVALID_ARGUMENT', 'screenshot payload missing requestId')
    end
    local endpoint = GetCurrentServerEndpoint()   -- host:port of THIS server
    -- FXServer routes HTTP per-resource: /<resource><path>.
    local uploadUrl = ('http://%s/sunset_test_agent/testagent/screenshot'):format(endpoint)

    -- Step 1: capture (base64 string)
    local capture = promise.new()
    local okCall = pcall(function()
        exports['screenshot_basic']:requestScreenshot(function(data)
            capture:resolve(data)
        end, { encoding = 'jpg', quality = 0.85 })
    end)
    if not okCall then
        return nil, err('SCREENSHOT_FAILED', 'screenshot-basic export call failed')
    end
    local data = Citizen.Await(capture)
    if type(data) ~= 'string' or #data < 64 then
        return nil, err('SCREENSHOT_FAILED', 'capture returned no image data')
    end

    -- Step 2: upload as JSON; the one-shot requestId is the only credential.
    local uploaded = promise.new()
    PerformHttpRequest(uploadUrl, function(statusCode, body)
        uploaded:resolve({ status = statusCode, body = tostring(body or ''):sub(1, 200) })
    end, 'POST', json.encode({ requestId = requestId, base64 = data, mime = 'image/jpeg' }), {
        ['Content-Type'] = 'application/json',
    })
    local upRes = Citizen.Await(uploaded)
    if not upRes or upRes.status ~= 200 then
        return nil, err('SCREENSHOT_FAILED',
            ('upload failed status=%s body=%s'):format(tostring(upRes and upRes.status), tostring(upRes and upRes.body)))
    end
    ClientLog.action('screenshot uploaded', { requestId = requestId, base64Length = #data })
    return { uploaded = true, requestId = requestId, mime = 'image/jpeg', bytes = math.floor(#data * 3 / 4) }
end)
