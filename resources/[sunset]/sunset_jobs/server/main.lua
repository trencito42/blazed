local function isLegacyMigrated(jobId)
    if GetResourceState('sunset_jobcreator') ~= 'started' then return false end
    local mig = exports.sunset_jobcreator:GetMigrationTarget(jobId)
    return mig and exports.sunset_jobcreator:IsCreatorJob(mig)
end

local function ensureCreatorJobsRegistered()
    if GetResourceState('sunset_jobcreator') ~= 'started' then return end
    pcall(function()
        exports.sunset_jobcreator:EnsureCivilianJobsRegistered()
    end)
end

local function resolveHireJobId(jobId)
    ensureCreatorJobsRegistered()
    if GetResourceState('sunset_jobcreator') ~= 'started' then return jobId end
    local legacy = exports.sunset_jobcreator:GetLegacyJobId(jobId)
    if legacy then return legacy end
    return jobId
end

local function resolveCreatorJobId(jobId)
    if GetResourceState('sunset_jobcreator') ~= 'started' then return nil end
    if exports.sunset_jobcreator:IsCreatorJob(jobId) then
        return jobId
    end
    local mig = exports.sunset_jobcreator:GetMigrationTarget(jobId)
    if mig and exports.sunset_jobcreator:IsCreatorJob(mig) then
        return mig
    end
    return nil
end

