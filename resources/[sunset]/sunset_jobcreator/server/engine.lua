function JCEngine_TickSessions()
    local now = os.time()
    for source, session in pairs(JCSessions_GetAll and JCSessions_GetAll() or {}) do
        if session.waitUntil and now >= session.waitUntil then
            session.waitUntil = nil
            local stage = JCSessions_GetStage(session)
            if stage then
                JCEngine_Advance(source, stage.onSuccess or 'complete')
            end
        end
    end
end

function JCEngine_ClientAction(source, data)
    data = type(data) == 'table' and data or {}
    local session = JCSessions_Get(source)
    if not session or session.stageId ~= data.stageId then
        return nil, 'Invalid session stage.'
    end
    local stage = JCSessions_GetStage(session)
    if not stage then return nil, 'Invalid stage.' end

    if data.error then
        return JCEngine_Advance(source, stage.onFailure or 'fail')
    end

    if stage.type == 'spawn_vehicle' and data.netId then
        session.variables[stage.storeAs or 'vehicle'] = data.netId
        return JCEngine_Advance(source, stage.onSuccess)
    elseif stage.type == 'attach_trailer' and data.netId then
        session.variables[stage.storeAs or 'trailer'] = data.netId
        return JCEngine_Advance(source, stage.onSuccess)
    elseif stage.type == 'spawn_npc' and data.npcData then
        session.variables[stage.storeAs or 'npc'] = data.npcData
        return JCEngine_Advance(source, stage.onSuccess)
    elseif stage.type == 'spawn_prop' and data.propData then
        local copy = {}
        for k, v in pairs(data.propData) do
            if k ~= 'entity' then copy[k] = v end
        end
        session.variables[stage.storeAs or 'prop'] = copy
        return JCEngine_Advance(source, stage.onSuccess)
    elseif stage.type == 'delete_vehicle' or stage.type == 'remove_npc' then
        return JCEngine_Advance(source, stage.onSuccess)
    elseif stage.type == 'progress' or stage.type == 'skill_check' or stage.type == 'chop_prop' then
        if data.success then
            if stage.type == 'chop_prop' and data.poolKey then
                session.variables._poolCooldown = session.variables._poolCooldown or {}
                session.variables._poolCooldown[data.poolKey] = os.time() + (tonumber(stage.regenerateSec) or 45)
            end
            return JCEngine_Advance(source, stage.onSuccess)
        end
        return JCEngine_Advance(source, stage.onFailure or stage.onSuccess)
    end

    return nil, 'Unknown client action.'
end

function JCEngine_BuildClientPayload(session)
    local stage = JCSessions_GetStage(session)
    return {
        jobId = session.jobId,
        label = session.label,
        stageId = session.stageId,
        stage = stage,
        variables = session.variables,
        definition = {
            ui = session.definition.ui,
            locations = session.definition.locations,
        },
        timeoutAt = session.timeoutAt,
    }
end

function JCEngine_Advance(source, nextId)
    local session = JCSessions_Get(source)
    if not session then return nil, SunsetJobCreator.L('no_session') end

    while nextId and nextId ~= '' do
        if nextId == 'complete' then
            JCSessions_Clear(source, SunsetJobCreator.L('shift_complete'), false)
            TriggerEvent('sunset:jobcreator:jobCompleted', source, session.jobId)
            return { completed = true }
        end
        if nextId == 'fail' then
            JCSessions_Clear(source, SunsetJobCreator.L('shift_failed'), true)
            TriggerEvent('sunset:jobcreator:jobFailed', source, session.jobId)
            return { failed = true }
        end

        session.stageId = nextId
        local stage = JCSessions_GetStage(session)
        if not stage then
            JCSessions_Clear(source, 'Invalid stage', true)
            return nil, 'Invalid stage configuration.'
        end

        TriggerEvent('sunset:jobcreator:stageStarted', source, session.jobId, stage.id)
        local ok, autoNext, err = JCStages_Enter(source, session, stage)
        if not ok then return nil, err end
        if autoNext and autoNext ~= nextId then
            nextId = autoNext
        else
            TriggerClientEvent('sunset:jobcreator:sessionSync', source, JCEngine_BuildClientPayload(session))
            return JCEngine_BuildClientPayload(session)
        end
    end
    return JCEngine_BuildClientPayload(session)
end

function JCEngine_Start(source, jobRow, testMode)
    local session, err = JCSessions_Create(source, jobRow, testMode)
    if not session then return nil, err end
    TriggerEvent('sunset:jobcreator:jobStarted', source, jobRow.id)
    return JCEngine_Advance(source, session.stageId)
end

function JCEngine_Interact(source)
    local session = JCSessions_Get(source)
    if not session then return nil, SunsetJobCreator.L('no_session') end
    local now = GetGameTimer()
    if session.interactCooldown and now < session.interactCooldown then
        return nil, 'Wait a moment.'
    end
    session.interactCooldown = now + 500

    local stage = JCSessions_GetStage(session)
    if not stage then return nil, 'Invalid stage.' end

    local ok, nextId, err = JCStages_Interact(source, session, stage)
    if not ok then return nil, err end
    if not nextId then
        nextId = resolveNextFromStage(stage, true)
    end
    TriggerEvent('sunset:jobcreator:stageCompleted', source, session.jobId, stage.id)
    return JCEngine_Advance(source, nextId)
end

function resolveNextFromStage(stage, success)
    if success then return stage.onSuccess or 'complete' end
    return stage.onFailure or 'fail'
end

function JCEngine_DebugSkip(source)
    local session = JCSessions_Get(source)
    if not session then return nil, SunsetJobCreator.L('no_session') end
    local stage = JCSessions_GetStage(session)
    return JCEngine_Advance(source, stage.onSuccess or 'complete')
end
