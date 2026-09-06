AddEventHandler('sunset:world:openJobCenter', function(centerId, center)
    if IsNuiFocused() then return end
    exports.sunset_ui:Send('jobCenterShow', {
        centerId = centerId,
        label = center.label,
        jobs = center.jobs or {},
    })
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:nui:jobCenterHire', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:hireJob', data.jobId)
    if ok then
        if data.jobId ~= 'unemployed' then
            exports.sunset_ui:Notify('You are now employed as ' .. (data.jobLabel or data.jobId), 'success')
        end
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Send('jobCenterHide', {})
    else
        exports.sunset_ui:Notify(err or 'Could not get job', 'error')
    end
end)

AddEventHandler('sunset:nui:jobCenterClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('jobCenterHide', {})
end)

RegisterCommand('quitjob', function()
    CreateThread(function()
        if Sunset.JobClient and Sunset.JobClient.cleanup then
            Sunset.JobClient.cleanup()
        end
        local ok, err = Sunset.AwaitCallback('sunset:quitCivilianJob')
        if not ok then exports.sunset_ui:Notify(err or 'Could not quit civilian job', 'error') end
    end)
end, false)
