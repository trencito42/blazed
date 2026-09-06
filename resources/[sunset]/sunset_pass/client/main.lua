local openTab = 'rewards'
local isOpen = false

local function notify(message, kind)
    TriggerEvent('sunset:client:notify', message, kind or 'info', 5000)
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function setFocus(state)
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
end

local function closePass()
    if not isOpen then return end
    isOpen = false
    setFocus(false)
    send('passHide', {})
end

local function openPass(tab)
    if isOpen then
        openTab = tab or openTab
        send('passSetTab', { tab = openTab })
        return
    end
    if IsNuiFocused() and not isOpen then return end

    local data, err = Sunset.AwaitCallback('sunset:pass:getData')
    if not data then
        notify(err or 'Could not load Sunset Pass.', 'error')
        return
    end

    openTab = tab or 'rewards'
    isOpen = true
    setFocus(true)
    send('passShow', { tab = openTab, state = data })
end

RegisterCommand('pass', function()
    openPass('rewards')
end, false)

RegisterCommand('missions', function()
    openPass('missions')
end, false)

RegisterNUICallback('passClose', function(_, cb)
    closePass()
    cb('ok')
end)

RegisterNUICallback('passSetTab', function(data, cb)
    openTab = (data and data.tab) or openTab
    cb('ok')
end)

RegisterNUICallback('passClaim', function(data, cb)
    local result, err = Sunset.AwaitCallback('sunset:pass:claim', data)
    if not result then
        notify(err or 'Could not claim reward.', 'error')
        cb({ ok = false })
        return
    end
    send('passUpdate', { state = result })
    cb({ ok = true })
end)

RegisterNUICallback('passBuyPremium', function(_, cb)
    local result, err = Sunset.AwaitCallback('sunset:pass:buyPremium')
    if not result then
        notify(err or 'Could not unlock premium pass.', 'error')
        cb({ ok = false })
        return
    end
    send('passUpdate', { state = result })
    notify('Premium pass unlocked.', 'success')
    cb({ ok = true })
end)

RegisterNetEvent('sunset:pass:refresh', function()
    if not isOpen then return end
    local data = Sunset.AwaitCallback('sunset:pass:getData')
    if data then send('passUpdate', { state = data }) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closePass()
end)

exports('OpenPass', function(tab)
    openPass(tab or 'rewards')
end)

exports('ClosePass', closePass)
