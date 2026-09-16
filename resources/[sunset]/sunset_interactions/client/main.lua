local menuOpen = false
local activeTarget = nil
local promptTarget = nil
local lockedTarget = nil
local contextRequestActive = false
local contextRequestNonce = 0
local holdActive = false
local menuCloseArmed = false
local lastPromptVisible = false
local contactBusy = false      -- prevents add-to-contacts spam
local contactCooldownUntil = 0 -- timestamp; blocks rapid re-triggers

local TARGET_SCAN_DISTANCE = 3.2
local HOLD_VALIDATE_DISTANCE = 3.5
local MENU_VALIDATE_DISTANCE = 3.5
local SCREEN_CONE_RADIUS = 0.34
local SINGLE_TARGET_CONE_RADIUS = 0.50
local CURRENT_TARGET_RELEASE_RADIUS = 0.43
local CAMERA_SCORE_WEIGHT = 0.82
local DISTANCE_SCORE_WEIGHT = 0.18
local SWITCH_SCORE_RATIO = 0.75
local SWITCH_MIN_GAIN = 0.035
local TARGET_SCAN_INTERVAL_MS = 125

local function notify(message, kind, duration)
    exports.sunset_ui:Notify(message, kind or 'info', duration)
end

local function isChatOpen()
    if GetResourceState('sunset_chat') ~= 'started' then return false end
    local ok, open = pcall(function()
        return exports.sunset_chat:IsChatOpen()
    end)
    return ok and open == true
end

local function inputIsBusy()
    return isChatOpen() or IsNuiFocused() or IsPauseMenuActive()
end

local function playerFromServerId(serverId)
    serverId = tonumber(serverId)
    if not serverId or serverId <= 0 then return nil end
    for _, player in ipairs(GetActivePlayers()) do
        if NetworkIsPlayerActive(player) and GetPlayerServerId(player) == serverId then return player end
    end
    return nil
end

local function getSharedVehicleSeat(localPed, targetPed)
    if not IsPedInAnyVehicle(localPed, false) or not IsPedInAnyVehicle(targetPed, false) then return nil end
    local localVehicle = GetVehiclePedIsIn(localPed, false)
    if localVehicle == 0 or localVehicle ~= GetVehiclePedIsIn(targetPed, false) then return nil end
    for seat = -1, GetVehicleMaxNumberOfPassengers(localVehicle) - 1 do
        if GetPedInVehicleSeat(localVehicle, seat) == targetPed then return seat end
    end
    return nil
end

local function sharingVehicle()
    local me = PlayerPedId()
    if not IsPedInAnyVehicle(me, false) then return false end
    local vehicle = GetVehiclePedIsIn(me, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and ped ~= me and IsPedAPlayer(ped) then return true end
    end
    return false
end

local function validateInteractionTarget(serverId, maxDistance, requireLos)
    local player = playerFromServerId(serverId)
    if not player or player == PlayerId() then return false end

    local me = PlayerPedId()
    local ped = GetPlayerPed(player)
    if me == 0 or ped == 0 or not DoesEntityExist(me) or not DoesEntityExist(ped) then return false end

    local distance = #(GetEntityCoords(me) - GetEntityCoords(ped))
    if distance > (maxDistance or TARGET_SCAN_DISTANCE) then return false end

    local sharedSeat = getSharedVehicleSeat(me, ped)
    if requireLos and sharedSeat == nil and not HasEntityClearLosToEntity(me, ped, 17) then return false end
    return true, player, ped, distance, sharedSeat
end

local function getInteractionCandidates(maxDistance)
    local candidates = {}
    local me = PlayerPedId()
    local myCoords = GetEntityCoords(me)
    local limit = maxDistance or TARGET_SCAN_DISTANCE

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() and NetworkIsPlayerActive(player) then
            local ped = GetPlayerPed(player)
            if ped ~= 0 and DoesEntityExist(ped) then
                local distance = #(myCoords - GetEntityCoords(ped))
                local seat = getSharedVehicleSeat(me, ped)
                local hasLos = seat ~= nil or HasEntityClearLosToEntity(me, ped, 17)
                if distance <= limit and hasLos then
                    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.08)
                    local projected, screenX, screenY = World3dToScreen2d(head.x, head.y, head.z)
                    local screenDistance = math.huge
                    if projected then
                        local dx, dy = screenX - 0.5, screenY - 0.5
                        screenDistance = math.sqrt(dx * dx + dy * dy)
                    end
                    candidates[#candidates + 1] = {
                        serverId = GetPlayerServerId(player),
                        player = player,
                        ped = ped,
                        distance = distance,
                        normalizedDistance = math.min(1.0, distance / limit),
                        projected = projected == true,
                        screenX = screenX,
                        screenY = screenY,
                        screenDistance = screenDistance,
                        sameVehicle = seat ~= nil,
                        seat = seat,
                    }
                end
            end
        end
    end
    return candidates
