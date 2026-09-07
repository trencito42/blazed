local active = false
local payload = nil
local blips = {}
local lastGotoAdvance = 0
local lastStageId = nil
local clientSetupDone = nil
local progressActive = false
local skillActive = false
local lastTruckTick = 0

local INTERACT_STAGES = {
    zone_interact = true,
    talk_to_npc = true,
    progress = true,
    chop_prop = true,
    skill_check = true,
    party_gate = true,
    return_vehicle = true,
    enter_vehicle = true,
    require_vehicle = true,
}

local AUTO_ZONE_STAGES = {
    goto_zone = true,
    enter_vehicle = true,
}

local function notify(msg, kind)
    exports.sunset_ui:Notify(msg, kind or 'info', 6000)
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

local function clearBlips()
    for _, b in ipairs(blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blips = {}
end

local function addBlipAt(coords, cfg, label)
    if not coords or not coords.x then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, (cfg and cfg.sprite) or 1)
    SetBlipColour(blip, (cfg and cfg.color) or 47)
    SetBlipScale(blip, (cfg and cfg.scale) or 0.85)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, (cfg and cfg.color) or 47)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Objective')
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
end

local function stageLocation(data)
    if not data or not data.stage then return nil end
    local loc = SunsetJobCreator.StageLocation(
        data.definition or {},
        data.stage,
        data.variables or {}
    )
    if loc and data.stage.type == 'talk_to_npc' then
        local npcVar = data.stage.npcVar or 'npc'
        loc = (data.variables or {})[npcVar] or loc
    end
    return loc
end

local function formatMessage(stage, key)
    local msg = stage.message or stage.label or 'Follow the marker'
    return msg:gsub('{key}', key or 'E')
end

local function jobProgress(vars)
    local total = tonumber(vars.total) or tonumber(vars.caught) or 0
    local done = tonumber(vars.logs) or tonumber(vars.done) or tonumber(vars.mined)
        or tonumber(vars.tasks) or tonumber(vars.sorted) or tonumber(vars.harvest)
        or tonumber(vars.caught) or 0
    return done, total
end

local function fishingHud(data, extra)
    local ui = (data.definition and data.definition.ui) or {}
    local vars = data.variables or {}
    local done, total = jobProgress(vars)
    local payload = {
        title = ui.title or data.label or 'Work',
        bagLabel = ui.bagLabel or 'Task',
        icon = data.icon or ui.icon or 'briefcase',
    }
    if total > 0 then
        payload.carried = done
        payload.capacity = total
    end
    if extra then
        for k, v in pairs(extra) do payload[k] = v end
    end
    exports.sunset_ui:Send('fishingShow', payload)
    exports.sunset_ui:Send('jobShiftHide', {})
end

local function syncHud(data, override)
    if not data then return end
    local ui = (data.definition and data.definition.ui) or {}
    local stage = data.stage or {}
    local vars = data.variables or {}
    local done, total = jobProgress(vars)
    local key = ui.key or 'E'
    local title = ui.title or data.label or 'Work'
    local bagLabel = ui.bagLabel or 'Task'

    local state = 'shift'
    local message = formatMessage(stage, key)

    if override then
        state = override.state or state
        message = override.message or message
    else
        local stageType = stage.type
        if stageType == 'zone_interact' or stageType == 'progress' or stageType == 'chop_prop' or stageType == 'skill_check' then
            if progressActive or skillActive then
                state = 'waiting'
                message = stage.label or 'Working...'
            else
                state = 'idle'
                message = formatMessage(stage, key)
            end
        elseif stageType == 'give_reward' or stageType == 'complete' then
            state = 'success'
            message = formatMessage(stage, key)
        else
            state = 'shift'
            message = formatMessage(stage, key)
        end
    end

    local payload = {
        state = state,
        title = title,
        message = message,
        bagLabel = bagLabel,
        icon = data.icon or ui.icon or 'briefcase',
    }
    if total > 0 then
        payload.carried = done
        payload.capacity = total
        if not override then
            message = ('%s · %s %d/%d'):format(message, bagLabel, done, total)
            payload.message = message
        end
    end
    exports.sunset_ui:Send('fishingShow', payload)
    exports.sunset_ui:Send('jobShiftHide', {})
end

local function endShift(reason, failed)
    active = false
    payload = nil
    clientSetupDone = nil
    progressActive = false
    skillActive = false
    if JCTrucking_Reset then JCTrucking_Reset() end
    clearBlips()
    exports.sunset_ui:Send('fishingHide', {})
    exports.sunset_ui:Send('jobShiftHide', {})
    exports.sunset_ui:Send('jobSkillHide', {})
    JCEntities_Cleanup()
    if reason then notify(reason, failed and 'error' or 'success') end
end

local function sendClientAction(stageId, body)
    if not active or not payload or payload.stageId ~= stageId then return end
    local result, err = Sunset.AwaitCallback('sunset:jobcreator:clientAction', {
        stageId = stageId,
        error = body.error,
        netId = body.netId,
        npcData = body.npcData,
        propData = body.propData,
        poolKey = body.poolKey,
        success = body.success,
    })
    if err then notify(err, 'error') end
    if result and (result.completed or result.failed) then return end
    if result then TriggerEvent('sunset:jobcreator:sessionSync', result) end
