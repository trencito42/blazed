-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Street Racing (client/main.lua)
--  Race hub marker, checkpoint blips (named), race HUD, countdown,
--  freeze safety, checkpoint ACK model.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetRacing.Config
local raceActive = false
local raceData = nil
local currentCheckpoint = 1
local checkpointPending = false  -- waiting for server ACK
local raceBlips = {}
local hubBlip = nil
local frozen = false

-- ── Forward declarations ──
local openRaceUI
local closeRaceUI
local clearRaceBlips

-- ── Race hub marker ──
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sleep = 500

        if not raceActive and #(coords - Cfg.raceHub) < 8.0 then
            sleep = 0
            DrawMarker(1, Cfg.raceHub.x, Cfg.raceHub.y, Cfg.raceHub.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                2.5, 2.5, 1.0,
                0, 200, 255, 100,
                false, false, 2, false, nil, nil, false)

            if IsControlJustReleased(0, 38) then
                openRaceUI()
            end
        end

        Wait(sleep)
    end
end)

-- ── Hub blip ──
CreateThread(function()
    Wait(3000)
    if hubBlip and DoesBlipExist(hubBlip) then RemoveBlip(hubBlip) end
    hubBlip = AddBlipForCoord(Cfg.raceHub.x, Cfg.raceHub.y, Cfg.raceHub.z)
    SetBlipSprite(hubBlip, 562)
    SetBlipColour(hubBlip, 0)
    SetBlipScale(hubBlip, 0.8)
    SetBlipAsShortRange(hubBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Race Hub')
    EndTextCommandSetBlipName(hubBlip)
end)

local isRacingUiOpen = false

openRaceUI = function()
    local status = Sunset.AwaitCallback('sunset:racing:status')
    if not status then
        exports.sunset_ui:Notify('Could not load race status.', 'error')
        return
    end
    isRacingUiOpen = true
    exports.sunset_ui:Send('racingShow', status)
    exports.sunset_ui:SetFocus(true, true, false, 'racing')
end

closeRaceUI = function()
    if not isRacingUiOpen then return end
    isRacingUiOpen = false
    exports.sunset_ui:Send('racingHide', {})
    exports.sunset_ui:SetFocus(false, false, false, 'racing')
end

clearRaceBlips = function()
    for _, blip in ipairs(raceBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    raceBlips = {}
end

-- [BUG 1 FIX] Single helper for checkpoint blip creation.
-- Every blip ALWAYS gets an explicit name (never "Point of Interest").
local function createCheckpointBlip(index, total, checkpoint, isActive)
    local blip = AddBlipForCoord(checkpoint.x, checkpoint.y, checkpoint.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, isActive and 0 or 1)
    SetBlipScale(blip, isActive and 1.1 or 0.8)
    SetBlipRoute(blip, isActive)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('CP %d/%d'):format(index, total))
    EndTextCommandSetBlipName(blip)
    raceBlips[#raceBlips + 1] = blip
    return blip
end

-- ── Race events ──
RegisterNetEvent('sunset:racing:start', function(data)
    raceActive = true
    raceData = data
    currentCheckpoint = 1
    checkpointPending = false
    closeRaceUI()

    -- Create checkpoint blips (all with names)
    clearRaceBlips()
    if data.checkpoints then
        for i, cp in ipairs(data.checkpoints) do
            createCheckpointBlip(i, #data.checkpoints, cp, i == 1)
        end
    end

    exports.sunset_ui:Send('racingHud', {
        raceId = data.raceId,
        label = data.label,
        totalCheckpoints = data.checkpoints and #data.checkpoints or 0,
        currentCheckpoint = 0,
        countdown = data.countdown,
        isSolo = data.isSolo,
    })
end)

RegisterNetEvent('sunset:racing:countdown', function(n)
    exports.sunset_ui:Send('racingCountdown', { n = n })
end)

RegisterNetEvent('sunset:racing:go', function()
    exports.sunset_ui:Send('racingGo', {})
end)

-- [BUG 4 FIX] Client advances ONLY on server ACK.
RegisterNetEvent('sunset:racing:checkpointReached', function(data)
    checkpointPending = false
    currentCheckpoint = data.current + 1

    -- Update blips (only current + upcoming, all named)
    clearRaceBlips()
    if raceData and raceData.checkpoints then
        for i = currentCheckpoint, #raceData.checkpoints do
            createCheckpointBlip(i, #raceData.checkpoints, raceData.checkpoints[i], i == currentCheckpoint)
        end
    end

    exports.sunset_ui:Send('racingHud', {
        raceId = data.raceId,
        label = raceData and raceData.label or 'Race',
        totalCheckpoints = raceData and raceData.checkpoints and #raceData.checkpoints or 0,
        currentCheckpoint = data.current,
    })
end)

RegisterNetEvent('sunset:racing:finished', function(data)
    exports.sunset_ui:Send('racingFinished', data)
end)

RegisterNetEvent('sunset:racing:dnf', function(data)
    raceActive = false
    raceData = nil
    currentCheckpoint = 1
    checkpointPending = false
    clearRaceBlips()
    exports.sunset_ui:Send('racingHudHide', {})
    exports.sunset_ui:Notify(data and data.reason or 'DNF — race over.', 'error', 8000)
end)

RegisterNetEvent('sunset:racing:end', function(data)
    raceActive = false
    raceData = nil
    currentCheckpoint = 1
    checkpointPending = false
    clearRaceBlips()
    exports.sunset_ui:Send('racingHudHide', {})
end)

-- ── Vehicle freeze ──
RegisterNetEvent('sunset:racing:freeze', function(freeze)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        FreezeEntityPosition(veh, freeze == true)
        frozen = freeze == true
    end
end)

-- [BUG 10 FIX] Safety: unfreeze on resource stop
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if frozen then
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            FreezeEntityPosition(veh, false)
        end
        frozen = false
    end
    clearRaceBlips()
    if hubBlip and DoesBlipExist(hubBlip) then RemoveBlip(hubBlip) end
end)

-- ── Ground snapping helper ──
local function getGroundCoords(cp)
    if not cp then return cp end
    local found, groundZ = GetGroundZFor_3dCoord(cp.x, cp.y, cp.z + 50.0, false)
    if not found then
        found, groundZ = GetGroundZFor_3dCoord(cp.x, cp.y, cp.z + 150.0, false)
    end
    if found then
        return vector3(cp.x, cp.y, groundZ)
    end
    return cp
end

-- ── Checkpoint proximity detection & 3D markers ──
CreateThread(function()
    while true do
        if raceActive and raceData and raceData.checkpoints then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local target = veh ~= 0 and veh or ped
            local coords = GetEntityCoords(target)
            local cp = raceData.checkpoints[currentCheckpoint]

            if cp then
                local markerPos = getGroundCoords(cp)
                local dx, dy = coords.x - cp.x, coords.y - cp.y
                local hDist = math.sqrt(dx * dx + dy * dy)
                if hDist < 350.0 then
                    -- 3D Checkpoint ground ring
                    DrawMarker(1, markerPos.x, markerPos.y, markerPos.z - 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        12.0, 12.0, 2.5, 241, 196, 15, 170, false, false, 2, false, nil, nil, false)
                    -- Tall vertical beacon column beam
                    DrawMarker(1, markerPos.x, markerPos.y, markerPos.z - 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        3.0, 3.0, 30.0, 241, 196, 15, 65, false, false, 2, false, nil, nil, false)
                    -- Floating chevron arrow
                    DrawMarker(0, markerPos.x, markerPos.y, markerPos.z + 2.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        2.5, 2.5, 2.0, 241, 196, 15, 220, false, false, 2, false, nil, nil, false)
                end

                if not checkpointPending and hDist < (Cfg.checkpointRadius or 30.0) and math.abs(coords.z - markerPos.z) < 20.0 then
                    checkpointPending = true
                    TriggerServerEvent('sunset:racing:checkpoint', currentCheckpoint, raceData.raceId)
                    -- Timeout: if no ACK within 3s, allow retry (handles lost UDP)
                    CreateThread(function()
                        Wait(3000)
                        if checkpointPending and raceActive then
                            checkpointPending = false
                        end
                    end)
                end
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- ── Driver & Vehicle validation helper ──
local function validateVehicleForRace()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        exports.sunset_ui:Notify('You must be inside a vehicle at the Race Hub.', 'error')
        return false
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        exports.sunset_ui:Notify('You must be the driver of the vehicle.', 'error')
        return false
    end
    return true
end

-- ── NUI callbacks ──
AddEventHandler('sunset:nui:racingClose', function()
    closeRaceUI()
end)

AddEventHandler('sunset:nui:racingJoin', function(data)
    data = type(data) == 'table' and data or {}
    local routeId = tostring(data.routeId or '')
    if routeId == '' then
        exports.sunset_ui:Notify('No route selected.', 'error')
        return
    end
    if not validateVehicleForRace() then return end
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:racing:join', routeId)
        if not res then
            exports.sunset_ui:Notify(err or 'Race join failed. Check F8/server logs.', 'error')
            return
        end
        exports.sunset_ui:Notify(('Joined %s lobby (%d/%d players).'):format(
            routeId, res.players, res.minPlayers), 'success')
        closeRaceUI()
    end)
end)

-- Solo start
AddEventHandler('sunset:nui:racingStartSolo', function(data)
    data = type(data) == 'table' and data or {}
    local routeId = tostring(data.routeId or '')
    if routeId == '' then
        exports.sunset_ui:Notify('No route selected.', 'error')
        return
    end
    if not validateVehicleForRace() then return end
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:racing:startSolo', routeId)
        if not res then
            exports.sunset_ui:Notify(err or 'Solo start failed. Check F8/server logs.', 'error')
            return
        end
        closeRaceUI()
    end)
end)

-- Multiplayer start (explicit)
AddEventHandler('sunset:nui:racingStartMulti', function(data)
    data = type(data) == 'table' and data or {}
    local routeId = tostring(data.routeId or '')
    if routeId == '' then
        exports.sunset_ui:Notify('No route selected.', 'error')
        return
    end
    if not validateVehicleForRace() then return end
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:racing:startMulti', routeId)
        if not res then
            exports.sunset_ui:Notify(err or 'Multiplayer start failed.', 'error')
            return
        end
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

RegisterCommand('quitrace', function()
    if not raceActive then
        exports.sunset_ui:Notify('You are not currently in an active race.', 'info')
        return
    end
    CreateThread(function()
        local ok, err = Sunset.AwaitCallback('sunset:racing:quit')
        raceActive = false
        raceData = nil
        currentCheckpoint = 1
        checkpointPending = false
        clearRaceBlips()
        exports.sunset_ui:Send('racingHudHide', {})
        if ok then
            exports.sunset_ui:Notify('Race abandoned.', 'info')
        else
            exports.sunset_ui:Notify(err or 'Race cleared.', 'info')
        end
    end)
end, false)
RegisterCommand('cancelrace', function() ExecuteCommand('quitrace') end, false)
TriggerEvent('chat:addSuggestion', '/quitrace', 'Abandon current race or time trial')
TriggerEvent('chat:addSuggestion', '/cancelrace', 'Abandon current race or time trial')

exports('IsRaceActive', function() return raceActive end)
exports('CancelRace', function()
    if raceActive then
        raceActive = false
        raceData = nil
        currentCheckpoint = 1
        checkpointPending = false
        clearRaceBlips()
        exports.sunset_ui:Send('racingHudHide', {})
    end
end)
