local Sessions = {}
local seq = 0

function JCSessions_GetAll()
    return Sessions
end

function JCSessions_Get(source)
    return Sessions[source]
end

function JCSessions_Clear(source, reason, failed)
    local session = Sessions[source]
    if not session then return end
    TriggerClientEvent('sunset:jobcreator:cleanupEntities', source)
    Sessions[source] = nil
    TriggerClientEvent('sunset:jobcreator:sessionEnded', source, {
        jobId = session.jobId,
        reason = reason,
        failed = failed == true,
    })
end

function JCSessions_Create(source, jobRow, testMode)
    if Sessions[source] then return nil, SunsetJobCreator.L('already_working') end
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Character not loaded.' end
    if not testMode then
        local jobId = select(1, Sunset.GetCharacterJob(char))
        local allowed = jobId == jobRow.id
        if not allowed then
            local mig = SunsetJobCreator.GetMigrationTarget(jobId)
            allowed = mig == jobRow.id
        end
        if not allowed then
            return nil, SunsetJobCreator.L('wrong_job')
        end
    end

    seq = seq + 1
    local def = jobRow.definition
    local vars = {}
    for k, v in pairs(def.variables or {}) do vars[k] = v end

    local session = {
        id = seq,
        jobId = jobRow.id,
        label = jobRow.label,
        definition = def,
        stageId = def.startStage,
        variables = vars,
        entities = {},
        startedAt = os.time(),
        timeoutAt = os.time() + (tonumber(def.timeoutSec) or 1800),
        testMode = testMode == true,
        interactCooldown = 0,
    }
    Sessions[source] = session
    return session
end

function JCSessions_GetStage(session)
    return SunsetJobCreator.FindStage(session.definition, session.stageId)
end

function JCSessions_SetStage(source, stageId)
    local session = Sessions[source]
    if not session then return false end
    session.stageId = stageId
    return true
end

function JCSessions_TickTimeouts()
    local now = os.time()
    for source, session in pairs(Sessions) do
        if session.timeoutAt and now > session.timeoutAt then
            JCSessions_Clear(source, 'Time expired', true)
        end
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        JCSessions_TickTimeouts()
        if JCEngine_TickSessions then JCEngine_TickSessions() end
    end
end)

AddEventHandler('playerDropped', function()
    JCSessions_Clear(source, 'Disconnected', true)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for source in pairs(Sessions) do
        JCSessions_Clear(source, 'Resource stopped', true)
    end
end)
