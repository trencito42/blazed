local panelOpen = false

local function setFocus(on)
    exports.sunset_ui:SetFocus(on, on)
end

RegisterNetEvent('sunset:jobcreator:openPanel', function()
    if panelOpen then return end
    local data, err = Sunset.AwaitCallback('sunset:jobcreator:list')
    if not data then
        exports.sunset_ui:Notify(err or 'Could not open Job Creator', 'error')
        return
    end
    panelOpen = true
    setFocus(true)
    exports.sunset_ui:Send('jobCreatorShow', data)
end)

RegisterNetEvent('sunset:jobcreator:definitionsUpdated', function()
    if not panelOpen then return end
    local data = Sunset.AwaitCallback('sunset:jobcreator:list')
    if data then exports.sunset_ui:Send('jobCreatorUpdate', data) end
end)

AddEventHandler('sunset:jobcreator:nui:close', function()
    panelOpen = false
    setFocus(false)
    exports.sunset_ui:Send('jobCreatorHide', {})
end)

AddEventHandler('sunset:jobcreator:nui:test', function(jobId)
    panelOpen = false
    setFocus(false)
    exports.sunset_ui:Send('jobCreatorHide', {})
    JCRuntime_StartWork(jobId)
end)

AddEventHandler('sunset:jobcreator:nui:place', function()
    panelOpen = false
    setFocus(false)
    exports.sunset_ui:Send('jobCreatorHide', {})
    JCPlacement_Start(function(point)
        panelOpen = true
        setFocus(true)
        local data = Sunset.AwaitCallback('sunset:jobcreator:list')
        exports.sunset_ui:Send('jobCreatorShow', data or { jobs = {} })
        exports.sunset_ui:Send('jobCreatorPlacement', { point = point })
    end)
end)
