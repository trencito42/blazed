-- Proximity voice HUD bridge for pma-voice.
-- Do not call Mumble natives here — pma-voice owns voice targets and range.

local currentModeIndex = 2
local voiceModeCount = 3
local lastTalking = false

local function isPmaVoiceStarted()
    return GetResourceState('pma-voice') == 'started'
end

local function isPlayerTalkingNow()
    local myId = PlayerId()
    if MumbleIsPlayerTalking and MumbleIsPlayerTalking(myId) then
        return true
    end
    return NetworkIsPlayerTalking(myId) == 1 or NetworkIsPlayerTalking(myId) == true
end

local function getProximityLabel()
    local prox = LocalPlayer.state.proximity
    if type(prox) == 'table' then
        if type(prox.mode) == 'string' and prox.mode ~= '' then
            return prox.mode
        end
        local idx = tonumber(prox.index)
        if idx == 1 then return 'Whisper' end
        if idx == 3 then return 'Shout' end
    end
    return 'Normal'
end

local function pushVoiceHud()
    pcall(function()
        exports.sunset_ui:Send('updateVoice', {
            voiceRange = getProximityLabel(),
            voiceTalking = isPlayerTalkingNow(),
        })
    end)
end

local function syncModeFromState()
    local prox = LocalPlayer.state.proximity
    if type(prox) == 'table' and prox.index then
        currentModeIndex = tonumber(prox.index) or currentModeIndex
    end
end

local function loadPmaVoiceSettings()
    if not isPmaVoiceStarted() then return end
    TriggerEvent('pma-voice:settingsCallback', function(settings)
        if type(settings) == 'table' and type(settings.voiceModes) == 'table' then
            voiceModeCount = math.max(1, #settings.voiceModes)
        end
        syncModeFromState()
        pushVoiceHud()
    end)
end

local function notifyCurrentRange()
    local prox = LocalPlayer.state.proximity
    if type(prox) == 'table' and prox.mode and prox.distance then
        exports.sunset_ui:Notify(('Voice range: %s (%.1fm)'):format(prox.mode, prox.distance), 'info')
        return
    end
    exports.sunset_ui:Notify(('Voice range: %s'):format(getProximityLabel()), 'info')
end

local function cycleVoiceProximity(notify)
    if not isPmaVoiceStarted() then
        if notify then
            pcall(function()
                exports.sunset_ui:Notify('Voice chat is unavailable.', 'error')
            end)
        end
        return
    end

    ExecuteCommand('cycleproximity')
    SetTimeout(60, function()
        syncModeFromState()
        pushVoiceHud()
        if notify then notifyCurrentRange() end
    end)
end

local function setVoiceModeIndex(targetIndex, notify)
    if not isPmaVoiceStarted() then
        if notify then
            pcall(function()
                exports.sunset_ui:Notify('Voice chat is unavailable.', 'error')
            end)
        end
        return
    end

    syncModeFromState()
    targetIndex = math.max(1, math.min(voiceModeCount, tonumber(targetIndex) or currentModeIndex))
    if targetIndex == currentModeIndex then
        pushVoiceHud()
        if notify then notifyCurrentRange() end
        return
    end

    local steps = (targetIndex - currentModeIndex + voiceModeCount) % voiceModeCount
    if steps == 0 then steps = voiceModeCount end

    CreateThread(function()
        for _ = 1, steps do
            ExecuteCommand('cycleproximity')
            Wait(80)
        end
        syncModeFromState()
        pushVoiceHud()
        if notify then notifyCurrentRange() end
    end)
end

RegisterCommand('+sunset_cycleproximity', function()
    cycleVoiceProximity(true)
end, false)

RegisterCommand('-sunset_cycleproximity', function()
end, false)

RegisterKeyMapping('+sunset_cycleproximity', 'Cycle Voice Range (Whisper/Normal/Shout)', 'keyboard', 'Z')

RegisterCommand('proximity', function(_, args)
    local query = tostring(args[1] or ''):lower()
    if query == '1' or query == 'whisper' or query == 'w' or query == 'low' then
        setVoiceModeIndex(1, true)
    elseif query == '2' or query == 'normal' or query == 'n' or query == 'med' then
        setVoiceModeIndex(2, true)
    elseif query == '3' or query == 'shout' or query == 's' or query == 'high' or query == 'loud' then
        setVoiceModeIndex(3, true)
    else
        cycleVoiceProximity(true)
    end
end, false)

AddEventHandler('pma-voice:setTalkingMode', function(mode)
    currentModeIndex = tonumber(mode) or currentModeIndex
    pushVoiceHud()
end)

AddStateBagChangeHandler('proximity', nil, function(bagName, _, value)
    local myBag = ('player:%s'):format(GetPlayerServerId(PlayerId()))
    if bagName ~= myBag or type(value) ~= 'table' then return end
    if value.index then
        currentModeIndex = tonumber(value.index) or currentModeIndex
    end
    pushVoiceHud()
end)

CreateThread(function()
    while true do
        local talking = isPlayerTalkingNow()
        if talking ~= lastTalking then
            lastTalking = talking
            pushVoiceHud()
        end
        Wait(talking and 40 or 80)
    end
end)

AddEventHandler('sunset:client:playerSpawned', function()
    loadPmaVoiceSettings()
end)

AddEventHandler('sunset:client:onCharacterLoaded', function()
    loadPmaVoiceSettings()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'pma-voice' and resource ~= GetCurrentResourceName() then return end
    SetTimeout(500, loadPmaVoiceSettings)
end)

exports('CycleVoiceProximity', function()
    return cycleVoiceProximity(true)
end)

exports('SetVoiceProximity', function(idx, notify)
    setVoiceModeIndex(idx, notify ~= false)
    return getProximityLabel()
end)

exports('GetVoiceProximity', function()
    syncModeFromState()
    return currentModeIndex, {
        index = currentModeIndex,
        label = getProximityLabel(),
        distance = type(LocalPlayer.state.proximity) == 'table' and LocalPlayer.state.proximity.distance or nil,
    }
end)
