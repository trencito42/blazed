local function openClanPanel()
    local data, err = Sunset.AwaitCallback('sunset:clanDashboard')
    if not data then
        return exports.sunset_ui:Notify(err or 'Clan panel could not be opened.', 'error', 7000)
    end
    exports.sunset_ui:Send('clanPanelShow', data)
    exports.sunset_ui:SetFocus(true, true)
end

RegisterCommand('clan', openClanPanel, false)
TriggerEvent('chat:addSuggestion', '/clan', 'Open your clan page — members, settings, and management')

RegisterCommand('clans', function()
    local data, err = Sunset.AwaitCallback('sunset:clanDirectory')
    if not data then
        return exports.sunset_ui:Notify(err or 'Clan directory could not be opened.', 'error', 7000)
    end
    exports.sunset_ui:Send('clanDirectoryShow', { clans = data })
    exports.sunset_ui:SetFocus(true, true)
end, false)
TriggerEvent('chat:addSuggestion', '/clans', 'Browse all server clans')

RegisterCommand('acceptclan', function()
    local data, err = Sunset.AwaitCallback('sunset:clanAcceptInvite')
    if not data then
        return exports.sunset_ui:Notify(err or 'Could not accept clan invite.', 'error', 8000)
    end
    exports.sunset_ui:Notify(('You joined %s.'):format(data.name or 'the clan'), 'success', 8000)
    exports.sunset_ui:Send('clanPanelShow', data)
    exports.sunset_ui:SetFocus(true, true)
end, false)
TriggerEvent('chat:addSuggestion', '/acceptclan', 'Accept a pending clan invitation')

RegisterCommand('declineclan', function()
    local ok, err = Sunset.AwaitCallback('sunset:clanDeclineInvite')
    if not ok then
        return exports.sunset_ui:Notify(err or 'Could not decline invite.', 'error', 7000)
    end
    exports.sunset_ui:Notify('Clan invite declined.', 'info')
end, false)
TriggerEvent('chat:addSuggestion', '/declineclan', 'Decline a pending clan invitation')

AddEventHandler('sunset:nui:clanManage', function(data)
    data = data or {}
    local action = data.action
    local ok, err

    if action == 'create' then
        ok, err = Sunset.AwaitCallback('sunset:clanCreate', data)
        if ok then
            exports.sunset_ui:Notify(('Clan %s created.'):format(ok.name or ''), 'success', 8000)
            exports.sunset_ui:Send('clanPanelShow', ok)
            return
        end
    else
        ok, err = Sunset.AwaitCallback('sunset:clanManage', data)
        if ok then
            if action == 'invite' then
                exports.sunset_ui:Notify('Clan invite sent.', 'success')
            elseif action == 'kick' then
                exports.sunset_ui:Notify('Member removed from clan.', 'success')
            elseif action == 'promote' then
                exports.sunset_ui:Notify('Member rank updated.', 'success')
            elseif action == 'motd' then
                exports.sunset_ui:Notify('Clan MOTD updated.', 'success')
            elseif action == 'settings' then
                exports.sunset_ui:Notify('Clan settings saved.', 'success')
            elseif action == 'leave' then
                exports.sunset_ui:Notify('You left the clan.', 'info')
            elseif action == 'dissolve' then
                exports.sunset_ui:Notify('Clan dissolved.', 'warning')
            end
            exports.sunset_ui:Send('clanPanelShow', ok)
            return
        end
    end

    exports.sunset_ui:Notify(err or 'Clan action failed.', 'error', 8000)
end)
