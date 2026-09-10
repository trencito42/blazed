local VOICE_PROXIMITY_MODES = {
    { index = 1, label = 'Whisper', distance = 1.5 },
    { index = 2, label = 'Normal', distance = 4.0 },
    { index = 3, label = 'Shout', distance = 10.0 },
}

local currentProximityIndex = 2
local lastTalking = false
local voiceInitialized = false

local function isPlayerTalkingNow()
    local myId = PlayerId()
    if MumbleIsPlayerTalking and MumbleIsPlayerTalking(myId) then
        return true
    end
    return NetworkIsPlayerTalking(myId) == 1 or NetworkIsPlayerTalking(myId) == true
end

local function applyVoiceProximity(index, notify)
    index = tonumber(index) or 2
    if index < 1 then index = 1 end
    if index > #VOICE_PROXIMITY_MODES then index = #VOICE_PROXIMITY_MODES end

    currentProximityIndex = index
    local mode = VOICE_PROXIMITY_MODES[currentProximityIndex]

    -- Set native GTA V and Mumble talker proximity
    pcall(function()
        MumbleSetTalkerProximity(mode.distance + 0.0)
    end)
    pcall(function()
        NetworkSetTalkerProximity(mode.distance + 0.0)
    end)

    -- Update state bag for HUD & remote players
    LocalPlayer.state:set('proximity', {
        index = mode.index,
        mode = mode.label,
        distance = mode.distance,
    }, true)

    -- Send fast update directly to UI
    pcall(function()
        exports.sunset_ui:Send('updateVoice', {
            voiceRange = mode.label,
            voiceTalking = isPlayerTalkingNow(),
        })
    end)

    if notify then
        pcall(function()
            exports.sunset_ui:Notify(('Voice range: %s (%sm)'):format(mode.label, mode.distance), 'info')
        end)
    end

    return mode
end

local function cycleVoiceProximity()
    local nextIndex = (currentProximityIndex % #VOICE_PROXIMITY_MODES) + 1
    return applyVoiceProximity(nextIndex, true)
end

local function initializeVoice()
    if voiceInitialized then return end
    voiceInitialized = true

    pcall(function()
        MumbleClearVoiceTarget(1)
        MumbleSetVoiceTarget(1)
        MumbleAddVoiceTargetChannel(1, 1)
    end)

    applyVoiceProximity(currentProximityIndex, false)
end

-- Keymapping for proximity cycling (Default: Z)
RegisterCommand('+cycleproximity', function()
    cycleVoiceProximity()
end, false)

RegisterCommand('-cycleproximity', function()
end, false)

RegisterKeyMapping('+cycleproximity', 'Cycle Voice Range (Whisper/Normal/Shout)', 'keyboard', 'Z')

-- Chat commands
RegisterCommand('cycleproximity', function()
    cycleVoiceProximity()
end, false)

RegisterCommand('proximity', function(_, args)
    local query = tostring(args[1] or ''):lower()
    if query == '1' or query == 'whisper' or query == 'w' or query == 'low' then
        applyVoiceProximity(1, true)
    elseif query == '2' or query == 'normal' or query == 'n' or query == 'med' then
        applyVoiceProximity(2, true)
    elseif query == '3' or query == 'shout' or query == 's' or query == 'high' or query == 'loud' then
        applyVoiceProximity(3, true)
    else
        cycleVoiceProximity()
    end
end, false)

-- Reactive talking detection thread
CreateThread(function()
    while true do
        local talking = isPlayerTalkingNow()
        if talking ~= lastTalking then
            lastTalking = talking
            LocalPlayer.state:set('isTalking', talking, true)
            pcall(function()
                exports.sunset_ui:Send('updateVoice', {
                    voiceTalking = talking,
                    voiceRange = VOICE_PROXIMITY_MODES[currentProximityIndex].label,
                })
            end)
        end
        Wait(talking and 40 or 80)
    end
end)

-- Initialization handlers
AddEventHandler('sunset:client:playerSpawned', function()
    initializeVoice()
end)

AddEventHandler('sunset:client:onCharacterLoaded', function()
    initializeVoice()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(500)
    initializeVoice()
end)

-- Exports
exports('CycleVoiceProximity', cycleVoiceProximity)
exports('SetVoiceProximity', function(idx, notify)
    return applyVoiceProximity(idx, notify ~= false)
end)
exports('GetVoiceProximity', function()
    return currentProximityIndex, VOICE_PROXIMITY_MODES[currentProximityIndex]
end)
