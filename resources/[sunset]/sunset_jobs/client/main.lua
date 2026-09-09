AddEventHandler('sunset:world:openJobCenter', function(centerId, center)
    if IsNuiFocused() then return end
    local jobs, err = Sunset.AwaitCallback('sunset:jobs:getJobCenterJobs', centerId)
    if not jobs then
        exports.sunset_ui:Notify(err or 'Could not load jobs', 'error')
        return
    end
    exports.sunset_ui:Send('jobCenterShow', {
        centerId = centerId,
        label = center.label,
        jobs = jobs,
    })
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:nui:jobCenterHire', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:hireJob', data.jobId)
    if ok then
        if data.jobId ~= 'unemployed' then
            exports.sunset_ui:Notify('Esti acum angajat ca ' .. (data.jobLabel or data.jobId), 'success', 6000)
        else
            exports.sunset_ui:Notify('Te-ai dat demisie.', 'info', 4000)
        end
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Send('jobCenterHide', {})
    else
        local errMsg = err or 'Nu s-a putut finaliza angajarea.'
        -- "already work" = user already has this job; treat as info, not error
        local kind = (errMsg:find('already work') or errMsg:find('You already work')) and 'info' or 'error'
        if kind == 'info' then
            errMsg = 'Esti deja angajat la acest job! Foloseste /work sa incepi tura.'
        end
        exports.sunset_ui:Notify(errMsg, kind)
        -- nu inchidem UI-ul — userul poate incerca alt job sau apasa ESC
    end
end)

AddEventHandler('sunset:nui:jobCenterClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('jobCenterHide', {})
end)

AddEventHandler('sunset:nui:jobCenterWaypoint', function(data)
    if data and data.x and data.y then
        SetNewWaypoint(data.x, data.y)
        exports.sunset_ui:Notify('Waypoint setat pe harta!', 'info', 3000)
    end
end)

RegisterCommand('quitjob', function()
    CreateThread(function()
        if Sunset.JobClient then
            if Sunset.JobClient.clearWorkHud then
                Sunset.JobClient.clearWorkHud()
            elseif Sunset.JobClient.cleanup then
                Sunset.JobClient.cleanup()
            end
        end
        local ok, err = Sunset.AwaitCallback('sunset:quitCivilianJob')
        if not ok then exports.sunset_ui:Notify(err or 'Could not quit civilian job', 'error') end
    end)
end, false)
