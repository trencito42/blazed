-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (server/tools.lua)
--  Allowlisted tool registry. Every tool is an explicit function —
--  there is NO eval/executeLua/arbitrary-event primitive anywhere.
--  Tools return: result  OR  nil, errorTable{code,message,retryable}.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config
local E = SunsetTestAgent.Errors
local Tools = {}

local function invalid(msg)
    return { code = 'INVALID_ARGUMENT', message = msg or E.INVALID_ARGUMENT.message, retryable = false }
end

local function notAllowed(msg)
    return { code = 'OPERATION_NOT_ALLOWED', message = msg or E.OPERATION_NOT_ALLOWED.message, retryable = false }
end

-- ═══ HEALTH / PLAYERS ═══

function Tools.health()
    local testSrc = TestAgentAuth.testPlayer()
    local clientReady = false
    if testSrc then
        local ok, res = RpcClient.await(testSrc, 'ping', {}, 3000)
        clientReady = ok and type(res) == 'table' and res.pong == true
    end
    return {
        bridge = 'ok',
        fxserver = 'ok',
        testAgentResource = GetResourceState('sunset_test_agent'),
        testPlayer = {
            connected = testSrc ~= nil,
            serverId = testSrc,
            clientReady = clientReady,
        },
        sunsetCore = GetResourceState('sunset_core'),
        sunsetUi = GetResourceState('sunset_ui'),
        screenshot = GetResourceState('screenshot_basic') == 'started' and 'available' or 'missing',
        players = #GetPlayers(),
        serverTime = os.date('%Y-%m-%dT%H:%M:%S'),
    }
end

function Tools.get_players()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local char = exports.sunset_core:GetCharacter(src)
        out[#out + 1] = {
            serverId = src,
            name = GetPlayerName(src) or '',
            characterId = char and tonumber(char.id) or nil,
            characterName = char and ((char.firstName or '') .. ' ' .. (char.lastName or '')):gsub('%s+$', '') or nil,
            isTestPlayer = src == TestAgentAuth.testPlayer(),
        }
    end
    return out
end

-- ═══ PLAYER STATE (reads go through domain owners) ═══