end

local function scoreInteractionCandidate(candidate)
    if not candidate or not candidate.projected then return math.huge end
    return candidate.screenDistance * CAMERA_SCORE_WEIGHT
        + candidate.normalizedDistance * DISTANCE_SCORE_WEIGHT
end

local function debugTargetSelection(reason, selected, candidates)
    if GetConvarInt('sv_sunset_interactions_debug', 0) ~= 1 then return end
    local rows = {}
    for _, candidate in ipairs(candidates or {}) do
        rows[#rows + 1] = ('#%d d=%.2f screen=%s score=%s seat=%s'):format(
            candidate.serverId,
            candidate.distance,
            candidate.projected and ('%.3f'):format(candidate.screenDistance) or 'offscreen',
            candidate.score < math.huge and ('%.3f'):format(candidate.score) or 'inf',
            candidate.sameVehicle and tostring(candidate.seat) or '-')
    end
    print(('[sunset_interactions:target] %s selected=%s locked=%s active=%s | %s'):format(
        reason,
        selected and tostring(selected.serverId) or 'none',
        tostring(lockedTarget),
        tostring(activeTarget),
        table.concat(rows, '; ')))
end

local function selectBestInteractionTarget(candidates, currentServerId)
    if #candidates == 0 then return nil, 'no_candidates' end

    local sameVehicle = {}
    local current = nil
    for _, candidate in ipairs(candidates) do
        candidate.score = scoreInteractionCandidate(candidate)
        if candidate.serverId == currentServerId then current = candidate end
        if candidate.sameVehicle then sameVehicle[#sameVehicle + 1] = candidate end
    end

    if #sameVehicle == 1 then return sameVehicle[1], 'single_vehicle_occupant' end

    local pool = #sameVehicle > 0 and sameVehicle or candidates
    if #sameVehicle > 0 and current and not current.sameVehicle then current = nil end
    local cameraEligible = {}
    for _, candidate in ipairs(pool) do
        if candidate.projected and candidate.screenDistance <= SCREEN_CONE_RADIUS then
            cameraEligible[#cameraEligible + 1] = candidate
        end
    end

    table.sort(cameraEligible, function(a, b)
        if math.abs(a.score - b.score) > 0.0001 then return a.score < b.score end
        return a.serverId < b.serverId
    end)

    local best = cameraEligible[1]
    if not best and #pool == 1 then
        local only = pool[1]
        if only.sameVehicle or (only.projected and only.screenDistance <= SINGLE_TARGET_CONE_RADIUS) then
            best = only
        end
    end

    if not best and #sameVehicle > 1 then
        table.sort(sameVehicle, function(a, b)
            if a.seat ~= b.seat then return a.seat < b.seat end
            return a.serverId < b.serverId
        end)
        best = sameVehicle[1]
        return best, 'vehicle_seat_fallback'
    end
    if not best then return nil, 'outside_selection_cone' end

    if current and current.serverId ~= best.serverId and current.projected
        and current.screenDistance <= CURRENT_TARGET_RELEASE_RADIUS then
        local gain = current.score - best.score
        local ratioAllows = best.score <= current.score * SWITCH_SCORE_RATIO
        if not ratioAllows or gain < SWITCH_MIN_GAIN then
            return current, 'hysteresis_keep'
        end
        return best, 'meaningfully_better'
    end
    return best, current and 'current_best' or 'new_target'
end

local function getPromptDisplayName(player)
    local serverId = GetPlayerServerId(player)
    local name = GetPlayerName(player) or ('Player #' .. serverId)
    return ('%s (%d)'):format(name, serverId)
end

local lastScreenX, lastScreenY = nil, nil
local lastPromptTarget = nil
local promptPlayerCache = nil

local function promptPlayerFromServerId(serverId)
    if promptPlayerCache and NetworkIsPlayerActive(promptPlayerCache)
        and GetPlayerServerId(promptPlayerCache) == tonumber(serverId) then
        return promptPlayerCache
    end
    promptPlayerCache = playerFromServerId(serverId)
    return promptPlayerCache
end

local function hidePlayerPrompt()
    if not lastPromptVisible then return end
    lastPromptVisible = false
    lastScreenX, lastScreenY = nil, nil
    lastPromptTarget = nil
    promptPlayerCache = nil
    exports.sunset_ui:Send('playerInteractionPrompt', { visible = false })
end

local function sendPlayerPrompt(serverId, extra)
    local player = promptPlayerFromServerId(serverId)
    if not player then
        hidePlayerPrompt()
        return
    end

    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then
        hidePlayerPrompt()
        return
    end

    local headCoords = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    if headCoords.x == 0.0 and headCoords.y == 0.0 and headCoords.z == 0.0 then
        headCoords = GetEntityCoords(ped) + vector3(0.0, 0.0, 0.85)
    else
        headCoords = headCoords + vector3(0.0, 0.0, 0.40)
    end

    local visible, screenX, screenY = World3dToScreen2d(headCoords.x, headCoords.y, headCoords.z)
    if not visible then
        hidePlayerPrompt()
        return
    end

    local sx = screenX * 100.0
    local sy = screenY * 100.0
    if not extra and lastPromptTarget == serverId and lastScreenX
        and math.abs(sx - lastScreenX) < 0.15 and math.abs(sy - lastScreenY) < 0.15 then
        return
    end
    lastScreenX, lastScreenY = sx, sy
    lastPromptTarget = serverId

    lastPromptVisible = true
    local payload = {
        visible = true,
        x = sx,
        y = sy,
        name = getPromptDisplayName(player),
        key = 'G',
    }
    if type(extra) == 'table' then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end
    exports.sunset_ui:Send('playerInteractionPrompt', payload)
end

local function setHoldState(active)
    holdActive = active == true
    local targetId = lockedTarget or promptTarget
    if not targetId or menuOpen then return end
    sendPlayerPrompt(targetId, { holding = holdActive })
end

local function cancelTargetLock(keepPrompt)
    if holdActive then setHoldState(false) end
    holdActive = false
    lockedTarget = nil
    menuCloseArmed = false
    if not keepPrompt then hidePlayerPrompt() end
end

local function closeMenu()
    contextRequestNonce = contextRequestNonce + 1
    contextRequestActive = false
    lockedTarget = nil
    if not menuOpen then return end
    menuOpen = false
    activeTarget = nil
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
end

local function openMenu(requestedTarget)
    if menuOpen then return end
    if contextRequestActive or inputIsBusy() then return end
    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) then return notify('You cannot interact while downed.', 'error') end

    local targetId = tonumber(requestedTarget or lockedTarget or promptTarget)
    if not targetId then return notify('No player is close enough. Move within 3 metres and try again.', 'info') end
    if not validateInteractionTarget(targetId, HOLD_VALIDATE_DISTANCE, true) then
        cancelTargetLock(false)
        return notify('That player is no longer available or close enough.', 'info')
    end

    lockedTarget = targetId
    hidePlayerPrompt()
    holdActive = false
    menuCloseArmed = false

    contextRequestNonce = contextRequestNonce + 1
    local requestNonce = contextRequestNonce
    contextRequestActive = true
    local context, err = Sunset.AwaitCallback('sunset:interactionContext', targetId)
    if requestNonce ~= contextRequestNonce then return end
    contextRequestActive = false
    if lockedTarget ~= targetId or inputIsBusy() then
        cancelTargetLock(false)
        return
    end
    if not context then
        cancelTargetLock(false)
        return notify(err or 'The interaction menu could not be opened.', 'error', 6000)
    end

    if not validateInteractionTarget(targetId, HOLD_VALIDATE_DISTANCE, true) then
        cancelTargetLock(false)
        return notify('That player moved away before the interaction menu opened.', 'info')
    end
    activeTarget = targetId
    lockedTarget = nil
    menuOpen = true
    exports.sunset_ui:Send('playerInteractionShow', context)
    exports.sunset_ui:SetFocus(true, true)
end

AddEventHandler('sunset:client:chatFocusChanged', function(open)
    if open == true then
        contextRequestNonce = contextRequestNonce + 1
        contextRequestActive = false
        cancelTargetLock(false)
        if menuOpen then closeMenu() end
    end
end)

RegisterCommand('interact', function()
    if menuOpen then
        closeMenu()
        return
    end
    local candidates = getInteractionCandidates(TARGET_SCAN_DISTANCE)
    local selected = selectBestInteractionTarget(candidates, promptTarget)
    if not selected then return notify('Look toward a nearby player and try again.', 'info') end
    promptTarget = selected.serverId
    lockedTarget = selected.serverId
    local targetId = lockedTarget
    CreateThread(function() openMenu(targetId) end)
end, false)

RegisterCommand('+interactplayer', function()
    if menuOpen then
        if menuCloseArmed then
            closeMenu()
            menuCloseArmed = false
        end
        return
    end
    if contextRequestActive or inputIsBusy() then return end
    if not promptTarget then
        local selected = selectBestInteractionTarget(getInteractionCandidates(TARGET_SCAN_DISTANCE), nil)
        promptTarget = selected and selected.serverId or nil
    end
    if not promptTarget or not validateInteractionTarget(promptTarget, HOLD_VALIDATE_DISTANCE, true) then return end
    lockedTarget = promptTarget
    if sharingVehicle() then
        local targetId = lockedTarget
        CreateThread(function() openMenu(targetId) end)
        return
    end
    setHoldState(true)
end, false)

RegisterCommand('-interactplayer', function()
    if menuOpen then
        menuCloseArmed = true
        return
    end
    cancelTargetLock(true)
    -- [UX] Releasing G inside a shared vehicle hides the prompt again
    -- (ambient prompts are suppressed there; only hold shows it).
    if sharingVehicle() then hidePlayerPrompt() end
end, false)

AddEventHandler('sunset:nui:playerInteractionHoldComplete', function()
    local targetId = lockedTarget
    if menuOpen or contextRequestActive or inputIsBusy() or not targetId then return end
    if not validateInteractionTarget(targetId, HOLD_VALIDATE_DISTANCE, true) then
        cancelTargetLock(false)
        return
    end
    holdActive = false
    menuCloseArmed = false
    CreateThread(function() openMenu(targetId) end)
end)

RegisterKeyMapping('+interactplayer', 'Interact with nearby player (hold)', 'keyboard', 'G')

local CallbackActions = {
    cuff = 'sunset:detentionCuff',
    uncuff = 'sunset:detentionUncuff',
    escort = 'sunset:detentionEscort',
    put_vehicle = 'sunset:detentionPutInVehicle',
    take_vehicle = 'sunset:detentionTakeOut',
    frisk = 'sunset:detentionFrisk',
    confiscate = 'sunset:policeConfiscate',
    summon = 'sunset:policeSummon',
    arrest = 'sunset:policeArrest',
    stabilize = 'sunset:emsStabilize',
    heal = 'sunset:emsHeal',
    revive = 'sunset:emsRevive',
    repair_vehicle = 'sunset:mechanicRepair',
    faction_invite = 'sunset:factionInvite',
}

local function showInventoryResult(title, rows)
    exports.sunset_ui:Send('chatMessage', { id = 0, name = 'INTERACTION', message = title, time = '' })
    if type(rows) ~= 'table' or #rows == 0 then
        exports.sunset_ui:Send('chatMessage', { id = 0, name = 'INTERACTION', message = 'No items found.', time = '' })
        return
    end
    for _, row in ipairs(rows) do
        exports.sunset_ui:Send('chatMessage', {
            id = 0, name = 'INTERACTION', message = ('%s x%d'):format(row.label or row.item or 'Item', tonumber(row.count) or 0), time = '',
        })
    end
end

local function refreshMenu()
    if not menuOpen or not activeTarget then return end
    local targetId = activeTarget
    if not validateInteractionTarget(targetId, MENU_VALIDATE_DISTANCE, false) then return closeMenu() end
    local context = Sunset.AwaitCallback('sunset:interactionContext', targetId)
    if menuOpen and activeTarget == targetId
        and validateInteractionTarget(targetId, MENU_VALIDATE_DISTANCE, false)
        and context then
        exports.sunset_ui:Send('playerInteractionUpdate', context)
    end
end

AddEventHandler('sunset:nui:playerInteractionClose', function()
    holdActive = false
    menuCloseArmed = false
    closeMenu()
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not menuOpen or not activeTarget then return end
    data = type(data) == 'table' and data or {}
    local action = tostring(data.action or '')
    local value = data.value
    local result, err

    if action == 'give_cash' then
        result, err = Sunset.AwaitCallback('sunset:interactionGiveCash', activeTarget, value)
        if result then
            notify(('You gave $%s to %s.'):format(result.amount, result.target), 'success')
        else
            notify(err or 'Could not transfer cash.', 'error', 6000)
        end
    elseif action == 'trade' then
        local target = activeTarget
        closeMenu()
        local res, tradeErr = Sunset.AwaitCallback('sunset:inventory:tradeRequest', { targetId = target })
        if not res then
            notify(tradeErr or 'Could not initiate trade.', 'error')
        elseif res.message then
            notify(res.message, res.kind or 'info')
        end
        return
    elseif action == 'add_friend' or action == 'add_contact' then
        -- Guard: one add-contact at a time, with a 4-second cooldown after completion.
        if contactBusy or GetGameTimer() < contactCooldownUntil then
            notify('Please wait before adding another contact.', 'warning', 3000)
            return
        end
        contactBusy = true
        result, err = Sunset.AwaitCallback('sunset:interactionAddFriend', activeTarget)
        contactBusy = false
        contactCooldownUntil = GetGameTimer() + 4000
        if result then
            notify(('%s has been saved to your contacts (%s).'):format(result.name, result.phone), 'success')
            if GetResourceState('sunset_phone') == 'started' then
                local refreshed = Sunset.AwaitCallback('sunset:getPhoneData')
                if refreshed then exports.sunset_ui:Send('phoneUpdate', refreshed) end
            end
        end
    elseif action == 'ticket' then
        local target = activeTarget
        closeMenu()
        ExecuteCommand(('ticket %d'):format(target))
        return
    elseif action == 'set_wanted' then
        result, err = Sunset.AwaitCallback('sunset:policeSetWanted', activeTarget, tostring(value or ''))
    elseif action == 'taxi_fare' then
        result, err = Sunset.AwaitCallback('sunset:taxiFare', activeTarget, tonumber(value))
        if result then notify(('Fare offer of $%d sent.'):format(result.amount or tonumber(value) or 0), 'success') end
    elseif action == 'license_exam' then
        local licenseType = tostring(value or '')
        if licenseType ~= 'pilot' and licenseType ~= 'boat' and licenseType ~= 'weapon' then
            err = 'Select a valid license exam.'
        else
            local target = activeTarget
            closeMenu()
            ExecuteCommand(('issuelicense %d %s'):format(target, licenseType))
            return
        end
    elseif CallbackActions[action] then
        result, err = Sunset.AwaitCallback(CallbackActions[action], activeTarget)
        if action == 'frisk' and result then showInventoryResult(('Search results for player #%d:'):format(activeTarget), result) end
        if action == 'confiscate' and result then showInventoryResult(('Confiscated from player #%d:'):format(activeTarget), result) end
    else
        err = 'That interaction is no longer available. Reopen the menu.'
    end

    if result == nil or result == false then
        if err then notify(err, 'error', 6500) end
    end
    refreshMenu()
end)

CreateThread(function()
    while true do
        if menuOpen then
            if not validateInteractionTarget(activeTarget, MENU_VALIDATE_DISTANCE, false)
                or IsPedDeadOrDying(PlayerPedId(), true) or IsPauseMenuActive() then
                closeMenu()
            end
            Wait(350)
        else
            Wait(750)
        end
    end
end)

CreateThread(function()
    while true do
        -- [UX] In a shared vehicle: no ambient name tag / "hold G" prompt.
        -- The prompt only appears while G is actually held (see setHoldState).
        if promptTarget and not menuOpen and not contextRequestActive and not inputIsBusy()
            and not (sharingVehicle() and not holdActive) then
            sendPlayerPrompt(lockedTarget or promptTarget)
            Wait(16)
        else
            Wait(200)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = TARGET_SCAN_INTERVAL_MS
        local me = PlayerPedId()

        if lockedTarget then
            if not validateInteractionTarget(lockedTarget, HOLD_VALIDATE_DISTANCE, true)
                or IsPedDeadOrDying(me, true) or inputIsBusy() then
                debugTargetSelection('locked_target_invalid', nil, {})
                cancelTargetLock(false)
            end
            sleep = 75
        elseif activeTarget or menuOpen or contextRequestActive then
            sleep = 350
        elseif not inputIsBusy() and not IsPedDeadOrDying(me, true) then
            local candidates = getInteractionCandidates(TARGET_SCAN_DISTANCE)
            local selected, reason = selectBestInteractionTarget(candidates, promptTarget)
            local nextTarget = selected and selected.serverId or nil
            if nextTarget ~= promptTarget then
                debugTargetSelection(reason, selected, candidates)
                promptTarget = nextTarget
                if not promptTarget then hidePlayerPrompt() end
            end
        else
            promptTarget = nil
            cancelTargetLock(false)
            sleep = 350
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        contextRequestNonce = contextRequestNonce + 1
        lockedTarget = nil
        hidePlayerPrompt()
        closeMenu()
    end
end)
