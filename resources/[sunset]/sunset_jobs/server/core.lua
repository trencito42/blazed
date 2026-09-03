local Sessions = {}
local sessionSeq = 0

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function charJob(source)
    local char = getChar(source)
    if not char then return nil end
    return select(1, Sunset.GetCharacterJob(char))
end

local function playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return vector3(c.x, c.y, c.z)
end

local function dist(a, b)
    if not a or not b then return 999999.0 end
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

function SunsetJobs_GetSession(source)
    return Sessions[source]
end

function SunsetJobs_ClearSession(source, finalState, reason)
    local session = Sessions[source]
    if not session then return end
    session.state = finalState or 'CANCELLED'
    session.endReason = reason
    Sessions[source] = nil
    TriggerClientEvent('sunset:jobs:sessionEnded', source, session.jobId, session.state, reason)
end

function SunsetJobs_RequireSession(source, jobId, allowedStates)
    local session = Sessions[source]
    if not session then return nil, 'No active work session' end
    if jobId and session.jobId ~= jobId then return nil, 'Wrong job session' end
    if allowedStates then
        local ok = false
        for _, st in ipairs(allowedStates) do
            if session.state == st then ok = true break end
        end
        if not ok then return nil, 'Invalid session state' end
    end
    if session.timeoutAt and os.time() > session.timeoutAt then
        SunsetJobs_ClearSession(source, 'FAILED', 'Session timed out')
        return nil, 'Session timed out'
    end
    return session
end

function SunsetJobs_SetState(source, state)
    local session = Sessions[source]
    if not session then return false end
    session.state = state
    TriggerClientEvent('sunset:jobs:stateChanged', source, state, session.data or {})
    return true
end

function SunsetJobs_ValidateCoords(source, target, radius)
    local pos = playerCoords(source)
    if not pos then return false end
    local t = type(target) == 'vector3' and target or vector3(target.x, target.y, target.z)
    return dist(pos, t) <= (radius or 5.0)
end

local function xpForLevel(level)
    return math.max(100, (level or 1) * 100)
end

function SunsetJobs_AddJobXP(source, jobId, amount)
    local char = getChar(source)
    if not char or not amount or amount <= 0 then return end

    local row = MySQL.single.await(
        'SELECT xp, level, completed_tasks, total_earned FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, jobId }
    )
    local xp = (row and row.xp or 0) + amount
    local level = row and row.level or 1
    local tasks = row and row.completed_tasks or 0
    local earned = row and row.total_earned or 0

    local needed = xpForLevel(level)
    while xp >= needed do
        xp = xp - needed
        level = level + 1
        needed = xpForLevel(level)
        TriggerClientEvent('sunset:client:notify', source,
            ('%s skill level %d!'):format(Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId, level),
            'success', 5000)
    end

    if row then
        MySQL.update.await(
            'UPDATE job_progress SET xp = ?, level = ?, completed_tasks = ?, total_earned = ? WHERE character_id = ? AND job_id = ?',
            { xp, level, tasks, earned, char.id, jobId }
        )
    else
        MySQL.insert.await(
            'INSERT INTO job_progress (character_id, job_id, xp, level, completed_tasks, total_earned) VALUES (?, ?, ?, ?, ?, ?)',
            { char.id, jobId, xp, level, tasks, earned }
        )
    end
end

function SunsetJobs_PayReward(source, jobId, amount, reason, countTask)
    local char = getChar(source)
    if not char or not amount or amount <= 0 then return false end

    exports.sunset_core:AddMoney(source, 'cash', amount, reason or ('job_' .. jobId))
    exports.sunset_core:AddXP(source, math.max(1, math.floor(amount / 20)))

    local row = MySQL.single.await(
        'SELECT completed_tasks, total_earned FROM job_progress WHERE character_id = ? AND job_id = ?',
        { char.id, jobId }
    )
    local tasks = (row and row.completed_tasks or 0) + (countTask and 1 or 0)
    local earned = (row and row.total_earned or 0) + amount

    if row then
        MySQL.update.await(
            'UPDATE job_progress SET completed_tasks = ?, total_earned = ? WHERE character_id = ? AND job_id = ?',
            { tasks, earned, char.id, jobId }
        )
    else
        MySQL.insert.await(
            'INSERT INTO job_progress (character_id, job_id, xp, level, completed_tasks, total_earned) VALUES (?, ?, 0, 1, ?, ?)',
            { char.id, jobId, tasks, earned }
        )
    end
    return true
end

