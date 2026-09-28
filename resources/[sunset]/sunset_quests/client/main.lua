-- ============================================================
--  sunset_quests — client: /quests command + progress events
-- ============================================================

local panelOpen = false
local panelRendered = false
local panelRenderToken = 0

AddEventHandler('sunset:nui:questLogRendered', function(data)
    if tonumber(data and data.renderToken) == panelRenderToken then
        panelRendered = true
    end
end)

local function openQuests()
    local list = Sunset.AwaitCallback('sunset:quests:list')
    if type(list) ~= 'table' then
        return exports.sunset_ui:Notify('Quest log unavailable right now.', 'error')
    end
    panelRendered = false
    panelRenderToken = panelRenderToken + 1
    exports.sunset_ui:Send('questLogShow', { quests = list, renderToken = panelRenderToken })

    -- The UI is loaded on demand. Never capture the mouse until CEF confirms
    -- that the panel was actually painted; otherwise a failed module load
    -- leaves the player with an invisible modal and a trapped cursor.
    local deadline = GetGameTimer() + 3000
    while not panelRendered and GetGameTimer() < deadline do Wait(25) end
    if not panelRendered then
        exports.sunset_ui:Send('questLogHide', {})
        exports.sunset_ui:SetFocus(false, false, false, 'force')
        return exports.sunset_ui:Notify('Quest log failed to load. Try again once.', 'error')
    end

    exports.sunset_ui:SetFocus(true, true, false, 'quests')
    panelOpen = true
end

RegisterCommand('quests', function()
    if panelOpen then
        panelOpen = false
        exports.sunset_ui:Send('questLogHide', {})
        exports.sunset_ui:ReleaseFocusUnlessModal('quests')
        return
    end
    openQuests()
end, false)
TriggerEvent('chat:addSuggestion', '/quests', 'Open your quest log / progression')

AddEventHandler('sunset:nui:questLogClose', function()
    panelOpen = false
    exports.sunset_ui:Send('questLogHide', {})
    exports.sunset_ui:ReleaseFocusUnlessModal('quests')
end)

AddEventHandler('sunset:nui:questClaim', function(data)
    local questKey = data and data.questKey
    if not questKey then return end
    local ok, err = Sunset.AwaitCallback('sunset:quests:claim', questKey)
    if ok then
        exports.sunset_ui:Notify('Reward claimed!', 'success')
        if panelOpen then openQuests() end
    else
        exports.sunset_ui:Notify(err or 'Could not claim reward.', 'error')
    end
end)

RegisterNetEvent('sunset:quests:objectiveComplete', function()
    -- subtle audio confirmation
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if panelOpen then
        exports.sunset_ui:Send('questLogHide', {})
        exports.sunset_ui:SetFocus(false, false, false, 'force')
    end
end)