local function buildJobCenterJobs(center)
    local jobs = {}
    local seen = {}

    local function add(job)
        if not job or not job.id or seen[job.id] then return end
        seen[job.id] = true
        jobs[#jobs + 1] = job
    end

    -- Published creator jobs first
    if GetResourceState('sunset_jobcreator') == 'started' then
        for _, j in ipairs(exports.sunset_jobcreator:GetPublishedForHire()) do
            if j.id ~= 'unemployed' then add(j) end
        end
    end

    -- All civilian jobs (type == 'civilian') from global config, excluding unemployed/criminal
    for jobId, def in pairs(Sunset.CivilianJobs or {}) do
        if jobId ~= 'unemployed' and (def.type == 'civilian' or not def.type) and not seen[jobId] then
            if not isLegacyMigrated(jobId) then
                add({
                    id = jobId,
                    label = def.label or jobId,
                    description = def.description or '',
                    salary = def.grades and def.grades[0] and def.grades[0].salary,
                    npcCoords = def.npcCoords,
                })
            end
        end
    end

    -- Any extra jobs explicitly listed in the center's jobs array
    for _, j in ipairs(center.jobs or {}) do
        if j.id == 'unemployed' or seen[j.id] or isLegacyMigrated(j.id) then goto continue end
        local def = Sunset.CivilianJobs[j.id]
        if def and def.type == 'civilian' then
            add({
                id = j.id,
                label = j.label or def.label or j.id,
                description = def.description or '',
                salary = def.grades and def.grades[0] and def.grades[0].salary,
                npcCoords = def.npcCoords,
            })
        end
        ::continue::
    end

    table.sort(jobs, function(a, b)
        if a.id == 'unemployed' then return true end
        if b.id == 'unemployed' then return false end
        return a.label < b.label
    end)
    return jobs
end

local function quitCivilianJob(source, reason)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and select it again.' end

    local currentJob = select(1, Sunset.GetCharacterJob(char))
    if not currentJob or currentJob == 'unemployed' then
        return nil, 'You do not have a civilian job to quit.'
    end

    if SunsetJobs_ClearSession then
        SunsetJobs_ClearSession(source, 'CANCELLED', reason or 'Civilian job resigned')
    end
    if GetResourceState('sunset_jobcreator') == 'started' then
        pcall(function() exports.sunset_jobcreator:CancelJob(source) end)
    end
    TriggerClientEvent('sunset:jobs:forceClearHud', source)
    if not exports.sunset_core:SetJob(source, 'unemployed', 0) then
        return nil, 'Could not clear your civilian job — try again after ending your current shift.'
    end
    exports.sunset_core:CommandReply(source,
        'Civilian job resigned. Your faction membership is unchanged.', 'success')
    return true
end

exports.sunset_core:RegisterCallback('sunset:jobs:getJobCenterJobs', function(source, centerId)
    local center = Sunset.JobCenters and Sunset.JobCenters[centerId]
    if not center then return nil, 'Unknown job center.' end
    return buildJobCenterJobs(center)
end)

local function hireCivilianJob(source, jobId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then
        print(('[sunset:hireJob] FAIL src=%s jobId=%s reason=character_not_loaded'):format(source, tostring(jobId)))
        return nil, 'Your character is not loaded. Reconnect and select it again.'
    end

    local requestedJob = jobId
    jobId = resolveHireJobId(jobId)
    local currentJob = select(1, Sunset.GetCharacterJob(char))
    print(('[sunset:hireJob] src=%s request=%s resolved=%s current=%s charId=%s'):format(
        source, tostring(requestedJob), tostring(jobId), tostring(currentJob), tostring(char.id)))
    ensureCreatorJobsRegistered()

    local creatorId = resolveCreatorJobId(jobId)
    local isCreator = creatorId ~= nil or (GetResourceState('sunset_jobcreator') == 'started' and exports.sunset_jobcreator:IsCreatorJob(jobId))
    if not (Sunset.CivilianJobs and Sunset.CivilianJobs[jobId]) and not isCreator then
        return nil, 'That is not a valid civilian job. Factions require a leader invitation.'
    end

    if jobId == 'unemployed' then
        return quitCivilianJob(source, 'Resigned at Job Center')
    end

    if currentJob == jobId or resolveHireJobId(currentJob) == jobId then
        local label = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId
        return nil, ('You already work as %s.'):format(label)
    end

    if currentJob ~= 'unemployed' then
        if SunsetJobs_ClearSession then
            SunsetJobs_ClearSession(source, 'CANCELLED', 'Changed civilian job')
        end
        if GetResourceState('sunset_jobcreator') == 'started' then
            pcall(function() exports.sunset_jobcreator:CancelJob(source) end)
        end
        TriggerClientEvent('sunset:jobs:forceClearHud', source)
        local current = Sunset.CivilianJobs[currentJob]
        exports.sunset_core:CommandReply(source,
            ('Left %s.'):format(current and current.label or currentJob), 'info')
    end

    local setOk = exports.sunset_core:SetJob(source, jobId, 0)
    if not setOk then
        print(('[sunset:hireJob] FAIL src=%s jobId=%s reason=set_job_failed'):format(source, tostring(jobId)))
        return nil, 'Could not assign the job — try reconnecting or contact staff.'
    end
    print(('[sunset:hireJob] OK src=%s jobId=%s'):format(source, tostring(jobId)))

    local hiredLabel = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId
    exports.sunset_core:CommandReply(source,
        ('Hired as %s. Use /work to start.'):format(hiredLabel), 'success')
    local coords = nil
    if creatorId then
        coords = exports.sunset_jobcreator:GetJobWorkCoords(creatorId)
    elseif GetResourceState('sunset_jobcreator') == 'started' then
        coords = exports.sunset_jobcreator:GetJobWorkCoords(jobId)
    end
    TriggerClientEvent('sunset:jobs:waypointToWork', source, jobId, coords)
    return true
end

exports('HireCivilianJob', hireCivilianJob)

exports.sunset_core:RegisterCallback('sunset:hireJob', function(source, jobId)
    return hireCivilianJob(source, jobId)
end)

exports.sunset_core:RegisterCallback('sunset:quitCivilianJob', function(source)
    return quitCivilianJob(source, 'Civilian job resigned')
end)

local function reply(source, message, kind)
    if source == 0 then
        print(message)
        return
    end
    exports.sunset_core:CommandReply(source, message, kind or 'info')
end

local function requireAdmin(source, cmd)
    if source == 0 then return true end
    if exports.sunset_admin:IsAdmin(source, 3) then return true end
    exports.sunset_core:CommandDenyAdmin(source, cmd)
    return false
end

local function resolvePlayer(source, arg)
    local target = tonumber(arg)
    if target and GetPlayerName(target) then return target end

    local account = MySQL.single.await('SELECT id, username FROM accounts WHERE LOWER(username) = LOWER(?)', { arg })
    if not account then return nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local player = exports.sunset_core:GetPlayer(src)
        if player and player.account_id == account.id then return src end
    end
    return nil
end

local function listCivilianJobs()
    return exports.sunset_core:CommandListKeys(Sunset.CivilianJobs, 12)
end

local function listFactions()
    return exports.sunset_core:CommandListKeys(Sunset.Factions, 12)
end

local function runSetJob(source, args)
    if not requireAdmin(source, 'setjob') then return end

    local targetArg = args[1]
    local jobId = args[2] and string.lower(args[2]) or nil
    local grade = tonumber(args[3]) or 0
    if not targetArg or not jobId then
        reply(source,
            'Usage: /setjob [server id|username] [job] [grade] — jobs: ' .. listCivilianJobs(),
            'error')
        return
    end

    local target = resolvePlayer(source, targetArg)
    if not target then
        exports.sunset_core:CommandPlayerNotFound(source, targetArg)
        return
    end

    if not exports.sunset_core:GetCharacter(target) then
        exports.sunset_core:CommandNoCharacter(source, target)
        return
    end

    if Sunset.Factions[jobId] then
        reply(source,
            ('"%s" is a faction, not a civilian job. Use /setfaction %s %s [grade].'):format(jobId, targetArg, jobId),
            'error')
        return
    end

    ensureCreatorJobsRegistered()
    jobId = resolveHireJobId(jobId)

    local isCreator = resolveCreatorJobId(jobId) ~= nil
    if not Sunset.CivilianJobs[jobId] and not isCreator then
        reply(source,
            ('Unknown civilian job "%s". Valid jobs: %s'):format(jobId, listCivilianJobs()),
            'error')
        return
    end

    if not exports.sunset_core:SetJob(target, jobId, grade) then
        reply(source,
            ('Grade %d is invalid for %s. Most civilian jobs use grade 0.'):format(grade, jobId),
            'error')
        return
    end

    local label = Sunset.CivilianJobs[jobId] and Sunset.CivilianJobs[jobId].label or jobId
    reply(target, ('Your civilian job was set to %s.'):format(label), 'success')
    if source ~= 0 then
        reply(source, ('Set %s (#%d) civilian job to %s (grade %d).'):format(
            GetPlayerName(target) or '?', target, label, grade), 'success')
    end
end

local function runSetFaction(source, args)
    if not requireAdmin(source, 'setfaction') then return end

    local targetArg = args[1]
    local factionId = args[2] and string.lower(args[2]) or nil
    local grade = tonumber(args[3]) or 0
    if not targetArg or not factionId then
        reply(source,
            'Usage: /setfaction [server id|username] [faction|none] [grade] — factions: ' .. listFactions(),
            'error')
        return
    end

    local target = resolvePlayer(source, targetArg)
    if not target then
        exports.sunset_core:CommandPlayerNotFound(source, targetArg)
        return
    end

    if not exports.sunset_core:GetCharacter(target) then
        exports.sunset_core:CommandNoCharacter(source, target)
        return
    end

    if factionId == 'none' or factionId == 'clear' then
        exports.sunset_core:SetFaction(target, nil, 0)
        reply(target, 'Your faction membership was cleared.', 'success')
        if source ~= 0 then
            reply(source, ('Cleared faction for %s (#%d).'):format(GetPlayerName(target) or '?', target), 'success')
        end
        return
    end

    if not Sunset.Factions[factionId] then
        reply(source,
            ('Unknown faction "%s". Valid factions: %s'):format(factionId, listFactions()),
            'error')
        return
    end

    if not exports.sunset_core:SetFaction(target, factionId, grade) then
        local faction = Sunset.Factions[factionId]
        reply(source,
            ('Grade %d does not exist for %s. Check faction grades in config.'):format(
                grade, faction and faction.label or factionId),
            'error')
        return
    end

    local label = Sunset.Factions[factionId].label
    reply(target, ('Your faction was set to %s.'):format(label), 'success')
    if source ~= 0 then
        reply(source, ('Set %s (#%d) faction to %s (grade %d).'):format(
            GetPlayerName(target) or '?', target, label, grade), 'success')
    end
end

RegisterCommand('setjob', function(source, args) runSetJob(source, args) end, false)
RegisterCommand('setfaction', function(source, args) runSetFaction(source, args) end, false)

function ExecutePlayerCommand(source, name, args)
    name = string.lower(tostring(name or ''))
    if name == 'setjob' then runSetJob(source, args or {}) return true end
    if name == 'setfaction' then runSetFaction(source, args or {}) return true end
    return false
end

exports('ExecutePlayerCommand', ExecutePlayerCommand)
