local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

RegisterCommand('stabilize', function(_, args)
    local target = tonumber(args[1])
    if not target then return notify('Usage: /stabilize [id]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:emsStabilize', target)
    if not ok then notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('heal', function(_, args)
    local target = tonumber(args[1])
    local ok, err = Sunset.AwaitCallback('sunset:emsHeal', target)
    if not ok then notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('revive', function(_, args)
    local target = tonumber(args[1])
    if not target then return notify('Usage: /revive [id]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:emsRevive', target)
    if not ok then notify(err or 'Failed', 'error') end
end, false)

CreateThread(function()
    Wait(3500)
    TriggerEvent('chat:addSuggestion', '/stabilize', 'Stabilize downed patient (EMS/LSFD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/firecalls', 'List active fire incidents (LSFD on duty)')
end)
