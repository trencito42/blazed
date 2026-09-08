local CustomStages = {}

local function vec3(c)
    if type(c) == 'vector3' then return c end
    return vector3(tonumber(c.x) or 0, tonumber(c.y) or 0, tonumber(c.z) or 0)
end

local function dist2d(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function playerPos(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function inZone(source, loc)
    if not loc then return false end
    local pos = playerPos(source)
    if not pos then return false end
    local ped = GetPlayerPed(source)
    local inVeh = ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
    local t = vec3(loc)
    local defaultRadius = inVeh and 8.0 or 3.0
    local radius = tonumber(loc.radius) or defaultRadius
    if inVeh and radius < 7.0 then radius = 7.0 end
    local zTol = tonumber(loc.zTolerance) or (inVeh and 8.0 or 5.0)
    if dist2d(pos, t) > radius then return false end
    return math.abs(pos.z - t.z) <= zTol
end

local function poolEntryKey(entry)
    if entry.id then return tostring(entry.id) end
    return string.format('%.1f_%.1f', tonumber(entry.x) or 0, tonumber(entry.y) or 0)
end

local function filterPool(session, pool)
    pool = pool or {}
    local cooldown = session.variables._poolCooldown or {}
    local now = os.time()
    local filtered = {}
    for _, e in ipairs(pool) do
        local key = poolEntryKey(e)
        e.poolKey = key
        if not cooldown[key] or cooldown[key] <= now then
            filtered[#filtered + 1] = e
        end
    end
    if #filtered == 0 then return pool end
    return filtered
end

local function pickWeighted(pool)
    pool = pool or {}
    if #pool == 0 then return nil end
    local total = 0
    for _, e in ipairs(pool) do total = total + (tonumber(e.weight) or 1) end
    local roll = math.random() * total
    local acc = 0
    for _, e in ipairs(pool) do
        acc = acc + (tonumber(e.weight) or 1)
        if roll <= acc then return e end
    end
    return pool[1]
end

local function runActions(session, actions)
    for _, act in ipairs(actions or {}) do
        local t = act.type
        local var = act.var or act.name
        if t == 'set' and var then
            session.variables[var] = act.value
        elseif t == 'increment' and var then
            session.variables[var] = (tonumber(session.variables[var]) or 0) + (tonumber(act.value) or 1)
        elseif t == 'decrement' and var then
            session.variables[var] = (tonumber(session.variables[var]) or 0) - (tonumber(act.value) or 1)
        elseif t == 'pick_random' and var then
            local poolKey = act.pool
            local pool = session.definition.pools and session.definition.pools[poolKey]
            if act.respectCooldown then pool = filterPool(session, pool) end
            local pick = pickWeighted(pool)
            if pick then
                pick.poolKey = poolEntryKey(pick)
                session.variables[var] = pick
            end
        end
    end
end

local function resolveNext(stage, success)
    if success then
        return stage.onSuccess or 'complete'
    end
    return stage.onFailure or 'fail'
end

local function evalBranch(session, branch)
    if not branch then return true end
    if branch.var then
        local left = tonumber(session.variables[branch.var]) or session.variables[branch.var]
        local op = branch.op or '>='
        local right = branch.valueRef and session.variables[branch.valueRef] or branch.value
        right = tonumber(right) or right
        left = tonumber(left) or left
        if op == '>=' then return tonumber(left) >= tonumber(right)
        elseif op == '<=' then return tonumber(left) <= tonumber(right)
        elseif op == '==' then return left == right
        elseif op == '>' then return tonumber(left) > tonumber(right)
        elseif op == '<' then return tonumber(left) < tonumber(right)
        end
    end
    return true
end

local StageHandlers = {}

StageHandlers.objective = {
    enter = function() return true end,
    interact = function() return true, 'complete' end,
}

StageHandlers.goto_zone = {
    enter = function() return true end,
    interact = function(source, session, stage)
        local loc = SunsetJobCreator.StageLocation(session.definition, stage, session.variables)
        if inZone(source, loc) then return true, resolveNext(stage, true) end
        return false, nil, SunsetJobCreator.L('interact_far')
    end,
    tick = function(source, session, stage)
        local loc = SunsetJobCreator.StageLocation(session.definition, stage, session.variables)
        if inZone(source, loc) then return true, resolveNext(stage, true) end
    end,
}

StageHandlers.zone_interact = {
    interact = function(source, session, stage)
        local loc = SunsetJobCreator.StageLocation(session.definition, stage, session.variables)
        if not inZone(source, loc) then
            return false, nil, SunsetJobCreator.L('interact_far')
        end
        if stage.requireTrailer and session.variables.trailer and JCTrucking_GetState then
            local state = JCTrucking_GetState(session, true, 40.0)
            if state == 'detached' then
                return false, nil, 'Reatașează remorca înainte de livrare.'
            end
            if state == 'destroyed' or state == 'too_far' then
                return false, nil, 'Remorca lipsește — folosește /recovertrailer.'
            end
        end
        runActions(session, stage.actions)
        return true, resolveNext(stage, true)
    end,
}

StageHandlers.branch = {
    enter = function(source, session, stage)
        local target = stage.ifTrue
        if evalBranch(session, stage.condition) then
            target = stage.ifTrue or stage.onSuccess
        else
            target = stage.ifFalse or stage.onFailure
        end
        return true, target or 'complete'
    end,
}

StageHandlers.pick_random = {
    enter = function(source, session, stage)
        runActions(session, {
            {
                type = 'pick_random',
                var = stage.storeAs or 'picked',
                pool = stage.pool,
                respectCooldown = stage.respectCooldown ~= false,
            },
        })
        return true, resolveNext(stage, true)
    end,
}

StageHandlers.set_variable = {
    enter = function(source, session, stage)
        runActions(session, stage.actions or { { type = 'set', var = stage.var, value = stage.value } })
        return true, resolveNext(stage, true)
    end,
}

StageHandlers.scale_from_level = {
    enter = function(source, session, stage)
        local level = 1
        if GetResourceState('sunset_jobs') == 'started' then
            level = exports.sunset_jobs:GetJobLevel(source, session.jobId) or 1
        end
        local var = stage.var or 'total'
        local base = tonumber(stage.base) or 3
        local perLevel = tonumber(stage.perLevel) or 1
        local max = tonumber(stage.max) or 10
        session.variables[var] = math.min(max, base + math.max(0, level - 1) * perLevel)
        if stage.resetVar then
            session.variables[stage.resetVar] = 0
        end
        return true, resolveNext(stage, true)
    end,
}

StageHandlers.give_reward = {
    enter = function(source, session, stage)
        local prog = session.definition.progression or {}
        local pay = tonumber(stage.pay) or tonumber(prog.payPerTask) or 0
        if stage.payVar and session.variables[stage.payVar] then
            local ref = session.variables[stage.payVar]
            if type(ref) == 'table' then
                pay = tonumber(ref.pay) or pay
            else
                pay = tonumber(ref) or pay
            end
        end
        local xp = tonumber(stage.xp) or tonumber(prog.xpPerTask) or 0
        local payJobId = session.jobId
        local char = exports.sunset_core:GetCharacter(source)
        if char then
            local charJob = char.job or 'unemployed'
            if SunsetJobCreator.GetMigrationTarget(charJob) == session.jobId then
                payJobId = charJob
            end
        end
        local paidOk = false
        if pay > 0 and GetResourceState('sunset_jobs') == 'started' then
            paidOk = exports.sunset_jobs:PayReward(source, payJobId, pay, payJobId .. '_task', true)
        end
        if pay > 0 and not paidOk then
            exports.sunset_core:AddMoney(source, 'cash', pay, 'jc_' .. session.jobId .. '_task')
            exports.sunset_core:AddXP(source, math.max(1, math.floor(pay / 20)))
        end
        if xp > 0 and GetResourceState('sunset_jobs') == 'started' then
            exports.sunset_jobs:AddJobXP(source, payJobId, xp)
        elseif xp > 0 then
            exports.sunset_core:AddXP(source, xp)
        end
        TriggerClientEvent('sunset:jobcreator:paid', source, {
            pay = pay,
            xp = xp,
            done = tonumber(session.variables[prog.progressVar or 'done'])
                or tonumber(session.variables.tasks)
                or tonumber(session.variables.done) or 0,
            total = tonumber(session.variables[prog.progressTotalVar or 'total'])
                or tonumber(session.variables.total) or 0,
            bagLabel = (session.definition.ui and session.definition.ui.bagLabel) or 'Task',
        })
        return true, resolveNext(stage, true)
    end,
}

StageHandlers.complete = {
    enter = function()
        return true, 'complete'
    end,
}

StageHandlers.fail = {
    enter = function()
        return true, 'fail'
    end,
}

-- Wait
StageHandlers.wait = {
    enter = function(source, session, stage)
        session.waitUntil = os.time() + (tonumber(stage.seconds) or 1)
        return true, nil
    end,
}

-- Items
StageHandlers.require_item = {
    enter = function(source, session, stage)
        local count = tonumber(stage.count) or 1
        local ok = GetResourceState('sunset_inventory') == 'started'
            and exports.sunset_inventory:HasItem(source, stage.item, count)
        if not ok then return true, stage.onFailure or 'fail' end
        return true, resolveNext(stage, true)
    end,
}

StageHandlers.give_item = {
    enter = function(source, session, stage)
        local count = tonumber(stage.count) or 1
        if GetResourceState('sunset_inventory') == 'started' then
            exports.sunset_inventory:TryAddItem(source, stage.item, count)
        end
        return true, resolveNext(stage, true)
    end,
}

StageHandlers.remove_item = {
    enter = function(source, session, stage)
        local count = tonumber(stage.count) or 1
        local ok = GetResourceState('sunset_inventory') == 'started'
            and exports.sunset_inventory:RemoveItem(source, stage.item, count)
        if not ok then return true, stage.onFailure or 'fail' end
        return true, resolveNext(stage, true)
    end,
}

-- Party
local function countNearbyCoworkers(source, session, radius)
    local pos = playerPos(source)
    if not pos then return 1 end
    local count = 1
    for _, pid in ipairs(GetPlayers()) do
        local other = tonumber(pid)
        if other and other ~= source then
            local otherSession = JCSessions_Get(other)
            if otherSession and otherSession.jobId == session.jobId then
                local opos = playerPos(other)
                if opos and #(pos - opos) <= (radius or 25.0) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

StageHandlers.party_gate = {
    interact = function(source, session, stage)
        local minPlayers = tonumber(stage.minPlayers) or 1
        local radius = tonumber(stage.radius) or 25.0
        if countNearbyCoworkers(source, session, radius) < minPlayers then
            return false, nil, stage.message or ('Need at least %d players nearby.'):format(minPlayers)
        end
        return true, resolveNext(stage, true)
    end,
    enter = function() return true, nil end,
}

-- Vehicles (client setup stages)
StageHandlers.spawn_vehicle = {
    enter = function() return true, nil end,
}

StageHandlers.attach_trailer = {
    enter = function() return true, nil end,
}

StageHandlers.delete_vehicle = {
    enter = function() return true, nil end,
}

StageHandlers.spawn_npc = {
    enter = function() return true, nil end,
}

StageHandlers.remove_npc = {
    enter = function() return true, nil end,
}

local function inJobVehicle(source, session, vehicleVar)
    vehicleVar = vehicleVar or 'vehicle'
    local netId = session.variables[vehicleVar]
    if not netId then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return false end
    local ent = NetworkGetEntityFromNetworkId(netId)
    return ent and ent == veh
end

StageHandlers.enter_vehicle = {
    interact = function(source, session, stage)
        if inJobVehicle(source, session, stage.vehicleVar) then
            return true, resolveNext(stage, true)
        end
        return false, nil, stage.message or 'Enter the job vehicle.'
    end,
    tick = function(source, session, stage)
        if inJobVehicle(source, session, stage.vehicleVar) then
            return true, resolveNext(stage, true)
        end
    end,
}

StageHandlers.require_vehicle = {
    interact = function(source, session, stage)
        if inJobVehicle(source, session, stage.vehicleVar) then
            return true, resolveNext(stage, true)
        end
        return false, nil, stage.message or 'You must be in the job vehicle.'
    end,
}

StageHandlers.return_vehicle = {
    interact = function(source, session, stage)
        local loc = SunsetJobCreator.StageLocation(session.definition, stage, session.variables)
        if not inZone(source, loc) then
            return false, nil, SunsetJobCreator.L('interact_far')
        end
        if not inJobVehicle(source, session, stage.vehicleVar) then
            return false, nil, stage.message or 'Return in the job vehicle.'
        end
        return true, resolveNext(stage, true)
    end,
}

StageHandlers.talk_to_npc = {
    interact = function(source, session, stage)
        local npcVar = stage.npcVar or 'npc'
        local loc = session.variables[npcVar]
        if not loc or not inZone(source, loc) then
            return false, nil, SunsetJobCreator.L('interact_far')
        end
        runActions(session, stage.actions)
        return true, resolveNext(stage, true)
    end,
}

-- Client-driven gameplay
StageHandlers.progress = {
    enter = function() return true, nil end,
}

StageHandlers.chop_prop = {
    enter = function() return true, nil end,
}

StageHandlers.spawn_prop = {
    enter = function() return true, nil end,
}

StageHandlers.skill_check = {
    enter = function() return true, nil end,
}

function JCStages_Register(name, handler)
    CustomStages[name] = handler
end

function JCStages_Get(name)
    return StageHandlers[name] or CustomStages[name]
end

function JCStages_Enter(source, session, stage)
    local handler = JCStages_Get(stage.type)
    if not handler then return false, nil, ('Unknown stage type: %s'):format(stage.type) end
    if handler.enter then
        return handler.enter(source, session, stage)
    end
    return true, stage.onSuccess
end

function JCStages_Interact(source, session, stage)
    local handler = JCStages_Get(stage.type)
    if not handler or not handler.interact then
        return false, nil, 'This step cannot be interacted with.'
    end
    return handler.interact(source, session, stage)
end

function JCStages_Tick(source, session, stage)
    local handler = JCStages_Get(stage.type)
    if handler and handler.tick then
        return handler.tick(source, session, stage)
    end
end

exports('RegisterStageType', JCStages_Register)
