local menuOpen = false
local activeTarget = nil
local promptTarget = nil
local promptPlayer = nil
local contextRequestActive = false

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

local function closestPlayer(maxDistance)
    local me = PlayerPedId()
    local myCoords = GetEntityCoords(me)
    local closest, distance = nil, maxDistance or 3.0
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            if ped ~= 0 and DoesEntityExist(ped) then
                local current = #(myCoords - GetEntityCoords(ped))
                if current <= distance and HasEntityClearLosToEntity(me, ped, 17) then
                    closest, distance = GetPlayerServerId(player), current
                end
            end
        end
    end
    return closest, distance
end

local function playerFromServerId(serverId)
    if not serverId then return nil end
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == serverId then return player end
    end
    return nil
end

local function drawPlayerPrompt(player)
    local ped = player and GetPlayerPed(player) or 0
    if ped == 0 or not DoesEntityExist(ped) then return end

    local headCoords = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    if headCoords.x == 0.0 and headCoords.y == 0.0 and headCoords.z == 0.0 then
        headCoords = GetEntityCoords(ped) + vector3(0.0, 0.0, 0.85)
    else
        headCoords = headCoords + vector3(0.0, 0.0, 0.40)
    end

    local visible, screenX, screenY = World3dToScreen2d(headCoords.x, headCoords.y, headCoords.z)
    if not visible then return end

    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - headCoords)
    local fov = (1.0 / GetGameplayCamFov()) * 100.0
    local scale = (1.0 / dist) * fov * 0.55
    if scale < 0.22 then scale = 0.22 end
    if scale > 0.32 then scale = 0.32 end

    local boxW = 0.088 * (scale / 0.28)
    local boxH = 0.028 * (scale / 0.28)

    -- Dark glass badge background (matches --pi-bg-base: rgba(13, 13, 20, 0.94))
    DrawRect(screenX, screenY + 0.0125, boxW, boxH, 13, 13, 20, 225)

    -- Cyan accent bottom border (matches --pi-accent: #00ffcc)
    DrawRect(screenX, screenY + 0.0125 + (boxH / 2) - 0.001, boxW, 0.0022, 0, 255, 204, 255)

    -- Crisp text: [G] INTERACTION
    SetTextFont(4)
    SetTextScale(0.0, scale)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(2, 0, 0, 0, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName('~HUD_COLOUR_NET_PLAYER1~[G]~s~  INTERACTION')
    EndTextCommandDisplayText(screenX, screenY)
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    activeTarget = nil
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
end

local function openMenu()
    if menuOpen then return closeMenu() end
    if contextRequestActive or inputIsBusy() then return end
    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) then return notify('You cannot interact while downed.', 'error') end

    local targetId = closestPlayer(3.0)
    if not targetId then return notify('No player is close enough. Move within 3 metres and try again.', 'info') end

    contextRequestActive = true
    local context, err = Sunset.AwaitCallback('sunset:interactionContext', targetId)
    contextRequestActive = false
    if inputIsBusy() then return end
    if not context then return notify(err or 'The interaction menu could not be opened.', 'error', 6000) end

    local currentTarget = closestPlayer(3.0)
    if currentTarget ~= targetId then
        return notify('That player moved away before the interaction menu opened.', 'info')
    end
    activeTarget = targetId
    menuOpen = true
    exports.sunset_ui:Send('playerInteractionShow', context)
    exports.sunset_ui:SetFocus(true, true)
end


AddEventHandler('sunset:client:chatFocusChanged', function(open)
    if open == true then
        contextRequestActive = false
        if menuOpen then closeMenu() end
    end
end)

RegisterCommand('interactplayer', openMenu, false)
RegisterCommand('interact', openMenu, false)
RegisterKeyMapping('interactplayer', 'Interact with nearby player', 'keyboard', 'G')

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
    local targetNow = closestPlayer(3.5)
    if targetNow ~= activeTarget then return closeMenu() end
    local context = Sunset.AwaitCallback('sunset:interactionContext', activeTarget)
    if context then exports.sunset_ui:Send('playerInteractionUpdate', context) end
end

AddEventHandler('sunset:nui:playerInteractionClose', closeMenu)
AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not menuOpen or not activeTarget then return end
    data = type(data) == 'table' and data or {}
    local action = tostring(data.action or '')
    local value = data.value
    local result, err

    if action == 'give_cash' then
        result, err = Sunset.AwaitCallback('sunset:interactionGiveCash', activeTarget, value)
        if result then notify(('You gave $%s to %s.'):format(result.amount, result.target), 'success') end
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
        result, err = Sunset.AwaitCallback('sunset:interactionAddFriend', activeTarget)
        if result then
            notify(('%s a fost salvat în contacte (%s).'):format(result.name, result.phone), 'success')
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
            local current = closestPlayer(4.0)
            if current ~= activeTarget or IsPedDeadOrDying(PlayerPedId(), true) or IsPauseMenuActive() then
                closeMenu()
            end
            Wait(350)
        else
            Wait(750)
        end
    end
end)

CreateThread(function()
    local lastScan = 0
    while true do
        local sleep = 250
        local me = PlayerPedId()

        if not menuOpen and not contextRequestActive and not inputIsBusy()
            and not IsPedDeadOrDying(me, true) then

            local myCoords = GetEntityCoords(me)
            local currentPed = promptPlayer and GetPlayerPed(promptPlayer) or 0

            -- 1. If we already have a locked player, update and draw every frame (0ms) so it never lags behind
            if currentPed ~= 0 and DoesEntityExist(currentPed) then
                local targetCoords = GetEntityCoords(currentPed)
                local dist = #(myCoords - targetCoords)
                if dist <= 3.35 and HasEntityClearLosToEntity(me, currentPed, 17) then
                    drawPlayerPrompt(promptPlayer)
                    sleep = 0
                else
                    promptTarget = nil
                    promptPlayer = nil
                end
            else
                promptTarget = nil
                promptPlayer = nil
            end

            -- 2. Periodically scan for the closest player if none locked or check timeout
            local now = GetGameTimer()
            if not promptPlayer or (now - lastScan > 200) then
                lastScan = now
                local targetId, dist = closestPlayer(3.2)
                if targetId then
                    promptTarget = targetId
                    promptPlayer = playerFromServerId(targetId)
                    if promptPlayer then sleep = 0 end
                end
            end
        else
            promptTarget = nil
            promptPlayer = nil
            sleep = 350
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeMenu() end
end)
