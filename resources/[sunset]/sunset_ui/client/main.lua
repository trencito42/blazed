local isOpen = false
local currentScreen = nil

function Show(screen, data)
    isOpen = true
    currentScreen = screen
    if screen ~= 'loading' then
        SetNuiFocus(true, true)
    end
    SendNUIMessage({
        action = 'show',
        screen = screen,
        data = data or {},
    })
end
exports('Show', Show)

function Hide()
    isOpen = false
    currentScreen = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'hide' })
end
exports('Hide', Hide)

function SetFocus(hasFocus, hasCursor, keepInput)
    SetNuiFocus(hasFocus, hasCursor == true)
    SetNuiFocusKeepInput(keepInput == true)
end
exports('SetFocus', SetFocus)

function Send(action, data)
    SendNUIMessage({
        action = action,
        data = data or {},
    })
end
exports('Send', Send)

function IsOpen()
    return isOpen
end
exports('IsOpen', IsOpen)

local FRIENDLY_ERRORS = {
    ['nil'] = 'That action could not be completed. Please try again; if it repeats, report what you clicked.',
    ['error'] = 'That action stopped unexpectedly. Try again once; if it repeats, report the command or button you used.',
    ['failed'] = 'That action did not complete. Check the requirement shown in /help, your target ID and your distance, then try again.',
    ['cannot use item'] = 'This item cannot be used in your current situation. Check the requirement shown in your inventory.',
    ['no permission'] = 'Your current job, faction rank, duty state, or admin level does not unlock this action. Open /help to see commands available to you.',
    ['not on duty or no permission'] = 'This action requires the correct faction, rank, and an active duty shift. Go to your faction HQ, start duty, then check /help.',
    ['player not found'] = 'That server ID is not online. Hold F10 and use the ID currently shown there.',
    ['no character'] = 'Your character is not loaded. Reconnect and select your character again.',
    ['no character loaded'] = 'Your character is not loaded. Reconnect and select your character again.',
    ['character error'] = 'A required character is no longer available. Refresh and try again.',
    ['not found'] = 'That entry no longer exists. Refresh the menu and try again.',
    ['unavailable'] = 'That system is currently unavailable. Try once more; if it repeats, report the command or button to staff.',
    ['invalid action'] = 'That button/action is no longer valid for the current screen. Close the menu, reopen it, and try again.',
    ['invalid amount'] = 'Enter a positive numeric amount within the limit shown by this system.',
    ['invalid target'] = 'Choose another online player and use the current server ID shown in F10.',
    ['invalid player'] = 'That server ID is not online. Hold F10 and use the ID currently shown there.',
    ['call not found'] = 'That service call was closed, cancelled, or taken already. Refresh the call list.',
    ['could not accept call'] = 'That service call could not be assigned, usually because another responder took it. Refresh the call list.',
    ['rank too low'] = 'Your current faction rank does not unlock this action. Open /help to see commands available to your rank.',
    ['not on duty'] = 'This action requires an active duty shift. Go to your faction HQ and press E or use /duty.',
    ['must be on duty'] = 'This action requires an active duty shift. Go to your faction HQ and press E or use /duty.',
    ['wrong faction'] = 'This action belongs to a different faction. Open /faction to check your membership.',
}

local function friendlyMessage(message)
    if message == nil or message == false then return FRIENDLY_ERRORS['nil'] end
    local text = tostring(message)
    if text == '' then return FRIENDLY_ERRORS['nil'] end
    return FRIENDLY_ERRORS[string.lower(text)] or text
end

function Notify(message, type, duration)
    SendNUIMessage({
        action = 'notify',
        message = friendlyMessage(message),
        type = type or 'info',
        duration = duration or 4000,
    })
end
exports('Notify', Notify)

-- One canonical listener prevents every server notification from being rendered
-- once per unrelated client resource.
RegisterNetEvent('sunset:client:notify', function(message, notificationType, duration)
    Notify(message, notificationType, duration)
end)

function ProgressBar(label, duration, cb)
    SendNUIMessage({
        action = 'progress',
        label = label,
        duration = duration,
    })
    if cb then
        SetTimeout(duration, cb)
    end
end
exports('ProgressBar', ProgressBar)

RegisterNUICallback('close', function(_, cb)
    Hide()
    cb('ok')
end)

RegisterNUICallback('playSound', function(data, cb)
    PlaySoundFrontend(-1, data.sound or 'SELECT', data.set or 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    cb('ok')
end)

RegisterNUICallback('loadingTimeout', function(_, cb)
    if currentScreen == 'loading' then
        Hide()
        DoScreenFadeIn(500)
        Notify('Character loading took too long. Your controls were restored; reconnect if the character still does not appear.', 'error', 8000)
        TriggerEvent('sunset:client:loadingTimedOut')
    end
    cb('ok')
end)

-- ESC handling
CreateThread(function()
    while true do
        if isOpen and currentScreen ~= 'loading' then
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- PTT
            EnableControlAction(0, 46, true)  -- E
        end
        Wait(isOpen and currentScreen ~= 'loading' and 0 or 500)
    end
end)
