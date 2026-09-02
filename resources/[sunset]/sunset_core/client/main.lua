Sunset = Sunset or {}
Sunset.Player = nil
Sunset.Character = nil
Sunset.Ready = false

-- Notify player ready on spawn
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end

    -- Inchide loading screen-ul custom
    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()

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

function GetPlayerData()
    return Sunset.Player
end
exports('GetPlayer', GetPlayerData)

function GetCharacterData()
    return Sunset.Character
end
exports('GetCharacter', GetCharacterData)
