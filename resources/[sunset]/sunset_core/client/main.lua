Sunset = Sunset or {}
Sunset.Player = nil
Sunset.Character = nil
Sunset.Ready = false

local BOOT_ORDER = {
    LOADSCREEN = 1,
    SESSION_REQUESTED = 2,
    AUTH_BOOT = 3,
    AUTH_FORM = 4,
    AUTHENTICATING = 5,
    CHARACTER_LOADING = 6,
    SPAWNING = 7,
    GAMEPLAY = 8,
}
local bootState = 'LOADSCREEN'

function SetBootState(nextState, reason)
    if not BOOT_ORDER[nextState] then return false end
    local currentOrder = BOOT_ORDER[bootState] or 0
    local nextOrder = BOOT_ORDER[nextState]
    local authFailure = bootState == 'AUTHENTICATING' and nextState == 'AUTH_FORM'
    if nextOrder < currentOrder and not authFailure then
        print(('^3[BOOT]^7 rejected state %s -> %s (%s)'):format(bootState, nextState, tostring(reason or '')))
        return false
    end
    if nextState == bootState then return true end
    local previous = bootState
    bootState = nextState
    if GetConvar('sv_sunset_nuidebug', '0') == '1' then
        print(('^5[BOOT]^7 state %s -> %s (%s)'):format(previous, nextState, tostring(reason or '')))
    end
    TriggerEvent('sunset:client:bootStateChanged', nextState, previous, reason)
    return true
end
exports('SetBootState', SetBootState)
exports('GetBootState', function() return bootState end)

CreateThread(function()
    while bootState ~= 'GAMEPLAY' do
        DisableAllControlActions(0)
        -- NUI receives keyboard/mouse independently; keep only push-to-talk alive.
        EnableControlAction(0, 249, true)
        Wait(0)
    end
end)

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

    -- Wait only for the auth DOM host. DOM readiness does not authorize the
    -- loadscreen handoff; an actually visible auth frame does.
    local uiDeadline = GetGameTimer() + 15000
    while (GetResourceState('sunset_auth_ui') ~= 'started' and GetResourceState('sunset_ui') ~= 'started') and GetGameTimer() < uiDeadline do
        Wait(50)
    end
    btrace('auth_ui state=' .. tostring(GetResourceState('sunset_auth_ui')) .. ', sunset_ui state=' .. tostring(GetResourceState('sunset_ui')))

    local domDeadline = GetGameTimer() + 30000
    while GetGameTimer() < domDeadline do
        if GetResourceState('sunset_auth_ui') == 'started' and GetResourceState('sunset_auth') == 'started' then
            local ok, ready = pcall(function() return exports.sunset_auth_ui:IsDomReady() end)
            if ok and ready then break end
        end
        Wait(25)
    end

    SetBootState('SESSION_REQUESTED', 'auth DOM ready')
    btrace('notifying server playerLoaded')
    TriggerServerEvent('sunset:server:playerLoaded')

    -- Auth decides between quick-login and the form. Keep the FiveM loadscreen
    -- until either presentation has reached its final painted position.
    local handoffOk, handoffErr = pcall(function()
        local readyDeadline = GetGameTimer() + 12000
        local nuiReady = false
        while GetGameTimer() < readyDeadline do
            if GetResourceState('sunset_auth_ui') == 'started' then
                local rendered = exports.sunset_auth_ui:IsVisibleRendered()
                if rendered then
                    btrace('sunset_auth_ui visible frame confirmed')
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

    -- Park the ped in open ocean before handing rendering control to GTA.
    -- When ShutdownLoadingScreen() fires, the engine streams the area around
    -- the ped; ocean at (0,0,-100) has virtually no geometry, so the first-frame
    -- stall is near-zero. sunset_spawn will relocate and stream the real spawn
    -- position via streamSpawnArea() once the player selects a character.
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, 0.0, 0.0, -100.0, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetFocusPosAndVel(0.0, 0.0, -100.0, 0.0, 0.0, 0.0)

    btrace('ShutdownLoadingScreenNui (calling)')
    ShutdownLoadingScreenNui()
    btrace('ShutdownLoadingScreenNui RETURNED')
    ShutdownLoadingScreen()
    btrace('ShutdownLoadingScreen RETURNED')
    DoScreenFadeIn(500)
    btrace('fade-in started; auth owns the visible surface')

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