function SunsetJobs_StartSession(source, jobId, data)
    if Sessions[source] then
        return nil, 'Already on a work shift'
    end
    local currentJob = charJob(source)
    if currentJob ~= jobId then
        return nil, 'You are not employed as ' .. (Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId)
    end

    local cfg = Sunset.GetJobConfig(jobId)
    if not cfg then return nil, 'Job not configured' end

    sessionSeq = sessionSeq + 1
    local session = {
        id = sessionSeq,
        jobId = jobId,
        state = 'STARTING',
        token = ('%s-%s-%s'):format(jobId, source, sessionSeq),
        startedAt = os.time(),
        timeoutAt = os.time() + (cfg.timeoutSec or 1800),
        data = data or {},
        vehicleNetId = nil,
        trailerNetId = nil,
    }
    Sessions[source] = session
    TriggerClientEvent('sunset:jobs:sessionStarted', source, jobId, session)
    return session
end

local function fetchProgress(charId)
    local rows = MySQL.query.await(
        'SELECT job_id, xp, level, completed_tasks, total_earned FROM job_progress WHERE character_id = ?',
        { charId }
    ) or {}
    local map = {}
    for _, row in ipairs(rows) do
        map[row.job_id] = {
            xp = row.xp,
            level = row.level,
            completedTasks = row.completed_tasks,
            totalEarned = row.total_earned,
            xpToNext = xpForLevel(row.level) - row.xp,
        }
    end
    return map
end

exports.sunset_core:RegisterCallback('sunset:jobs:getPanelData', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end

    local jobId, jobGrade = Sunset.GetCharacterJob(char)
    local progress = fetchProgress(char.id)
    local session = Sessions[source]

    local jobs = {}
    for id, def in pairs(Sunset.CivilianJobs or {}) do
        if id ~= 'unemployed' then
            local cfg = Sunset.GetJobConfig(id)
            jobs[#jobs + 1] = {
                id = id,
                label = def.label,
                description = def.description or '',
                salary = def.grades and def.grades[0] and def.grades[0].salary or 0,
                progress = progress[id],
                help = cfg and cfg.help or '',
            }
        end
    end
    table.sort(jobs, function(a, b) return a.label < b.label end)

    local currentJobObj = nil
    if jobId and jobId ~= 'unemployed' then
        currentJobObj = {
            id = jobId,
            label = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId,
        }
    end

    for _, row in ipairs(jobs) do
        local prog = progress[row.id]
        if prog then
            row.level = prog.level
            row.xp = prog.xp
            row.xpNext = prog.xpToNext or xpForLevel(prog.level)
        end
    end

    return {
        currentJob = currentJobObj,
        currentJobLabel = currentJobObj and currentJobObj.label or 'Unemployed',
        jobGrade = jobGrade,
        session = session and {
            jobId = session.jobId,
            state = session.state,
            data = session.data,
        } or nil,
        jobs = jobs,
        progress = progress,
    }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:getSkills', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local progress = fetchProgress(char.id)
    local skills = {}
    for jobId, prog in pairs(progress) do
        skills[#skills + 1] = {
            id = jobId,
            label = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId,
            level = prog.level,
            xp = prog.xp,
            xpNext = prog.xpToNext or xpForLevel(prog.level),
        }
    end
    table.sort(skills, function(a, b) return a.label < b.label end)
    return { progress = progress, skills = skills }
end)

exports.sunset_core:RegisterCallback('sunset:jobs:cancelWork', function(source)
    local session = Sessions[source]
    if not session then return nil, 'No active shift' end
    SunsetJobs_ClearSession(source, 'CANCELLED', 'Cancelled by player')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:jobs:registerVehicle', function(source, vehicleNetId, trailerNetId)
    local session, err = SunsetJobs_RequireSession(source, nil, { 'STARTING', 'ACTIVE', 'RETURNING' })
    if not session then return nil, err end
    session.vehicleNetId = tonumber(vehicleNetId)
    session.trailerNetId = trailerNetId and tonumber(trailerNetId) or nil
    if session.state == 'STARTING' then
        SunsetJobs_SetState(source, 'ACTIVE')
    end
    return true
end)

exports.sunset_core:RegisterCallback('sunset:jobs:vehicleLost', function(source)
    local session = Sessions[source]
    if not session then return nil, 'No session' end
    SunsetJobs_ClearSession(source, 'FAILED', 'Work vehicle destroyed')
    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Sessions[src] then
        Sessions[src] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for src, session in pairs(Sessions) do
            if session.timeoutAt and now > session.timeoutAt then
                SunsetJobs_ClearSession(src, 'FAILED', 'Shift timed out')
            end
        end
    end
end)
