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

RegisterCommand('+sunset_scoreboard', function()
    toggleScoreboard(true)
end, false)

RegisterCommand('-sunset_scoreboard', function()
    toggleScoreboard(false)
end, false)

RegisterKeyMapping('+sunset_scoreboard', 'Scoreboard (lista jucători)', 'keyboard', 'TAB')

CreateThread(function()
    while true do
        Wait(0)
        -- Blochează weapon wheel / player list GTA fără overlay negru
        DisableControlAction(0, 37, true)
        DisableControlAction(0, 199, true) -- pause menu
        if open then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
        end
    end
end)
