local function openClanPanel()
    local data, err = Sunset.AwaitCallback('sunset:clanDashboard')
    if not data then
        return exports.sunset_ui:Notify(err or 'Clan panel could not be opened.', 'error', 7000)
    end
    exports.sunset_ui:Send('clanPanelShow', data)
end

local function openClanDirectory()
    local data, err = Sunset.AwaitCallback('sunset:clanDirectory')
    if not data then
        return exports.sunset_ui:Notify(err or 'Clan directory could not be opened.', 'error', 7000)
    end
    exports.sunset_ui:Send('clanDirectoryShow', { clans = data })
end

RegisterCommand('clan', openClanPanel, false)
RegisterCommand('group', openClanPanel, false)
TriggerEvent('chat:addSuggestion', '/clan', 'Open your clan unit panel — crew, command, identity')
TriggerEvent('chat:addSuggestion', '/group', 'Same as /clan — clan unit panel')

RegisterCommand('clans', openClanDirectory, false)
TriggerEvent('chat:addSuggestion', '/clans', 'Browse all server clans')

RegisterNetEvent('sunset:clans:openDashboard', openClanPanel)
RegisterNetEvent('sunset:clans:openDirectory', openClanDirectory)

AddEventHandler('sunset:nui:clanPanelsReady', function()
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:nui:clanBrowse', function()
    local data, err = Sunset.AwaitCallback('sunset:clanDirectory')
    if not data then
        exports.sunset_ui:Send('clanBrowseInline', { clans = {}, error = err })
        return exports.sunset_ui:Notify(err or 'Clan directory could not be loaded.', 'error', 7000)
    end
    exports.sunset_ui:Send('clanBrowseInline', { clans = data })
end)

AddEventHandler('sunset:nui:clanProfile', function(data)
    local clanId = tonumber(data and data.clanId)
    local profile, err = Sunset.AwaitCallback('sunset:clanProfile', clanId)
    if not profile then
        exports.sunset_ui:Notify(err or 'Could not load clan profile.', 'error', 7000)
        return
    end
    exports.sunset_ui:Send('clanProfileShow', profile)
end)

RegisterCommand('cmotd', function(_, args)
    local msg = table.concat(args, ' ')
    if msg == '' then
        local data, err = Sunset.AwaitCallback('sunset:clanGetMotd')
        if not data then return exports.sunset_ui:Notify(err or 'Clan MOTD could not be loaded.', 'error') end
        exports.sunset_ui:Send('chatMessage', {
            id = 0,
            type = 'clan_motd',
            clanTag = data.tag,
            clanName = data.name,
            name = data.name,
            message = data.message ~= '' and data.message or 'No message of the day has been set.',
            command = '/cmotd',
            time = '',
        })
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:clanManage', { action = 'motd', message = msg })
    if ok then exports.sunset_ui:Notify('Clan MOTD updated', 'success')
    else exports.sunset_ui:Notify(err or 'MOTD update failed. Officers can set it with /cmotd [message].', 'error') end
end, false)
TriggerEvent('chat:addSuggestion', '/cmotd', 'Read clan MOTD, or set it if you are an officer', { { name = 'message', help = 'optional new MOTD' } })

RegisterCommand('acceptclan', function()
    local data, err = Sunset.AwaitCallback('sunset:clanAcceptInvite')
    if not data then
        return exports.sunset_ui:Notify(err or 'Could not accept clan invite.', 'error', 8000)
    end
    exports.sunset_ui:Notify(('You joined %s.'):format(data.name or 'the clan'), 'success', 8000)
    exports.sunset_ui:Send('clanPanelShow', data)
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
TriggerEvent('chat:addSuggestion', '/c', 'Clan chat — visible to your clan members only')

local function clanWarnCommand(_, args)
    local targetId = tonumber(args[1])
    local reason = table.concat(args, ' ', 2)
    if not targetId or reason == '' then
        return exports.sunset_ui:Notify('Usage: /cwarn [id] [reason]', 'error')
    end
    local ok, err = Sunset.AwaitCallback('sunset:clanManage', {
        action = 'warn',
        targetId = targetId,
        reason = reason,
    })
    if ok then
        exports.sunset_ui:Notify('Clan warning issued.', 'warning')
        exports.sunset_ui:Send('clanPanelShow', ok)
    else
        exports.sunset_ui:Notify(err or 'Clan warning failed.', 'error', 8000)
    end
end

RegisterCommand('cwarn', clanWarnCommand, false)
RegisterCommand('cw', clanWarnCommand, false)
TriggerEvent('chat:addSuggestion', '/cwarn', 'Issue a clan warning', { { name = 'id' }, { name = 'reason' } })
TriggerEvent('chat:addSuggestion', '/cw', 'Alias for /cwarn', { { name = 'id' }, { name = 'reason' } })

local function handleClanManageUi(data)
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
            elseif action == 'rankUp' or action == 'rankDown' then
                exports.sunset_ui:Notify('Member rank updated.', 'success')
            elseif action == 'warn' then
                exports.sunset_ui:Notify('Clan warning issued.', 'warning')
            elseif action == 'rankLabels' then
                exports.sunset_ui:Notify('Clan rank names saved.', 'success')
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

    if err and tostring(err) ~= '' then
        exports.sunset_ui:Notify(tostring(err), 'error', 8000)
    else
        exports.sunset_ui:Notify(('Clan action failed (%s).'):format(tostring(action or 'unknown')), 'error', 8000)
    end
    print(('[sunset_clans] clanManage failed (%s): %s'):format(tostring(action or 'unknown'), tostring(err or 'nil')))
end

AddEventHandler('sunset:nui:clanManage', function(data)
    CreateThread(function()
        handleClanManageUi(data)
    end)
end)

RegisterCommand('leaveclan', function()
    CreateThread(function()
        handleClanManageUi({ action = 'leave' })
    end)
end, false)
TriggerEvent('chat:addSuggestion', '/leaveclan', 'Leave your current clan')

RegisterCommand('dissolveclan', function()
    CreateThread(function()
        handleClanManageUi({ action = 'dissolve' })
    end)
end, false)
TriggerEvent('chat:addSuggestion', '/dissolveclan', 'Dissolve your clan (leader only)')