function Tools.get_player_state(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, E.ENTITY_NOT_FOUND end
    local coords = GetEntityCoords(ped)
    local char = exports.sunset_core:GetCharacter(src)
    return {
        serverId = src,
        name = GetPlayerName(src) or '',
        ping = GetPlayerPing(src),
        health = GetEntityHealth(ped),
        armour = GetPedArmour(ped),
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = GetEntityHeading(ped),
        interior = GetInteriorFromEntity(ped),
        inVehicle = GetVehiclePedIsIn(ped, false) ~= 0,
        vehicleNetId = (function()
            local v = GetVehiclePedIsIn(ped, false)
            return v ~= 0 and NetworkGetNetworkIdFromEntity(v) or nil
        end)(),
        isDriver = (function()
            local v = GetVehiclePedIsIn(ped, false)
            return v ~= 0 and GetPedInVehicleSeat(v, -1) == ped
        end)(),
        character = char and {
            id = tonumber(char.id),
            firstName = char.firstName,
            lastName = char.lastName,
        } or nil,
        money = (function()
            if not char then return nil end
            local ok, res = pcall(function()
                return {
                    cash = exports.sunset_core:GetMoney(src, 'cash'),
                    bank = exports.sunset_core:GetMoney(src, 'bank'),
                }
            end)
            return ok and res or nil
        end)(),
        adminLevel = TestAgentAuth.adminLevel(src),
    }
end

function Tools.get_player_coords(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, E.ENTITY_NOT_FOUND end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }
end

function Tools.teleport_player(target, args)
    args = type(args) == 'table' and args or {}
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z then return nil, invalid('x, y, z are required numbers') end
    if math.abs(x) > 12000 or math.abs(y) > 12000 or math.abs(z) > 2000 then
        return nil, invalid('coordinates out of world bounds')
    end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok = RpcClient.await(src, 'teleport', { x = x, y = y, z = z, heading = tonumber(args.heading) })
    if not ok then return nil, err end
    return { teleported = true, x = x, y = y, z = z, heading = tonumber(args.heading) }
end

function Tools.set_player_heading(target, args)
    args = type(args) == 'table' and args or {}
    local heading = tonumber(args.heading)
    if not heading then return nil, invalid('heading is required') end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok = RpcClient.await(src, 'setHeading', { heading = heading })
    if not ok then return nil, err end
    return { heading = heading }
end

function Tools.get_player_health(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, E.ENTITY_NOT_FOUND end
    return { health = GetEntityHealth(ped), armour = GetPedArmour(ped), isDead = IsEntityDead(ped) }
end

function Tools.set_test_health(target, args)
    args = type(args) == 'table' and args or {}
    local health = math.floor(tonumber(args.health) or 0)
    local armour = math.floor(tonumber(args.armour) or 0)
    if health < 0 or health > 1000 or armour < 0 or armour > 100 then
        return nil, invalid('health 0-1000, armour 0-100')
    end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok = RpcClient.await(src, 'setVitals', { health = health, armour = armour })
    if not ok then return nil, err end
    return { health = health, armour = armour }
end

function Tools.get_player_vehicle(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'vehicleState', {})
    if not ok then return nil, res end
    return res
end

function Tools.get_player_inventory(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    if GetResourceState('sunset_inventory') ~= 'started' then
        return nil, { code = 'RESOURCE_NOT_STARTED', message = 'sunset_inventory is not started', retryable = true }
    end
    local ok, inv = pcall(function() return exports.sunset_inventory:GetInventory(src) end)
    if not ok then return nil, E.INTERNAL end
    local out = {}
    for _, row in ipairs(inv or {}) do
        out[#out + 1] = { slot = row.slot, item = row.item, count = row.count, metadata = row.metadata }
    end
    return { items = out, count = #out }
end

function Tools.get_player_money(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = pcall(function()
        return {
            cash = exports.sunset_core:GetMoney(src, 'cash'),
            bank = exports.sunset_core:GetMoney(src, 'bank'),
        }
    end)
    if not ok then return nil, E.INTERNAL end
    return res
end

function Tools.get_player_job(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local char = exports.sunset_core:GetCharacter(src)
    if not char then return nil, E.TEST_PLAYER_NOT_CONNECTED end
    local job = select(1, Sunset.GetCharacterJob(char))
    return { jobId = job }
end

function Tools.get_player_faction(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local char = exports.sunset_core:GetCharacter(src)
    if not char then return nil, E.TEST_PLAYER_NOT_CONNECTED end
    local factionId, grade = Sunset.GetCharacterFaction(char)
    local onDuty = nil
    if GetResourceState('sunset_factions') == 'started' then
        pcall(function() onDuty = exports.sunset_factions:IsOnDuty(src) == true end)
    end
    return { factionId = factionId, grade = grade, onDuty = onDuty }
end

function Tools.get_player_wanted(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    if GetResourceState('sunset_factions') ~= 'started' then
        return nil, { code = 'RESOURCE_NOT_STARTED', message = 'sunset_factions not started', retryable = true }
    end
    local ok, wanted = pcall(function() return exports.sunset_factions:GetWantedState(src) end)
    if not ok then return nil, E.INTERNAL end
    return { wanted = type(wanted) == 'table' and wanted or { level = 0 } }
end

function Tools.get_player_jail_state(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    if GetResourceState('sunset_factions') ~= 'started' then
        return nil, { code = 'RESOURCE_NOT_STARTED', message = 'sunset_factions not started', retryable = true }
    end
    local ok, jailed = pcall(function() return exports.sunset_factions:IsJailed(src) end)
    if not ok then return nil, E.INTERNAL end
    return { jailed = jailed == true }
end

function Tools.get_player_session_state(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    -- Job session via sunset_jobs read-only export (domain owner stays authoritative).
    local jobSession = nil
    if GetResourceState('sunset_jobs') == 'started' then
        local ok, res = pcall(function() return exports.sunset_jobs:GetSessionSnapshot(src) end)
        if ok and type(res) == 'table' then jobSession = res end
    end
    local raceNightActive = nil
    if GetResourceState('sunset_racing') == 'started' then
        pcall(function() raceNightActive = exports.sunset_racing:IsRaceNightActive() == true end)
    end
    return {
        jobSession = jobSession,
        raceNightActive = raceNightActive,
        frameworkSessions = (function()
            if GetResourceState('sunset_sessions') ~= 'started' then return nil end
            local ok2, list = pcall(function()
                return exports.sunset_sessions.ListSessions(exports.sunset_sessions)
            end)
            if not ok2 or type(list) ~= 'table' then return nil end
            local mine = {}
            for _, s in ipairs(list) do
                if tonumber(s.source) == src then mine[#mine + 1] = { id = s.id, activity = s.activity, state = s.state } end
            end
            return mine
        end)(),
    }
end

-- ═══ WORLD / ENTITY INSPECTION (client-side scans via RPC) ═══

function Tools.get_nearby_entities(target, args)
    args = type(args) == 'table' and args or {}
    local radius = math.min(tonumber(args.radius) or 25.0, Cfg.maxNearbyRadius)
    local kind = tostring(args.kind or 'all')
    if kind ~= 'all' and kind ~= 'objects' and kind ~= 'vehicles' and kind ~= 'peds' then
        return nil, invalid("kind must be all|objects|vehicles|peds")
    end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'nearbyEntities', { radius = radius, kind = kind })
    if not ok then return nil, res end
    return res
end

function Tools.get_nearby_objects(target, args)
    args = type(args) == 'table' and args or {}
    args.kind = 'objects'
    return Tools.get_nearby_entities(target, args)
end

function Tools.get_nearby_vehicles(target, args)
    args = type(args) == 'table' and args or {}
    args.kind = 'vehicles'
    return Tools.get_nearby_entities(target, args)
end

function Tools.inspect_entity(target, args)
    args = type(args) == 'table' and args or {}
    local netId = tonumber(args.netId)
    if not netId then return nil, invalid('netId is required') end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'inspectEntity', { netId = netId, modelHint = args.modelName })
    if not ok then return nil, res end
    return res
end

-- Model-hash lookup helper (forward hashing only).
function Tools.hash_model(args)
    args = type(args) == 'table' and args or {}
    local name = tostring(args.name or '')
    if name == '' then return nil, invalid('name is required') end
    return { name = name, hash = GetHashKey(name) }
end

-- Find closest object of a model name near coords (client-side scan).
function Tools.find_object(target, args)
    args = type(args) == 'table' and args or {}
    local name = tostring(args.name or '')
    if name == '' then return nil, invalid('model name is required') end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'findObjectByModel', {
        name = name,
        coords = args.coords,
        radius = tonumber(args.radius) or 10.0,
    })
    if not ok then return nil, res end
    return res
end

-- Semantic interaction: fires an ALLOWLISTED server event that a world
-- marker would normally fire. Documented as a bypass — never pretends to be
-- a physical key press.
local ALLOWED_SEMANTIC_EVENTS = {
    ['sunset:robbery:tryStart'] = true,
    ['sunset:robbery:hackOpen'] = true,
}

function Tools.interact_semantic(target, args)
    args = type(args) == 'table' and args or {}
    local eventName = tostring(args.event or '')
    if not ALLOWED_SEMANTIC_EVENTS[eventName] then
        return nil, notAllowed(('semantic event "%s" is not on the allowlist'):format(eventName))
    end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'interactNearMarker', { event = eventName, arg = args.arg })
    if not ok then return nil, res end
    return res
end

function Tools.spawn_test_vehicle(target, args)
    args = type(args) == 'table' and args or {}
    local model = tostring(args.model or '')
    if model == '' then return nil, invalid('model is required') end
    -- Only road vehicles; block peds/objects/weapons models by prefix policy.
    if model:match('^weapon_') or model:match('^a_') or model:match('^cs_') or model:match('^ig_') then
        return nil, notAllowed('spawn_test_vehicle only spawns vehicle models')
    end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'spawnTestVehicle', { model = model, warp = args.warp == true })
    if not ok then return nil, res end
    return res
end

function Tools.delete_test_entity(target, args)
    args = type(args) == 'table' and args or {}
    local netId = tonumber(args.netId)
    if not netId then return nil, invalid('netId is required') end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    -- Server-side policy: only entities tagged as test-spawned may be deleted.
    local ok, res = RpcClient.await(src, 'deleteTestEntity', { netId = netId })
    if not ok then return nil, res end
    return res
end

-- ═══ INPUT / INTERACTION ═══
-- REAL control input (physical key simulation) is documented as such;
-- semantic actions that bypass input are named invoke_*.

function Tools.press_control(target, args)
    args = type(args) == 'table' and args or {}
    local control = tonumber(args.control)
    if not control or control < 0 or control > 600 then return nil, invalid('control must be 0-600') end
    local durationMs = math.min(math.max(tonumber(args.durationMs) or 100, 10), 3000)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'pressControl', { control = control, durationMs = durationMs })
    if not ok then return nil, res end
    return res
end

function Tools.hold_control(target, args)
    args = type(args) == 'table' and args or {}
    local control = tonumber(args.control)
    if not control or control < 0 or control > 600 then return nil, invalid('control must be 0-600') end
    local durationMs = math.min(math.max(tonumber(args.durationMs) or 1000, 10), 10000)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'holdControl', { control = control, durationMs = durationMs })
    if not ok then return nil, res end
    return res
end

function Tools.interact(target)
    -- Semantic: physically simulates the E (context, control 38) press used
    -- by every Sunset interaction marker. This IS real input simulation
    -- (SetControlNormal pressed-state injection), not a callback bypass.
    return Tools.press_control(target, { control = 38, durationMs = 120 })
end

-- Allowlist for invoke_callback — read-only or safely-repeatable callbacks.
-- Declared BEFORE Tools.invoke_callback uses it (lexical ordering).
local ALLOWED_INVOKE_CALLBACKS = {
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

function Tools.invoke_callback(target, args)
    -- Semantic BYPASS (documented): calls a sunset_core callback directly
    -- from the client, skipping world interaction. Allowlist restricts which
    -- callback names may be invoked — no arbitrary callbacks.
    args = type(args) == 'table' and args or {}
    local name = tostring(args.name or '')
    if not ALLOWED_INVOKE_CALLBACKS[name] then
        return nil, notAllowed(('callback "%s" is not on the test-agent invoke allowlist'):format(name))
    end
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'invokeCallback', {
        name = name,
        args = type(args.args) == 'table' and args.args or {},
    })
    if not ok then return nil, res end
    return res
end

-- ═══ SCREENSHOTS ═══

function Tools.take_screenshot(target, args)
    args = type(args) == 'table' and args or {}
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    if GetResourceState('screenshot_basic') ~= 'started' then
        return nil, { code = 'SCREENSHOT_FAILED', message = 'screenshot_basic resource is not started', retryable = true }
    end
    -- The server generates the requestId and tells the client where to upload
    -- (the game-port HTTP endpoint). Bytes never cross the server script
    -- thread: client → HTTP POST screenshot → ScreenshotStore; MCP GETs by id.
    local requestId = tostring(args.requestId or ('ss_' .. GetGameTimer() .. '_' .. math.random(1000, 99999)))
    -- The client builds its own upload URL from GetCurrentServerEndpoint()
    -- (works whether the test client is local or remote); we only pass the
    -- route + bearer.
    local ok, res = RpcClient.await(src, 'screenshot', {
        requestId = requestId,
        uploadRoute = ('%sscreenshot'):format(Cfg.httpPrefix),
        bearer = TestAgentAuth.bearerForClient(),
        source = src,
    }, Cfg.screenshotTimeoutMs)
    if not ok then return nil, res end
    return {
        requestId = requestId,
        bytes = res and res.bytes or nil,
        mime = res and res.mime or 'image/jpeg',
        downloadPath = ('%sscreenshot/%s'):format(Cfg.httpPrefix, requestId),
    }
end

-- ═══ LOGS ═══

function Tools.get_server_logs(args)
    args = type(args) == 'table' and args or {}
    return { logs = TestAgentLog.tail(tonumber(args.limit) or 200) }
end

function Tools.get_recent_errors(args)
    args = type(args) == 'table' and args or {}
    return { errors = TestAgentLog.errorsOnly(tonumber(args.limit) or 100) }
end

function Tools.get_client_logs(target, args)
    args = type(args) == 'table' and args or {}
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'clientLogs', { limit = tonumber(args.limit) or 200 })
    if not ok then return nil, res end
    return res
end

function Tools.clear_client_logs(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'clearClientLogs', {})
    if not ok then return nil, res end
    return res
end

-- ═══ NUI INSPECTION ═══

function Tools.get_nui_state(target)
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    if GetResourceState('sunset_ui') ~= 'started' then return nil, E.NUI_UNAVAILABLE end
    local ok, res = RpcClient.await(src, 'nuiState', {})
    if not ok then return nil, res end
    return res
end

function Tools.get_nui_focus(target)
    local state, err = Tools.get_nui_state(target)
    if not state then return nil, err end
    return { focus = state.focus, currentScreen = state.currentScreen }
end

function Tools.get_open_panels(target)
    local state, err = Tools.get_nui_state(target)
    if not state then return nil, err end
    return { openPanels = state.openPanels or {} }
end

function Tools.get_last_nui_message(target)
    local state, err = Tools.get_nui_state(target)
    if not state then return nil, err end
    return { lastMessage = state.lastMessage }
end

function Tools.get_nui_callback_history(target, args)
    args = type(args) == 'table' and args or {}
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    if GetResourceState('sunset_ui') ~= 'started' then return nil, E.NUI_UNAVAILABLE end
    local ok, res = RpcClient.await(src, 'nuiHistory', { limit = tonumber(args.limit) or 40 })
    if not ok then return nil, res end
    return res
end

function Tools.get_nui_errors(target, args)
    args = type(args) == 'table' and args or {}
    local src, err = TestAgentAuth.resolveTarget(target)
    if not src then return nil, err end
    local ok, res = RpcClient.await(src, 'nuiErrors', { limit = tonumber(args.limit) or 40 })
    if not ok then return nil, res end
    return res
end

-- ═══ RESOURCES ═══

function Tools.get_resource_state(args)
    args = type(args) == 'table' and args or {}
    local name = tostring(args.name or args.resource or '')
    if name == '' then return nil, invalid('resource name is required') end
    return { resource = name, state = GetResourceState(name) }
end

function Tools.list_sunset_resources()
    local out = {}
    local n = GetNumResources()
    for i = 0, n - 1 do
        local name = GetResourceByFindIndex(i)
        if name and name:sub(1, 7) == 'sunset_' then
            out[#out + 1] = { resource = name, state = GetResourceState(name) }
        end
    end
    return { resources = out, count = #out }
end

local function resourceGuard(name)
    if Cfg.protectedResources[name] then
        return notAllowed(('resource "%s" is protected and cannot be modified by the test bridge'):format(name))
    end
    if name:sub(1, #Cfg.allowedResourcePrefix) ~= Cfg.allowedResourcePrefix then
        return notAllowed(('only %s* resources may be modified (got "%s")'):format(Cfg.allowedResourcePrefix, name))
    end
    return nil
end

function Tools.restart_resource(args)
    args = type(args) == 'table' and args or {}
    local name = tostring(args.name or args.resource or '')
    if name == '' then return nil, invalid('resource name is required') end
    local guard = resourceGuard(name)
    if guard then return nil, guard end
    if GetResourceState(name) == 'missing' then
        return nil, { code = 'RESOURCE_NOT_STARTED', message = ('resource "%s" does not exist'):format(name), retryable = false }
    end
    RestartResource(name)
    TestAgentLog.event('resource', 'restarted', { resource = name })
    return { resource = name, state = GetResourceState(name) }
end

function Tools.start_resource(args)
    args = type(args) == 'table' and args or {}
    local name = tostring(args.name or args.resource or '')
    if name == '' then return nil, invalid('resource name is required') end
    local guard = resourceGuard(name)
    if guard then return nil, guard end
    StartResource(name)
    TestAgentLog.event('resource', 'started', { resource = name })
    return { resource = name, state = GetResourceState(name) }
end

function Tools.stop_resource(args)
    args = type(args) == 'table' and args or {}
    local name = tostring(args.name or args.resource or '')
    if name == '' then return nil, invalid('resource name is required') end
    local guard = resourceGuard(name)
    if guard then return nil, guard end
    StopResource(name)
    TestAgentLog.event('resource', 'stopped', { resource = name })
    return { resource = name, state = GetResourceState(name) }
end

-- ═══ DB (READ-ONLY, domain-specific) ═══

function Tools.get_character_db_state(args)
    args = type(args) == 'table' and args or {}
    local charId = tonumber(args.characterId)
    if not charId then return nil, invalid('characterId is required') end
    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT id, first_name, last_name, cash, bank, job, faction_id, faction_grade FROM characters WHERE id = ?',
            { charId })
    end)
    if not ok then return nil, E.INTERNAL end
    if not row then return nil, { code = 'ENTITY_NOT_FOUND', message = 'character not found', retryable = false } end
    return { character = row }
end

function Tools.get_robbery_db_state(args)
    args = type(args) == 'table' and args or {}
    local charId = tonumber(args.characterId)
    local limit = math.min(tonumber(args.limit) or 10, 50)
    local query = 'SELECT session_id, character_id, location_id, status, bag_used, estimated_value, started_at, finished_at FROM robbery_runs'
    local params = {}
    if charId then
        query = query .. ' WHERE character_id = ? ORDER BY started_at DESC LIMIT ' .. limit
        params[#params + 1] = charId
    else
        query = query .. ' ORDER BY started_at DESC LIMIT ' .. limit
    end
    local ok, rows = pcall(function() return MySQL.query.await(query, params) end)
    if not ok then return nil, E.INTERNAL end
    local cooldowns = nil
    pcall(function()
        cooldowns = MySQL.query.await(
            'SELECT scope, scope_key, expires_at FROM robbery_cooldowns WHERE expires_at > ?', { os.time() })
    end)
    return { runs = rows or {}, activeCooldowns = cooldowns or {} }
end

-- ═══ DISPATCH TABLE ═══
-- Every HTTP-exposed tool name maps here explicitly. Anything not in this
-- table is UNKNOWN_TOOL — there is no dynamic dispatch to globals.

TestAgentTools = {
    health = { fn = Tools.health },
    get_players = { fn = Tools.get_players },
    get_player_state = { fn = Tools.get_player_state, target = true },
    get_player_coords = { fn = Tools.get_player_coords, target = true },
    teleport_player = { fn = Tools.teleport_player, target = true, args = true },
    set_player_heading = { fn = Tools.set_player_heading, target = true, args = true },
    get_player_health = { fn = Tools.get_player_health, target = true },
    set_test_health = { fn = Tools.set_test_health, target = true, args = true },
    get_player_vehicle = { fn = Tools.get_player_vehicle, target = true },
    get_player_inventory = { fn = Tools.get_player_inventory, target = true },
    get_player_money = { fn = Tools.get_player_money, target = true },
    get_player_job = { fn = Tools.get_player_job, target = true },
    get_player_faction = { fn = Tools.get_player_faction, target = true },
    get_player_wanted = { fn = Tools.get_player_wanted, target = true },
    get_player_jail_state = { fn = Tools.get_player_jail_state, target = true },
    get_player_session_state = { fn = Tools.get_player_session_state, target = true },
    get_nearby_entities = { fn = Tools.get_nearby_entities, target = true, args = true },
    get_nearby_objects = { fn = Tools.get_nearby_objects, target = true, args = true },
    get_nearby_vehicles = { fn = Tools.get_nearby_vehicles, target = true, args = true },
    inspect_entity = { fn = Tools.inspect_entity, target = true, args = true },
    find_object = { fn = Tools.find_object, target = true, args = true },
    hash_model = { fn = Tools.hash_model, args = true },
    interact_semantic = { fn = Tools.interact_semantic, target = true, args = true },
    spawn_test_vehicle = { fn = Tools.spawn_test_vehicle, target = true, args = true },
    delete_test_entity = { fn = Tools.delete_test_entity, target = true, args = true },
    press_control = { fn = Tools.press_control, target = true, args = true },
    hold_control = { fn = Tools.hold_control, target = true, args = true },
    interact = { fn = Tools.interact, target = true },
    invoke_callback = { fn = Tools.invoke_callback, target = true, args = true },
    take_screenshot = { fn = Tools.take_screenshot, target = true, args = true },
    get_server_logs = { fn = Tools.get_server_logs, args = true },
    get_recent_errors = { fn = Tools.get_recent_errors, args = true },
    get_client_logs = { fn = Tools.get_client_logs, target = true, args = true },
    clear_client_logs = { fn = Tools.clear_client_logs, target = true },
    get_nui_state = { fn = Tools.get_nui_state, target = true },
    get_nui_focus = { fn = Tools.get_nui_focus, target = true },
    get_open_panels = { fn = Tools.get_open_panels, target = true },
    get_last_nui_message = { fn = Tools.get_last_nui_message, target = true },
    get_nui_callback_history = { fn = Tools.get_nui_callback_history, target = true, args = true },
    get_nui_errors = { fn = Tools.get_nui_errors, target = true, args = true },
    get_resource_state = { fn = Tools.get_resource_state, args = true },
    list_sunset_resources = { fn = Tools.list_sunset_resources },
    restart_resource = { fn = Tools.restart_resource, args = true },
    start_resource = { fn = Tools.start_resource, args = true },
    stop_resource = { fn = Tools.stop_resource, args = true },
    get_character_db_state = { fn = Tools.get_character_db_state, args = true },
    get_robbery_db_state = { fn = Tools.get_robbery_db_state, args = true },
}

-- Domain adapters register themselves here (server/domains.lua).
function TestAgentTools.registerDomain(name, spec)
    if TestAgentTools[name] then
        TestAgentLog.error('domain tool "%s" would shadow a core tool — registration refused', name)
        return false
    end
    TestAgentTools[name] = spec
    return true
end
