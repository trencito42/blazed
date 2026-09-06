RobberyNui = {}

function RobberyNui.send(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

function RobberyNui.focus(hasFocus, hasCursor)
    SetNuiFocus(hasFocus == true, hasCursor == true)
end

RegisterNUICallback('hackClick', function(data, cb)
    TriggerServerEvent('sunset:robbery:hackClick', data and data.nodeId)
    cb('ok')
end)

RegisterNUICallback('hackClose', function(_, cb)
    RobberyNui.focus(false, false)
    cb('ok')
end)

RegisterNUICallback('lootTake', function(data, cb)
    TriggerServerEvent('sunset:robbery:takeItem', data and data.displayId, data and data.uid)
    cb('ok')
end)

RegisterNUICallback('lootClose', function(_, cb)
    RobberyNui.focus(false, false)
    RobberyNui.send('lootHide', {})
    cb('ok')
end)

RegisterNUICallback('fenceSell', function(data, cb)
    TriggerEvent('sunset:robbery:nuiFenceSell', data)
    cb('ok')
end)

RegisterNUICallback('fenceClose', function(_, cb)
    RobberyNui.focus(false, false)
    RobberyNui.send('fenceHide', {})
    cb('ok')
end)

RegisterNUICallback('playSound', function(data, cb)
    local key = data and data.key
    local snd = key and SunsetRobbery.Sounds[key]
    if snd then
        PlaySoundFrontend(-1, snd.name, snd.set, true)
    end
    cb('ok')
end)
