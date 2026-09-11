-- Proximity voice HUD bridge for pma-voice.
-- Z is bound only in pma-voice (voice_defaultCycle). Do not duplicate the keybind here.

local currentModeIndex = 2
local voiceModeCount = 3
local lastTalking = false
local voiceModeTable = {}

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

local function normalizeLabel(text)
    text = tostring(text or '')
    if text == '' then return 'Normal' end
    return text:sub(1, 1):upper() .. text:sub(2):lower()
end

local function getProximityState()
    local prox = LocalPlayer.state.proximity
    if type(prox) ~= 'table' then return nil end
    return prox
end

local function getProximityLabel()
    local prox = getProximityState()
    if not prox then return 'Normal' end
    if type(prox.mode) == 'string' and prox.mode ~= '' then
        return normalizeLabel(prox.mode)
    end
    local idx = tonumber(prox.index)
    if idx and voiceModeTable[idx] and voiceModeTable[idx].label then
        return voiceModeTable[idx].label
    end
    if idx == 1 then return 'Whisper' end
    if idx == 3 then return 'Shout' end
    return 'Normal'
end

local function getProximityDistance()
    local prox = getProximityState()
    local dist = prox and tonumber(prox.distance)
    if dist and dist > 0 then return dist end
    local idx = tonumber(prox and prox.index) or currentModeIndex
    if voiceModeTable[idx] and voiceModeTable[idx].distance then
        return voiceModeTable[idx].distance
    end
    if idx == 1 then return 1.5 end
    if idx == 3 then return 6.0 end
    return 3.0
end

local function getProximityHudText()
    return ('%s · %.1fm'):format(getProximityLabel(), getProximityDistance())
end

local function pushVoiceHud(highlight)
    pcall(function()
        exports.sunset_ui:Send('updateVoice', {
            voiceRange = getProximityLabel(),
            voiceRangeMeters = getProximityDistance(),
            voiceRangeDisplay = getProximityHudText(),
            voiceTalking = isPlayerTalkingNow(),
            voiceChanged = highlight == true,
        })
    end)
end

local function syncModeFromState()
    local prox = getProximityState()
    if prox and prox.index then
        currentModeIndex = tonumber(prox.index) or currentModeIndex
    end
end

local function loadPmaVoiceSettings()
    if not isPmaVoiceStarted() then return end
    TriggerEvent('pma-voice:settingsCallback', function(settings)
        voiceModeTable = {}
        if type(settings) == 'table' and type(settings.voiceModes) == 'table' then
            voiceModeCount = math.max(1, #settings.voiceModes)
            for i, mode in ipairs(settings.voiceModes) do
                voiceModeTable[i] = {
                    distance = tonumber(mode[1]) or 3.0,
                    label = normalizeLabel(mode[2]),
                }
            end
        end
        syncModeFromState()
        pushVoiceHud(false)
    end)
end

local function cycleVoiceProximity()
    if not isPmaVoiceStarted() then
        pcall(function()
            exports.sunset_ui:Notify('Voice chat is unavailable.', 'error')
        end)
        return
    end
    ExecuteCommand('cycleproximity')
end

local function setVoiceModeIndex(targetIndex)
    if not isPmaVoiceStarted() then
        pcall(function()
            exports.sunset_ui:Notify('Voice chat is unavailable.', 'error')
        end)
        return
    end

    syncModeFromState()
    targetIndex = math.max(1, math.min(voiceModeCount, tonumber(targetIndex) or currentModeIndex))
    if targetIndex == currentModeIndex then
        pushVoiceHud(true)
        return
    end

    local steps = (targetIndex - currentModeIndex + voiceModeCount) % voiceModeCount
    if steps == 0 then steps = voiceModeCount end

    CreateThread(function()
        for _ = 1, steps do
            ExecuteCommand('cycleproximity')
            Wait(80)
        end
    end)
end

RegisterCommand('proximity', function(_, args)
    local query = tostring(args[1] or ''):lower()
    if query == '1' or query == 'whisper' or query == 'w' or query == 'low' then
        setVoiceModeIndex(1)
    elseif query == '2' or query == 'normal' or query == 'n' or query == 'med' then
        setVoiceModeIndex(2)
    elseif query == '3' or query == 'shout' or query == 's' or query == 'high' or query == 'loud' then
        setVoiceModeIndex(3)
    else
        cycleVoiceProximity()
    end
end, false)

AddEventHandler('pma-voice:setTalkingMode', function(mode)
    currentModeIndex = tonumber(mode) or currentModeIndex
    pushVoiceHud(true)
end)

AddStateBagChangeHandler('proximity', nil, function(bagName, _, value)
    local myBag = ('player:%s'):format(GetPlayerServerId(PlayerId()))
    if bagName ~= myBag or type(value) ~= 'table' then return end
    if value.index then
        currentModeIndex = tonumber(value.index) or currentModeIndex
    end
    pushVoiceHud(true)
end)

CreateThread(function()
    while true do
        local talking = isPlayerTalkingNow()
        if talking ~= lastTalking then
            lastTalking = talking
            pushVoiceHud(false)
        end
        Wait(talking and 40 or 120)
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

exports('CycleVoiceProximity', cycleVoiceProximity)

exports('SetVoiceProximity', function(idx)
    setVoiceModeIndex(idx)
    return getProximityHudText()
end)

exports('GetVoiceProximity', function()
    syncModeFromState()
    return currentModeIndex, {
        index = currentModeIndex,
        label = getProximityLabel(),
        distance = getProximityDistance(),
        display = getProximityHudText(),
    }
end)

exports('GetVoiceHudData', function()
    return {
        voiceRange = getProximityLabel(),
        voiceRangeMeters = getProximityDistance(),
        voiceRangeDisplay = getProximityHudText(),
    }
end)
