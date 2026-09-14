-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Marriage System (client/main.lua)
--  Commands: /propose [id], /divorce, /marriage (status)
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetMarriage.Config

-- /propose [id]
RegisterCommand('propose', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        return exports.sunset_ui:Notify('Usage: /propose [player id]', 'warning')
    end
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:marriage:propose', targetId)
        if not res then
            exports.sunset_ui:Notify(err or 'Could not propose.', 'error')
        end
    end)
end, false)

-- /divorce
RegisterCommand('divorce', function()
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:marriage:divorce')
        if not res then
            exports.sunset_ui:Notify(err or 'Could not divorce.', 'error')
        end
    end)
end, false)

-- /marriage (status)
RegisterCommand('marriage', function()
    CreateThread(function()
        local res = Sunset.AwaitCallback('sunset:marriage:status')
        if not res then return end
        if res.married then
            exports.sunset_ui:Notify(('💍 Married to %s (%s). Married: %s'):format(
                res.partnerName, res.partnerOnline and 'online' or 'offline', res.marriedAt), 'info', 8000)
        else
            exports.sunset_ui:Notify('You are not married. Use /propose [id] to propose.', 'info')
        end
    end)
end, false)

-- Proposal received → show accept/decline UI
RegisterNetEvent('sunset:marriage:proposalReceived', function(data)
    exports.sunset_ui:Send('marriageProposal', data)
    exports.sunset_ui:SetFocus(true, true, false, 'marriage')
end)

-- NUI callbacks
AddEventHandler('sunset:nui:marriageRespond', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:marriage:respond', data.accept == true)
        if not res then
            exports.sunset_ui:Notify(err or 'Could not respond.', 'error')
        end
        exports.sunset_ui:Send('marriageHide', {})
        exports.sunset_ui:SetFocus(false, false, false, 'marriage')
    end)
end)

AddEventHandler('sunset:nui:marriageClose', function()
    exports.sunset_ui:Send('marriageHide', {})
    exports.sunset_ui:SetFocus(false, false, false, 'marriage')
end)

CreateThread(function()
    Wait(1500)
    TriggerEvent('chat:addSuggestion', '/propose', 'Propose marriage to a nearby player', { { name = 'id', help = 'Player server ID' } })
    TriggerEvent('chat:addSuggestion', '/divorce', 'File for divorce')
    TriggerEvent('chat:addSuggestion', '/marriage', 'Check your marriage status')
end)
