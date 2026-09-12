-- ============================================================
--  sunset_quests — client: /quests command + progress events
-- ============================================================

local panelOpen = false

local function openQuests()
    local list = Sunset.AwaitCallback('sunset:quests:list')
    if type(list) ~= 'table' then
        return exports.sunset_ui:Notify('Quest log unavailable right now.', 'error')
    end
    exports.sunset_ui:Send('questLogShow', { quests = list })
    panelOpen = true
end

RegisterCommand('quests', function()
    if panelOpen then
        panelOpen = false
        exports.sunset_ui:Send('questLogHide', {})
        exports.sunset_ui:ReleaseFocusUnlessModal()
        return
    end
    openQuests()
end, false)
TriggerEvent('chat:addSuggestion', '/quests', 'Open your quest log / progression')

AddEventHandler('sunset:nui:questLogClose', function()
    panelOpen = false
    exports.sunset_ui:Send('questLogHide', {})
    exports.sunset_ui:ReleaseFocusUnlessModal()
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
        exports.sunset_ui:SetFocus(false, false)
    end
end)