end

local function runClientSetup(data)
    if not data or not data.stage then return end
    local key = data.stageId .. ':' .. data.stage.type
    if clientSetupDone == key then return end

    local stage = data.stage
    local def = data.definition or {}
    local vars = data.variables or {}

    if stage.type == 'spawn_vehicle' then
        CreateThread(function()
            local netId, err = JCEntities_SpawnVehicle(stage, vars, def)
            sendClientAction(data.stageId, { netId = netId, error = err })
        end)
        clientSetupDone = key
    elseif stage.type == 'attach_trailer' then
        CreateThread(function()
            local netId, err = JCEntities_AttachTrailer(stage, vars, def)
            sendClientAction(data.stageId, { netId = netId, error = err })
        end)
        clientSetupDone = key
    elseif stage.type == 'delete_vehicle' then
        JCEntities_DeleteVehicles()
        sendClientAction(data.stageId, { success = true })
        clientSetupDone = key
    elseif stage.type == 'spawn_npc' then
        CreateThread(function()
            local npcData, err = JCEntities_SpawnNpc(stage, vars, def)
            sendClientAction(data.stageId, { npcData = npcData, error = err })
        end)
        clientSetupDone = key
    elseif stage.type == 'spawn_prop' then
        CreateThread(function()
            local propData, err = JCEntities_SpawnProp(stage, vars, def)
            sendClientAction(data.stageId, { propData = propData, error = err })
        end)
        clientSetupDone = key
    elseif stage.type == 'remove_npc' then
        JCEntities_RemoveNpc(vars, stage.npcVar)
        sendClientAction(data.stageId, { success = true })
        clientSetupDone = key
    elseif stage.type == 'chop_prop' then
        local propVar = stage.propVar or 'treeProp'
        local ent = JCEntities.propByVar[propVar]
        if not ent or not DoesEntityExist(ent) then
            CreateThread(function()
                JCEntities_SpawnProp({ model = stage.model, locationVar = stage.locationVar, storeAs = propVar }, vars, def)
            end)
        end
        clientSetupDone = key
    end
end

local function startProgressStage(data)
    if progressActive then return end
    local stage = data.stage
    local loc = stageLocation(data)
    if loc then
        local pos = GetEntityCoords(PlayerPedId())
        local radius = tonumber(loc.radius) or 3.0
        local dx, dy = pos.x - loc.x, pos.y - loc.y
        if math.sqrt(dx * dx + dy * dy) > radius then
            notify(SunsetJobCreator.L('interact_far'), 'error')
            return
        end
    end
    progressActive = true
    local duration = tonumber(stage.durationMs) or 5000
    local key = (data.definition and data.definition.ui and data.definition.ui.key) or 'E'
    fishingHud(data, {
        state = 'work',
        message = formatMessage(stage, key),
        windowMs = duration,
    })
    SetTimeout(duration, function()
        if not progressActive then return end
        progressActive = false
        sendClientAction(data.stageId, { success = true })
    end)
end

local function startChopStage(data)
    if progressActive then return end
    local stage = data.stage
    local loc = stageLocation(data)
    if loc then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local radius = tonumber(loc.radius) or 3.5
        local dx, dy = pos.x - loc.x, pos.y - loc.y
        if math.sqrt(dx * dx + dy * dy) > radius then
            notify(SunsetJobCreator.L('interact_far'), 'error')
            return
        end
        TaskTurnPedToFaceCoord(ped, loc.x, loc.y, loc.z, 600)
        Wait(400)
    end
    progressActive = true
    local swings = tonumber(stage.swings) or 5
    local duration = tonumber(stage.durationMs) or (swings * 1200)
    local key = (data.definition and data.definition.ui and data.definition.ui.key) or 'E'
    fishingHud(data, {
        state = 'work',
        message = formatMessage(stage, key),
        windowMs = duration,
    })
    CreateThread(function()
        JCEntities_PlayChopAnim(swings, duration)
        if not progressActive then return end
        local propVar = stage.propVar or 'treeProp'
        JCEntities_RemoveProp(data.variables or {}, propVar)
        progressActive = false
        sendClientAction(data.stageId, {
            success = true,
            poolKey = loc and (loc.poolKey or (loc.x and string.format('%.1f_%.1f', loc.x, loc.y))),
        })
    end)
end

