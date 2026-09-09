local JC = Sunset.JobClient

-- Keep in sync with sunset_jobcreator/shared/migrations.lua (no client export needed).
local CREATOR_MIGRATIONS = {
    trucker = 'jc_tpl_route',
    courier = 'jc_tpl_courier',
    garbage = 'jc_tpl_garbage',
    fisherman = 'jc_tpl_gather',
    lumberjack = 'jc_tpl_lumber',
}

local function jobcreatorCall(fn)
    if GetResourceState('sunset_jobcreator') ~= 'started' then return nil end
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local LEGACY_STARTERS = {
    trucker = function() Sunset.Jobs.StartTrucker() end,
    garbage = function() Sunset.Jobs.StartGarbage() end,
    courier = function() Sunset.Jobs.StartCourier() end,
    fisherman = function() Sunset.Jobs.StartFisherman() end,
    mechanic = function() Sunset.Jobs.StartMechanic() end,
}

local function startCreatorWork(jobId)
    if GetResourceState('sunset_jobcreator') ~= 'started' then return false end
    local target = CREATOR_MIGRATIONS[jobId] or jobId
    if jobcreatorCall(function() return exports.sunset_jobcreator:IsCreatorJob(target) end) then
        jobcreatorCall(function() exports.sunset_jobcreator:StartWork() end)
        return true
    end
    return false
end

local function starterFor(jobId)
    if startCreatorWork(jobId) then
        return function() end
    end
    return LEGACY_STARTERS[jobId]
end

local STARTERS = {
    trucker = function() starterFor('trucker')() end,
    garbage = function() starterFor('garbage')() end,
    courier = function() starterFor('courier')() end,
    fisherman = function() starterFor('fisherman')() end,
    mechanic = function() LEGACY_STARTERS.mechanic() end,
}

local function openJobsPanel()
    if IsNuiFocused() then return end
    local data, err = Sunset.AwaitCallback('sunset:jobs:getPanelData')
    if not data then
        JC.notify(err or 'Could not load jobs', 'error')
        return
    end
    TriggerEvent('sunset:ui:jobs', data)
end

local function showSkills()
    local data, err = Sunset.AwaitCallback('sunset:jobs:getSkills')
    if not data then
        JC.notify(err or 'Could not load skills', 'error')
        return
    end
    TriggerEvent('sunset:ui:skills', { skills = data.skills or {} })
end

local function showJobHelp()
    local jobId = JC.getCharacterJob()
    local cfg = Sunset.GetJobConfig(jobId)
    local def = Sunset.CivilianJobs[jobId]
    if not cfg or not def or jobId == 'unemployed' then
        JC.notify('Get a job at the Job Center or use /jobs', 'info')
        return
    end
    JC.notify(def.label .. ': ' .. (cfg.help or def.description or ''), 'info', 8000)
end

local function startWork()
    if JC.state ~= 'IDLE' then
        if not JC.syncSessionState() then
            -- stale client state cleared
        elseif JC.jobId == 'fisherman' then
            if Sunset.Jobs and Sunset.Jobs.EnsureFishermanShift then
                Sunset.Jobs.EnsureFishermanShift()
            end
            JC.workFeedback('Fisherman shift is already active — stand in a blue marker and press E.', 'info')
            return
        elseif JC.state ~= 'IDLE' then
            JC.workFeedback('Already on a shift — finish or /work cancel', 'error')
            return
        end
    end

    local jobId = JC.getCharacterJob()
    if jobId == 'unemployed' then
        JC.workFeedback('You need a job first — visit the Job Center or /jobs', 'error')
        return
    end

    local starter = STARTERS[jobId]
    if not starter and jobcreatorCall(function() return exports.sunset_jobcreator:IsCreatorJob(jobId) end) then
        starter = function()
            jobcreatorCall(function() exports.sunset_jobcreator:StartWork() end)
        end
    end
    if not starter then
        JC.workFeedback('No work loop for your job yet', 'error')
        return
    end

    local def = Sunset.CivilianJobs[jobId]
    JC.workFeedback(('Starting %s shift...'):format(def and def.label or jobId), 'info')
    local ok, err = pcall(starter)
    if not ok then
        JC.workFeedback('Work command failed — try again or contact staff.', 'error')
        print(('[sunset_jobs] /work error for %s: %s'):format(jobId, tostring(err)))
    end
end

RegisterCommand('jobs', function()
    openJobsPanel()
end, false)

