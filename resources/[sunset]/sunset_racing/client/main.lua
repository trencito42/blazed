-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Street Racing (client/main.lua)
--  Start marker, checkpoint tracking, race HUD, countdown.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetRacing.Config
local raceActive = false
local raceData = nil
local currentCheckpoint = 1
local raceBlips = {}

-- ── Start marker ──
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sleep = 500

        if not raceActive and #(coords - Cfg.startMarker) < 5.0 then
            sleep = 0
            DrawMarker(1, Cfg.startMarker.x, Cfg.startMarker.y, Cfg.startMarker.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                2.0, 2.0, 1.0,
                0, 200, 255, 100,
                false, false, 2, false, nil, nil, false)

            if IsControlJustReleased(0, 38) then
                openRaceUI()
            end
        end

        Wait(sleep)
    end
end)

local function openRaceUI()
    local status = Sunset.AwaitCallback('sunset:racing:status')
    if not status then
        exports.sunset_ui:Notify('Could not load race status.', 'error')
        return
    end
    exports.sunset_ui:Send('racingShow', status)
    exports.sunset_ui:SetFocus(true, true, false, 'racing')
end

local function closeRaceUI()
    exports.sunset_ui:Send('racingHide', {})
    exports.sunset_ui:SetFocus(false, false, false, 'racing')
end

-- ── Race events ──
RegisterNetEvent('sunset:racing:start', function(data)
    raceActive = true
    raceData = data
    currentCheckpoint = 1
    closeRaceUI()

    -- Create checkpoint blips
    clearRaceBlips()
    if data.checkpoints then
        for i, cp in ipairs(data.checkpoints) do
            local blip = AddBlipForCoord(cp.x, cp.y, cp.z)
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, i == 1 and 0 or 1)
            SetBlipScale(blip, 0.9)
            SetBlipRoute(blip, i == 1)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(('CP %d/%d'):format(i, #data.checkpoints))
            EndTextCommandSetBlipName(blip)
            raceBlips[#raceBlips + 1] = blip
        end
    end

    -- Show race HUD
    exports.sunset_ui:Send('racingHud', {
        label = data.label,
        totalCheckpoints = data.checkpoints and #data.checkpoints or 0,
        currentCheckpoint = 0,
        countdown = data.countdown,
    })
end)

RegisterNetEvent('sunset:racing:countdown', function(n)
    exports.sunset_ui:Send('racingCountdown', { n = n })
end)

RegisterNetEvent('sunset:racing:go', function()
    exports.sunset_ui:Send('racingGo', {})
end)

RegisterNetEvent('sunset:racing:checkpointReached', function(data)
    currentCheckpoint = data.current + 1

    -- Update blips
    clearRaceBlips()
    if raceData and raceData.checkpoints then
        for i = currentCheckpoint, #raceData.checkpoints do
            local cp = raceData.checkpoints[i]
            local blip = AddBlipForCoord(cp.x, cp.y, cp.z)
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, i == currentCheckpoint and 0 or 1)
            SetBlipScale(blip, 0.9)
            SetBlipRoute(blip, i == currentCheckpoint)
            SetBlipAsShortRange(blip, true)
            raceBlips[#raceBlips + 1] = blip
        end
    end

    exports.sunset_ui:Send('racingHud', {
        label = raceData and raceData.label or 'Race',
        totalCheckpoints = raceData and raceData.checkpoints and #raceData.checkpoints or 0,
        currentCheckpoint = data.current,
    })
end)

RegisterNetEvent('sunset:racing:finished', function(data)
    exports.sunset_ui:Send('racingFinished', data)
end)

RegisterNetEvent('sunset:racing:end', function(data)
    raceActive = false
    raceData = nil
    currentCheckpoint = 1
    clearRaceBlips()
    exports.sunset_ui:Send('racingHudHide', {})
end)

function clearRaceBlips()
    for _, blip in ipairs(raceBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    raceBlips = {}
end

-- ── Checkpoint proximity detection ──
CreateThread(function()
    while true do
        if raceActive and raceData and raceData.checkpoints then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local target = veh ~= 0 and veh or ped
            local coords = GetEntityCoords(target)
            local cp = raceData.checkpoints[currentCheckpoint]

            if cp and #(coords - cp) < 15.0 then
                TriggerServerEvent('sunset:racing:checkpoint', currentCheckpoint)
                currentCheckpoint = currentCheckpoint + 1

                if currentCheckpoint > #raceData.checkpoints then
                    -- All checkpoints done, wait for server confirmation
                    Wait(2000)
                end
            end
            Wait(200)
        else
            Wait(1000)
        end
    end
end)

-- ── NUI callbacks ──
AddEventHandler('sunset:nui:racingClose', function()
    closeRaceUI()
end)

AddEventHandler('sunset:nui:racingJoin', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:racing:join', data.routeId)
        if not res then
            exports.sunset_ui:Notify(err or 'Could not join the race.', 'error')
            return
        end
        exports.sunset_ui:Notify(('Joined race lobby (%d/%d players).'):format(res.players, res.minPlayers), 'success')
        closeRaceUI()
    end)
end)

AddEventHandler('sunset:nui:racingLeave', function()
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:racing:leave')
        if not res then
            exports.sunset_ui:Notify(err or 'Could not leave the lobby.', 'error')
            return
        end
        closeRaceUI()
    end)
end)

-- ESC closes race UI
CreateThread(function()
    while true do
        if IsPauseMenuActive() and not raceActive then
            closeRaceUI()
        end
        Wait(250)
    end
end)

exports('IsRaceActive', function() return raceActive end)
