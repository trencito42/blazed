Sunset = Sunset or {}
Sunset.Player = nil
Sunset.Character = nil
Sunset.Ready = false

-- Notify player ready on spawn
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end

    -- [BOOT TRACE] Timestamped prints for the loadscreen->login handoff chain.
    -- These land in the client F8 console / FiveM log — if the client crashes
    -- between two trace lines, that stage is the suspect.
    local bootT0 = GetGameTimer()
    local function btrace(stage)
        print(('^5[BOOT +%dms]^7 core: %s'):format(GetGameTimer() - bootT0, stage))
    end
    btrace('network active, waiting for sunset_ui')

    -- Keep the same preloaded background underneath the FiveM loadscreen.
    -- This prevents a world/black-frame flash while the independent NUIs swap.
    local uiDeadline = GetGameTimer() + 15000
    while GetResourceState('sunset_ui') ~= 'started' and GetGameTimer() < uiDeadline do
        Wait(50)
    end
    btrace('sunset_ui state=' .. tostring(GetResourceState('sunset_ui')))
    -- [AUDIT P8-24] Guard the handoff so a sunset_ui export error can never kill
    -- this thread before ShutdownLoadingScreen (manual shutdown = stuck loadscreen).
    local handoffOk, handoffErr = pcall(function()
        if GetResourceState('sunset_ui') == 'started' then
            exports.sunset_ui:Show('handoff', {})
            btrace('Show(handoff) done')
            exports.sunset_ui:Send('preloadEntryBackground', { screen = 'auth' })
            Wait(80)
            SendLoadingScreenMessage(json.encode({ eventName = 'sunsetHandoff' }))
            btrace('sunsetHandoff message sent')
            Wait(380)
        else
            print('^1[sunset_core]^7 sunset_ui was not ready before loadscreen shutdown; login UI may need /fixlogin')
        end
    end)
    if not handoffOk then
        print('^1[sunset_core]^7 loadscreen handoff failed: ' .. tostring(handoffErr))
    end

    btrace('ShutdownLoadingScreenNui')
    ShutdownLoadingScreenNui()
    btrace('ShutdownLoadingScreen')
    ShutdownLoadingScreen()
    DoScreenFadeIn(500)
    btrace('fade-in started, notifying server playerLoaded')

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
