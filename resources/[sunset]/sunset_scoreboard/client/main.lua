local open = false

-- [WAR FIX] During a turf war, Z belongs to the war scoreboard (sunset_turfs).
-- Yield to it so the two scoreboards don't both open on the same key.
local function inTurfWar()
    if GetResourceState('sunset_turfs') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.sunset_turfs:IsInWar() end)
    return ok and res == true
end

local function toggleScoreboard(show)
    if show == open then return end
    if show and (IsPauseMenuActive() or IsNuiFocused()) then return end
    if show and inTurfWar() then return end
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

RegisterKeyMapping('+sunset_playerlist', 'Player list (hold)', 'keyboard', 'Z')

-- FiveM keeps old user key mappings after defaults change. Read physical Z as a
-- fallback so the player list remains reliable without resetting local binds.
CreateThread(function()
    local physicalZDown = false
    while true do
        if IsPauseMenuActive() or IsNuiFocused() or inTurfWar() then
            physicalZDown = false
            if open then toggleScoreboard(false) end
            Wait(100)
        else
            DisableControlAction(0, 20, true) -- INPUT_MULTIPLAYER_INFO / Z
            local pressed = IsDisabledControlPressed(0, 20)
            if pressed and not physicalZDown then
                physicalZDown = true
                toggleScoreboard(true)
            elseif not pressed and physicalZDown then
                physicalZDown = false
                toggleScoreboard(false)
            end
            DisableControlAction(0, 199, true) -- pause menu
            Wait(0)
        end
    end
end)
