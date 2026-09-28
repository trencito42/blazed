Sunset = Sunset or {}
Sunset.Player = nil
Sunset.Character = nil
Sunset.Ready = false

-- Notify player ready on spawn
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end

    -- [BOOT TRACE v2] ABSOLUTE epoch-ms timestamps. Lua has no wall clock, so
    -- we calibrate against the NUI's Date.now() via a one-shot handshake
    -- (sunset_ui posts nuiEpoch back). Until calibration lands, lines print
    -- with epoch=0 and a local ms offset — still ORDERED, and the NUI side
    -- prints true epochs, so the two can be interleaved.
    local bootLocal = GetGameTimer()
    local epochOffset = nil -- set from NUI handshake: Date.now() - GetGameTimer()
    local function btrace(stage)
        local abs = epochOffset and (GetGameTimer() + epochOffset) or 0
        print(('^5[BOOT %d (+%dms)]^7 core: %s'):format(abs, GetGameTimer() - bootLocal, stage))
    end
    exports('BootTrace', function(stage) btrace(tostring(stage)) end)
    btrace('network active, waiting for sunset_ui')

    -- [A/B NOFX MODE] convar sv_sunset_nofx=1 disables loadscreen/NUI
    -- animations, filters and big backgrounds for freeze A/B testing.
    local nofx = GetConvar('sv_sunset_nofx', '0') == '1'

    -- Keep the same preloaded background underneath the FiveM loadscreen.
    -- This prevents a world/black-frame flash while the independent NUIs swap.
    local uiDeadline = GetGameTimer() + 15000
    while (GetResourceState('sunset_auth_ui') ~= 'started' and GetResourceState('sunset_ui') ~= 'started') and GetGameTimer() < uiDeadline do
        Wait(50)
    end
    btrace('auth_ui state=' .. tostring(GetResourceState('sunset_auth_ui')) .. ', sunset_ui state=' .. tostring(GetResourceState('sunset_ui')))

    -- [HANDOFF FIX] Deterministic ready handshake with sunset_auth_ui / sunset_ui.
    -- 1) Wait for auth UI to render first frames (IsRendered / bootEpoch)
    -- 2) Tell the loadscreen to freeze + fade
    -- 3) Shutdown loading screen
    local handoffOk, handoffErr = pcall(function()
        local readyDeadline = GetGameTimer() + 8000
        local nuiReady = false
        while GetGameTimer() < readyDeadline do
            if GetResourceState('sunset_auth_ui') == 'started' then
                local rendered = exports.sunset_auth_ui:IsRendered()
                if rendered then
                    btrace('sunset_auth_ui rendered confirmed')
                    nuiReady = true
                    break
                end
            end
            if GetResourceState('sunset_ui') == 'started' then
                local epochNow = exports.sunset_ui:GetBootEpoch()
                if epochNow and tonumber(epochNow) and tonumber(epochNow) > 0 then
                    epochOffset = tonumber(epochNow) - GetGameTimer()
                    btrace(('epoch calibrated (offset=%d) — sunset_ui ready'):format(epochOffset))
                    nuiReady = true
                    break
                end
            end
            Wait(25)
        end
        if not nuiReady then
            btrace('NUI ready timeout (8s) — proceeding with failsafe shutdown')
        end

        btrace('SEND_LOADING_SCREEN_MESSAGE sunsetHandoff')
        SendLoadingScreenMessage(json.encode({ eventName = 'sunsetHandoff' }))
        if nofx then
            SendLoadingScreenMessage(json.encode({ eventName = 'nofx' }))
        end
        Wait(120)
    end)
    if not handoffOk then
        print('^1[sunset_core]^7 loadscreen handoff failed: ' .. tostring(handoffErr))
    end

    btrace('ShutdownLoadingScreenNui (calling)')
    ShutdownLoadingScreenNui()
    btrace('ShutdownLoadingScreenNui RETURNED')
    ShutdownLoadingScreen()
    btrace('ShutdownLoadingScreen RETURNED')
    DoScreenFadeIn(500)
    btrace('fade-in started, notifying server playerLoaded')

    -- [BOOT TRACE v2] 6) first responsive frame after shutdown: measure how
    -- long the main thread stays blocked between fade-in and the next frames.
    CreateThread(function()
        local t0 = GetGameTimer()
        local frames = 0
        local lastGapStart = GetGameTimer()
        while frames < 300 do -- ~5s at 60fps
            Wait(0)
            frames = frames + 1
            local now = GetGameTimer()
            if now - lastGapStart > 300 then
                btrace(('CLIENT FRAME GAP %dms after %d frames'):format(now - lastGapStart, frames))
            end
            lastGapStart = now
            if frames == 1 then btrace(('first frame after shutdown (+%dms)'):format(now - t0)) end
            if frames == 60 then btrace(('60 frames rendered (+%dms)'):format(now - t0)) end
        end
    end)

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
