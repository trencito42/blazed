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

function SetFocus(hasFocus, hasCursor)
    SetNuiFocus(hasFocus, hasCursor == true)
    SetNuiFocusKeepInput(false)
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

function Notify(message, type, duration)
    SendNUIMessage({
        action = 'notify',
        message = message,
        type = type or 'info',
        duration = duration or 4000,
    })
end
exports('Notify', Notify)

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
