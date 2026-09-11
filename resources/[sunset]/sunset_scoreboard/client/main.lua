local open = false

local function toggleScoreboard(show)
    if show == open then return end
    open = show

    if show then
        local ok, data = pcall(function()
            return Sunset.AwaitCallback('sunset:getScoreboard')
        end)
        exports.sunset_ui:Send('showScoreboard', ok and data or { players = {}, count = 0, max = 48 })
        exports.sunset_ui:SetFocus(true, true, true)
    else
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Send('hideScoreboard', {})
    end
end

RegisterCommand('+sunset_playerlist', function()
    toggleScoreboard(true)
end, false)

RegisterCommand('-sunset_playerlist', function()
    toggleScoreboard(false)
end, false)

RegisterKeyMapping('+sunset_playerlist', 'Player list (hold)', 'keyboard', 'Z')

CreateThread(function()
    while true do
        if open then
            DisableControlAction(0, 199, true) -- pause menu
            Wait(0)
        else
            Wait(250)
        end
    end
end)
