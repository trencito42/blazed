local open = false

local function toggleScoreboard(show)
    if show == open then return end
    open = show

    if show then
        local ok, data = pcall(function()
            return Sunset.AwaitCallback('sunset:getScoreboard')
        end)
        exports.sunset_ui:Send('showScoreboard', ok and data or { players = {}, count = 0, max = 48 })
    else
        exports.sunset_ui:Send('hideScoreboard', {})
    end
end

RegisterCommand('+sunset_playerlist', function()
    toggleScoreboard(true)
end, false)

RegisterCommand('-sunset_playerlist', function()
    toggleScoreboard(false)
end, false)

RegisterKeyMapping('+sunset_playerlist', 'Player list', 'keyboard', 'F10')

CreateThread(function()
    while true do
        Wait(0)
        if open then
            DisableControlAction(0, 199, true) -- pause menu
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
        end
    end
end)