local function startSkillCheck(data)
    if skillActive then return end
    local stage = data.stage
    local loc = stageLocation(data)
    if loc then
        local pos = GetEntityCoords(PlayerPedId())
        local radius = tonumber(loc.radius) or 3.0
        local dx, dy = pos.x - loc.x, pos.y - loc.y
        if math.sqrt(dx * dx + dy * dy) > radius then
            notify(SunsetJobCreator.L('interact_far'), 'error')
            return
        end
    end
    skillActive = true
    local windowMs = tonumber(stage.windowMs) or 1500
    exports.sunset_ui:Send('jobSkillShow', {
        message = stage.message or 'Press E in time!',
        windowMs = windowMs,
        key = (data.definition and data.definition.ui and data.definition.ui.key) or 'E',
    })
    CreateThread(function()
        local deadline = GetGameTimer() + windowMs
        local hit = false
        while skillActive and GetGameTimer() < deadline do
            if IsControlJustReleased(0, 38) then
                hit = true
                break
            end
            Wait(0)
        end
        skillActive = false
        exports.sunset_ui:Send('jobSkillHide', {})
        sendClientAction(data.stageId, { success = hit })
    end)
end

RegisterNetEvent('sunset:jobcreator:sessionSync', function(data)
    active = data ~= nil
    payload = data
    clearBlips()
    if not data then
        endShift()
        return
    end
    if data.stageId ~= lastStageId then
        lastGotoAdvance = 0
        lastStageId = data.stageId
        clientSetupDone = nil
        progressActive = false
        skillActive = false
    end

    runClientSetup(data)

    local loc = stageLocation(data)
    if loc and loc.x then
        local blipCfg = loc.blip or { sprite = 478, color = 47, scale = 0.85 }
        addBlipAt(loc, blipCfg, loc.label or data.stage.label)
        SetNewWaypoint(loc.x, loc.y)
    end
    syncHud(data)
end)

RegisterNetEvent('sunset:jobcreator:sessionEnded', function(info)
    endShift(info and info.reason, info and info.failed)
end)

function JCRuntime_StartWork(testJobId)
    local data, err = Sunset.AwaitCallback('sunset:jobcreator:startWork', testJobId)
    if not data then
        notify(err or 'Could not start shift', 'error')
        return
    end
    if data.completed or data.failed then return end
    TriggerEvent('sunset:jobcreator:sessionSync', data)
end

function JCRuntime_Cancel()
    Sunset.AwaitCallback('sunset:jobcreator:cancel')
    endShift('Shift cancelled', false)
end

CreateThread(function()
    while true do
        local waitMs = 500
        if active and payload and payload.stage then
            waitMs = 0
            local stage = payload.stage
            local stageType = stage.type
            local loc = stageLocation(payload)
            if loc and loc.x then
                local radius = tonumber(loc.radius) or 3.0
                local size = math.max(3.5, radius * 1.2)
                DrawMarker(1, loc.x, loc.y, loc.z - 1.0, 0, 0, 0, 0, 0, 0,
                    size, size, 2.0, 255, 153, 51, 130, false, false, 2, false, nil, nil, false)
            end

            local near = false
            if loc and loc.x then
                local pos = GetEntityCoords(PlayerPedId())
                local dx = pos.x - loc.x
                local dy = pos.y - loc.y
                local radius = tonumber(loc.radius) or 3.0
                near = math.sqrt(dx * dx + dy * dy) <= radius
                    and math.abs(pos.z - loc.z) <= (tonumber(loc.zTolerance) or 5.0)
            end

            if AUTO_ZONE_STAGES[stageType] and near then
                local now = GetGameTimer()
                if now - lastGotoAdvance >= 1500 then
                    lastGotoAdvance = now
                    local result, err = Sunset.AwaitCallback('sunset:jobcreator:interact')
                    if err then notify(err, 'error') end
                    if result and (result.completed or result.failed) then goto continue end
                    if result then TriggerEvent('sunset:jobcreator:sessionSync', result) end
                end
            elseif INTERACT_STAGES[stageType] and (near or stageType == 'party_gate' or stageType == 'require_vehicle') then
                local helpMsg = formatMessage(stage, (payload.definition and payload.definition.ui and payload.definition.ui.key) or 'E')
                if stageType == 'progress' then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentString('Press ~INPUT_CONTEXT~ — ' .. helpMsg)
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) and not progressActive then
                        startProgressStage(payload)
                    end
                elseif stageType == 'chop_prop' then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentString('Press ~INPUT_CONTEXT~ — ' .. helpMsg)
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) and not progressActive then
                        startChopStage(payload)
                    end
                elseif stageType == 'skill_check' then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentString('Press ~INPUT_CONTEXT~ — ' .. helpMsg)
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) and not skillActive then
                        startSkillCheck(payload)
                    end
                else
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentString('Press ~INPUT_CONTEXT~ — ' .. helpMsg)
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then
                        local result, err = Sunset.AwaitCallback('sunset:jobcreator:interact')
                        if err then notify(err, 'error') end
                        if result and (result.completed or result.failed) then return end
                        if result then TriggerEvent('sunset:jobcreator:sessionSync', result) end
                    end
                end
            end
            ::continue::
        end
        if active and payload and JCTrucking_Tick then
            local now = GetGameTimer()
            if now - lastTruckTick >= 2000 then
                lastTruckTick = now
                JCTrucking_Tick(payload, syncHud, notify)
            end
        end
        Wait(waitMs)
    end
end)