-- DEBUG: test hire direct fara NUI
RegisterCommand('testangajare', function(_, args)
    CreateThread(function()
        local jobId = (args and args[1]) or 'fisherman'
        print('[testangajare] incep test pentru job: ' .. tostring(jobId))
        local ok, err = Sunset.AwaitCallback('sunset:hireJob', jobId)
        print('[testangajare] ok=' .. tostring(ok) .. ' err=' .. tostring(err))
        if ok then
            exports.sunset_ui:Notify('TEST SUCCES: angajat ca ' .. jobId, 'success', 8000)
        else
            exports.sunset_ui:Notify('TEST FAIL: ' .. tostring(err or 'nil'), 'error', 8000)
        end
    end)
end, false)

RegisterCommand('work', function(_, args)
    local sub = args[1] and string.lower(args[1])
    if sub == 'cancel' or sub == 'stop' then
        local cancelled = jobcreatorCall(function()
            if exports.sunset_jobcreator:IsSessionActive() then
                exports.sunset_jobcreator:CancelWork()
                return true
            end
            return false
        end)
        if cancelled then
            JC.cleanup()
            JC.hideObjective()
            JC.workFeedback('Shift cancelled', 'info')
            return
        end
        local charJob = JC.getCharacterJob()
        if charJob and jobcreatorCall(function() return exports.sunset_jobcreator:IsCreatorJob(charJob) end) then
            jobcreatorCall(function() exports.sunset_jobcreator:CancelWork() end)
        elseif JC.jobId == 'mechanic' and JC.state ~= 'IDLE' then
            Sunset.Jobs.EndMechanic()
        else
            Sunset.AwaitCallback('sunset:jobs:cancelWork')
        end
        JC.cleanup()
        JC.hideObjective()
        JC.workFeedback('Shift cancelled', 'info')
        return
    end
    startWork()
end, false)

RegisterCommand('jobhelp', function()
    showJobHelp()
end, false)

RegisterCommand('skills', function()
    showSkills()
end, false)

AddEventHandler('sunset:nui:jobsClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('jobsHide', {})
end)

AddEventHandler('sunset:nui:jobsStartWork', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('jobsHide', {})
    startWork()
end)

AddEventHandler('sunset:ui:jobsSelectRequest', function(data)
    if not data or not data.jobId then return end
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('jobsHide', {})
    local ok, err = Sunset.AwaitCallback('sunset:hireJob', data.jobId)
    if ok then
        JC.notify('You are now employed as ' .. (data.jobLabel or data.jobId), 'success')
    else
        JC.notify(err or 'Could not get job', 'error')
    end
end)

AddEventHandler('sunset:nui:jobsCancelWork', function()
    if JC.jobId == 'mechanic' and JC.state ~= 'IDLE' then
        Sunset.Jobs.EndMechanic()
    else
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
    end
    JC.cleanup()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('jobsHide', {})
end)

TriggerEvent('chat:addSuggestion', '/jobs', 'Open jobs panel')
TriggerEvent('chat:addSuggestion', '/work', 'Start your civilian job shift', {
    { name = 'cancel', help = 'Cancel current shift' },
})
TriggerEvent('chat:addSuggestion', '/jobhelp', 'Help for your current job')
TriggerEvent('chat:addSuggestion', '/skills', 'Show job skill levels')

CreateThread(function()
    local depotLabels = {
        trucker = 'Trucker Depot',
        garbage = 'Garbage Depot',
        courier = 'Courier Warehouse',
        mechanic = 'Mechanic Depot',
    }
    for jobId, cfg in pairs(Sunset.JobsConfig or {}) do
        local depot = cfg.depot or cfg.warehouse
        if depot and depot.coords and depot.blip then
            local blip = AddBlipForCoord(depot.coords.x, depot.coords.y, depot.coords.z)
            SetBlipSprite(blip, depot.blip.sprite or 1)
            SetBlipColour(blip, depot.blip.color or 0)
            SetBlipScale(blip, depot.blip.scale or 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(depotLabels[jobId] or ((cfg.label or jobId) .. ' Work'))
            EndTextCommandSetBlipName(blip)
        end
    end
    local fishCfg = Sunset.GetJobConfig('fisherman')
    if fishCfg and fishCfg.sellPoint then
        local sp = fishCfg.sellPoint
        local blip = AddBlipForCoord(sp.coords.x, sp.coords.y, sp.coords.z)
        SetBlipSprite(blip, sp.blip.sprite or 280)
        SetBlipColour(blip, sp.blip.color or 46)
        SetBlipScale(blip, sp.blip.scale or 0.75)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Fish Buyer')
        EndTextCommandSetBlipName(blip)
    end
end)
