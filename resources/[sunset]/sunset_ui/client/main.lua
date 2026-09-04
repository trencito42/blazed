local isOpen = false
local currentScreen = nil

function Show(screen, data)
    isOpen = true
    currentScreen = screen
    SetNuiFocus(true, true)
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
    ['error'] = 'That action could not be completed. Please try again.',
    ['failed'] = 'That action could not be completed. Please try again.',
    ['cannot use item'] = 'This item cannot be used in your current situation. Check the requirement shown in your inventory.',
    ['no permission'] = 'You do not have the required job, faction rank, or admin permission for this action.',
    ['no character'] = 'Your character is not loaded. Reconnect and select your character again.',
    ['character error'] = 'A required character is no longer available. Refresh and try again.',
    ['not found'] = 'That entry no longer exists. Refresh the menu and try again.',
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

-- ESC handling
CreateThread(function()
    while true do
        if isOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- PTT
            EnableControlAction(0, 46, true)  -- E
        end
        Wait(isOpen and 0 or 500)
    end
end)
