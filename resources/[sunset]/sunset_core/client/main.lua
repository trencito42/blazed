Sunset = Sunset or {}
Sunset.Player = nil
Sunset.Character = nil
Sunset.Ready = false

-- Notify player ready on spawn
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end

    -- Keep the same preloaded background underneath the FiveM loadscreen.
    -- This prevents a world/black-frame flash while the independent NUIs swap.
    local uiDeadline = GetGameTimer() + 15000
    while GetResourceState('sunset_ui') ~= 'started' and GetGameTimer() < uiDeadline do
        Wait(50)
    end
    if GetResourceState('sunset_ui') == 'started' then
        exports.sunset_ui:Show('handoff', {})
        exports.sunset_ui:Send('preloadEntryBackground', { screen = 'auth' })
        Wait(80)
        SendLoadingScreenMessage(json.encode({ eventName = 'sunsetHandoff' }))
        Wait(380)
    else
        print('^1[sunset_core]^7 sunset_ui was not ready before loadscreen shutdown; login UI may need /fixlogin')
    end

    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()
    DoScreenFadeIn(500)

    TriggerServerEvent('sunset:server:playerLoaded')
end)

RegisterNetEvent('sunset:client:playerReady', function(data)
    Sunset.Player = data
    Sunset.Ready = true
    Sunset.Debug('Player ready:', data.name)
    TriggerEvent('sunset:client:onPlayerReady', data)
end)

RegisterNetEvent('sunset:client:characterLoaded', function(charData)
    Sunset.Character = charData
    TriggerEvent('sunset:client:onCharacterLoaded', charData)
end)

RegisterNetEvent('sunset:client:updateCharacter', function(charData)
    if not charData then return end
    if Sunset.Character then
        for k, v in pairs(charData) do Sunset.Character[k] = v end
    else
        Sunset.Character = charData
    end
    TriggerEvent('sunset:client:onCharacterUpdated', charData)
end)

function GetPlayerData()
    return Sunset.Player
end
exports('GetPlayer', GetPlayerData)

function GetCharacterData()
    return Sunset.Character
end
exports('GetCharacter', GetCharacterData)
