local function registerSuggestions(categories)
    for _, cat in ipairs(categories or {}) do
        for _, entry in ipairs(cat.entries or {}) do
            local cmd = entry.cmd and entry.cmd:match('^(/[%w_]+)')
            if cmd then
                TriggerEvent('chat:addSuggestion', cmd, entry.desc or '')
            end
        end
    end
end

local function openHelp(data)
    TriggerEvent('sunset:ui:help', data)
    registerSuggestions(data.categories)
end

RegisterCommand('help', function()
    local data, err = Sunset.AwaitCallback('sunset:getHelp')
    if not data then
        exports.sunset_ui:Notify(err or 'Could not load help', 'error')
        return
    end
    openHelp(data)
end, false)

TriggerEvent('chat:addSuggestion', '/help', 'Open your personalized command guide')

AddEventHandler('sunset:nui:helpClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('helpHide', {})
end)
