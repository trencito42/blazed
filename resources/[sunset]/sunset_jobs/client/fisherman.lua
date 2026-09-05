local JC = Sunset.JobClient
local fishing = false
local rod = nil
local selling = false
local fishingUiMode = 'hidden'
local shiftLoopActive = false

local function horizontalDist(pos, coords)
    local dx = pos.x - coords.x
    local dy = pos.y - coords.y
    return math.sqrt(dx * dx + dy * dy)
end

local function catchRadius(cfg)
    return (cfg and cfg.catchRadius) or 15.0
end

local function markerDrawRadius(cfg)
    return (cfg and cfg.markerDrawRadius) or 45.0
end

local function isWithinCatchRadius(distance, cfg)
    return distance <= catchRadius(cfg)
end

local function atFishingSpot()
    local _, distance = nearestSpotIndex()
    local cfg = Sunset.GetJobConfig('fisherman')
    return isWithinCatchRadius(distance, cfg), distance, cfg
end

local function contextJustPressed()
    return IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38)
end

local function fishBagProgress(carried, capacity)
    capacity = math.max(tonumber(capacity) or 2, 1)
    carried = math.max(0, tonumber(carried) or 0)
    return math.floor((carried / capacity) * 100)
end

local function sessionBagProgress()
    local data = JC.sessionData or {}
    return fishBagProgress(data.carried, data.capacity)
end

local function sessionBagPayload()
    local data = JC.sessionData or {}
    return {
        carried = data.carried or 0,
        capacity = data.capacity or 2,
    }
end

local function bagCounts()
    local data = JC.sessionData or {}
    local carried = math.max(0, tonumber(data.carried) or 0)
    local capacity = math.max(tonumber(data.capacity) or 2, 1)
    return carried, capacity
end

local function isBagFull()
    local carried, capacity = bagCounts()
    return carried >= capacity
end

local lastBagSync = 0
local lastCatchAt = 0

local function applyBagState(carried, capacity, pendingValue)
    JC.sessionData = JC.sessionData or {}
    if carried ~= nil then JC.sessionData.carried = carried end
    if capacity ~= nil then JC.sessionData.capacity = capacity end
    if pendingValue ~= nil then JC.sessionData.pendingValue = pendingValue end
end

local function pushFishingBagUi()
    local carried, capacity = bagCounts()
    fishingUi('fishingUpdate', {
        bagOnly = true,
        carried = carried,
        capacity = capacity,
    })
end

local function syncBagFromServer()
    local now = GetGameTimer()
    if now - lastBagSync < 2000 then return end
    if fishing then return end
    if now - lastCatchAt < 4000 then return end
    lastBagSync = now
    if JC.jobId ~= 'fisherman' or JC.state == 'IDLE' then return end
    local status = Sunset.AwaitCallback('sunset:jobs:fisherman:bagStatus')
    if not status then return end
    applyBagState(status.carried, status.capacity, status.pendingValue)
    if fishingUiMode ~= 'hidden' and not fishing then
        pushFishingBagUi()
    end
end

local function buildFullBagMessage()
    local carried, capacity = bagCounts()
    local cfg = Sunset.GetJobConfig('fisherman')
    local sellLabel = cfg and cfg.sellPoint and cfg.sellPoint.label or 'Fish Buyer'
    return ('Bag full %d/%d — yellow marker or /sellfish to sell at %s'):format(
        carried, capacity, sellLabel)
end

local function fishingUi(action, data)
    exports.sunset_ui:Send(action, data or {})
end

local function hideFishingUi()
    fishingUiMode = 'hidden'
    fishingUi('fishingHide', {})
end

local function buildShiftMessage()
    if isBagFull() then
        return buildFullBagMessage()
    end
    local data = JC.sessionData or {}
    local pending = tonumber(data.pendingValue) or 0
    if pending > 0 then
        return ('Fish worth $%d — yellow marker or /sellfish to sell'):format(pending)
    end
    return 'Blue marker: E or /fish · /sellfish marks the buyer'
end

local function showFishingShift(message)
    fishingUiMode = 'shift'
    showFishingState('shift', {
        title = 'Fisherman',
        message = message or buildShiftMessage(),
    })
end

local function showFishingFull(message)
    fishingUiMode = 'full'
    showFishingState('full', {
        title = 'Bag Full',
        message = message or buildFullBagMessage(),
    })
end

local function refreshSpotUi()
    if isBagFull() then
        showFishingFull()
    else
        showFishingState('idle')
        fishingUiMode = 'idle'
    end
end

local function spotUiMode()
    return isBagFull() and 'full' or 'idle'
end

local function showFishingState(state, extra)
    if state == 'idle' and isBagFull() then
        state = 'full'
        extra = extra or {}
        extra.title = extra.title or 'Bag Full'
        extra.message = extra.message or buildFullBagMessage()
    end
    local payload = sessionBagPayload()
    payload.state = state
    if extra then
        for k, v in pairs(extra) do payload[k] = v end
    end
    fishingUi('fishingShow', payload)
end

local function alignPlayerAtSpot(spot)
    if not spot or not spot.coords then return end
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, spot.coords.x, spot.coords.y, spot.coords.z, false, false, false)
    if spot.heading then
        SetEntityHeading(ped, spot.heading + 0.0)
    end
end

local function removeRod()
    if rod and DoesEntityExist(rod) then DeleteEntity(rod) end
    rod = nil
    ClearPedTasks(PlayerPedId())
end

local function equipRod()
    local model = joaat('prop_fishing_rod_01')
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(model) then return false end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    rod = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(rod, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.02, -0.02, 80.0, 120.0, 160.0,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
    return true
end

local function nearestSpotIndex()
    local cfg = Sunset.GetJobConfig('fisherman')
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local best, bestDist = 1, 999999.0
    for i, spot in ipairs(cfg.spots or {}) do
        local d = horizontalDist(pos, spot.coords)
        if d < bestDist then bestDist = d; best = i end
    end
    return best, bestDist
end

local function drawShiftMarkers(cfg)
    if not cfg or not cfg.spots then return end
    local pos = GetEntityCoords(PlayerPedId())
    local drawRadius = markerDrawRadius(cfg)
    for _, spot in ipairs(cfg.spots) do
        if horizontalDist(pos, spot.coords) <= drawRadius then
            JC.drawFishingMarker(spot.coords, 52, 152, 219)
        end
    end
    local sell = cfg.sellPoint and cfg.sellPoint.coords
    if sell and (JC.sessionData and (JC.sessionData.pendingValue or 0) > 0) then
        if horizontalDist(pos, sell) <= drawRadius then
            JC.drawMarker(sell, 255, 200, 50)
        end
    end
end

local function ensureFishermanShiftLoop()
    if shiftLoopActive then return end
    shiftLoopActive = true

    CreateThread(function()
        while JC.jobId == 'fisherman' and JC.state ~= 'IDLE' do
            local cfg = Sunset.GetJobConfig('fisherman')
            drawShiftMarkers(cfg)

            local sell = cfg and cfg.sellPoint and cfg.sellPoint.coords
            if sell and (JC.sessionData and (JC.sessionData.pendingValue or 0) > 0) then
                if JC.isNear(sell, cfg.sellRadius or 5.0) then
                    JC.showHelp(('Press ~INPUT_CONTEXT~ to sell your fish ($%d before buyer bonus)'):format(
                        JC.sessionData.pendingValue or 0))
                end
            end
            Wait(0)
        end
        shiftLoopActive = false
    end)
end

local function attemptSell()
    if selling then return end
    local cfg = Sunset.GetJobConfig('fisherman')
    if not cfg or not cfg.sellPoint then return JC.notify('Fish Buyer is not configured', 'error') end
    if not JC.isNear(cfg.sellPoint.coords, cfg.sellRadius or 5.0) then
        JC.setWaypoint(cfg.sellPoint.coords)
        return JC.notify('Fish Buyer marked on GPS: Del Perro Pier. Enter the yellow marker and press E.', 'info', 8000)
    end

    selling = true
    local result, sellErr = Sunset.AwaitCallback('sunset:jobs:fisherman:sell')
    selling = false
    if result then
        JC.notify(('Sold %d fish for $%s'):format(result.count or 0, result.amount or 0), 'success')
        if result.session then
            applyBagState(result.session.carried, result.session.capacity, result.session.pendingValue)
            lastCatchAt = 0
            local cfg = Sunset.GetJobConfig('fisherman')
            local spotIdx = nearestSpotIndex()
            local spot = cfg.spots and cfg.spots[spotIdx]
            if spot then
                JC.setWaypoint(spot.coords)
            end
            refreshSpotUi()
            JC.notify('Shift still active — cast at the nearest blue fishing marker.', 'info', 7000)
        end
    else
        JC.notify(sellErr or 'Could not sell the fish. Stay inside the yellow marker and try again.', 'error')
    end
end

local function startFisherman()
    local data, err = Sunset.AwaitCallback('sunset:jobs:fisherman:start')
    if not data then
        JC.notify(err or 'Could not start fishing', 'error')
        return
    end

    local cfg = Sunset.GetJobConfig('fisherman')
    JC.clearBlips()
    for i, spot in ipairs(cfg.spots or {}) do
        JC.addBlip(spot.coords, spot.blip or { sprite = 68, color = 3 }, 'Fishing Spot ' .. i)
    end
    JC.addBlip(cfg.sellPoint.coords, cfg.sellPoint.blip, cfg.sellPoint.label or 'Fish Buyer')
    JC.sessionData = data
    JC.hideObjective()
    if (data.carried or 0) > 0 then
        JC.setWaypoint(cfg.sellPoint.coords)
    elseif cfg.spots and cfg.spots[1] then
        JC.setWaypoint(cfg.spots[1].coords)
    end
    if isBagFull() then
        showFishingFull()
    else
        showFishingShift()
    end
    JC.notify(('Fishing bag: %d/%d. Catch with E or /fish; use /sellfish at any time to mark the buyer.'):format(
        data.carried or 0, data.capacity or 2), 'info', 9000)

    ensureFishermanShiftLoop()
end

local function attemptFish()
    if fishing then return JC.notify('Your line is already cast', 'warning') end
    if JC.jobId ~= 'fisherman' or JC.state == 'IDLE' then
        return JC.notify('Start a fisherman shift with /work first', 'error')
    end
    local spotIdx, spotDist = nearestSpotIndex()
    local cfg = Sunset.GetJobConfig('fisherman')
    local spot = cfg.spots and cfg.spots[spotIdx]
    if spotDist > catchRadius(cfg) then
        return JC.notify('Stand inside the blue fishing marker', 'error')
    end

    syncBagFromServer()
    if isBagFull() then
        local carried, capacity = bagCounts()
        JC.setWaypoint(cfg.sellPoint.coords)
        refreshSpotUi()
        return JC.notify(('Fishing bag full (%d/%d). Head to the Fish Buyer or use /sellfish.'):format(
            carried, capacity), 'warning', 8000)
    end

    fishing = true
    fishingUiMode = 'hidden'
    alignPlayerAtSpot(spot)

    local cast, err = Sunset.AwaitCallback('sunset:jobs:fisherman:cast', spotIdx)
    if not cast then
        fishing = false
        if err and string.find(string.lower(err), 'bag full', 1, true) then
            JC.setWaypoint(cfg.sellPoint.coords)
            refreshSpotUi()
        else
            refreshSpotUi()
        end
        local notifyType = err and string.find(string.lower(err), 'bag full', 1, true) and 'warning' or 'error'
        return JC.notify(err or 'Could not cast', notifyType, 8000)
    end

    equipRod()
    JC.playAnim('amb@world_human_stand_fishing@idle_a', 'idle_c', -1)
    showFishingState('waiting')

    local delayMs = tonumber(cast.delayMs) or 3000
    local windowMs = tonumber(cast.windowMs) or 1500
    local token = cast.token
    local biteAt = GetGameTimer() + delayMs
    local early = false

    while GetGameTimer() < biteAt do
        if contextJustPressed() then
            early = true
            break
        end
        Wait(0)
    end

    local result, reelErr
    if early then
        Sunset.AwaitCallback('sunset:jobs:fisherman:miss', token)
        showFishingState('failed', { message = 'You pulled too early!' })
        Wait(2200)
    else
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        showFishingState('bite', { windowMs = windowMs })

        local deadline = GetGameTimer() + windowMs
        local reeled = false
        while GetGameTimer() <= deadline do
            if contextJustPressed() then reeled = true break end
            Wait(0)
        end

        if reeled then
            result, reelErr = Sunset.AwaitCallback('sunset:jobs:fisherman:reel', spotIdx, token)
            if result then
                applyBagState(result.carried, result.capacity, result.pendingValue)
                lastCatchAt = GetGameTimer()
                lastBagSync = lastCatchAt
                pushFishingBagUi()
                showFishingState('success', {
                    message = 'You caught a fish!',
                    carried = result.carried,
                    capacity = result.capacity,
                })
                Wait(2500)
            else
                showFishingState('failed', { message = reelErr or 'The fish escaped' })
                Wait(2200)
            end
        else
            Sunset.AwaitCallback('sunset:jobs:fisherman:miss', token)
            showFishingState('failed', { message = 'Too slow — the fish escaped' })
            Wait(2200)
        end
    end

    removeRod()
    fishing = false

    if result then
        applyBagState(result.carried, result.capacity, result.pendingValue)
        local sellLabel = cfg.sellPoint.label or 'Fish Buyer'
        JC.setWaypoint(cfg.sellPoint.coords)
        if isBagFull() then
            showFishingFull()
        else
            refreshSpotUi()
            fishingUi('fishingUpdate', {
                state = 'idle',
                carried = result.carried,
                capacity = result.capacity,
                message = ('Caught! Bag %d/%d · %s — /sellfish'):format(
                    result.carried or 0, result.capacity or 2, sellLabel),
            })
        end
        JC.notify(('Fresh Fish added to inventory (%d/%d). Buyer marked on GPS; press E or /sellfish there.'):format(
            result.carried or 0, result.capacity or 2), 'success', 9000)
    else
        local _, distance = nearestSpotIndex()
        if distance <= catchRadius(cfg) then
            refreshSpotUi()
        else
            showFishingShift()
        end
        if not early and reelErr then
            JC.notify(reelErr, 'warning')
        elseif not early then
            JC.notify('Too late — the fish escaped', 'warning')
        else
            JC.notify('Too early — the fish escaped', 'warning')
        end
    end
end

RegisterCommand('fish', function()
    CreateThread(attemptFish)
end, false)

RegisterCommand('sellfish', function()
    CreateThread(attemptSell)
end, false)

-- E must be polled every frame; Wait(400) in the UI loop misses single-frame presses.
CreateThread(function()
    while true do
        if JC.jobId == 'fisherman' and JC.state ~= 'IDLE' and not fishing then
            local atSpot = atFishingSpot()
            if atSpot then
                EnableControlAction(0, 38, true)
                JC.showHelp('Press ~INPUT_CONTEXT~ to cast your line')
                if contextJustPressed() then
                    CreateThread(attemptFish)
                end
                Wait(0)
            else
                Wait(200)
            end
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if JC.jobId == 'fisherman' and JC.state ~= 'IDLE' then
            ensureFishermanShiftLoop()
        end
        if JC.jobId == 'fisherman' and JC.state ~= 'IDLE' and not fishing then
            JC.hideObjective()
            if GetGameTimer() - lastBagSync > 2000 then
                CreateThread(syncBagFromServer)
            end
            local atSpot = atFishingSpot()
            if atSpot then
                local targetMode = spotUiMode()
                if fishingUiMode ~= targetMode then
                    refreshSpotUi()
                else
                    fishingUi('fishingUpdate', {
                        state = targetMode,
                        carried = (JC.sessionData or {}).carried,
                        capacity = (JC.sessionData or {}).capacity,
                        message = targetMode == 'full' and buildFullBagMessage() or nil,
                    })
                end
                Wait(0)
            else
                if fishingUiMode ~= 'shift' then
                    showFishingShift()
                else
                    fishingUi('fishingUpdate', {
                        state = 'shift',
                        carried = (JC.sessionData or {}).carried,
                        capacity = (JC.sessionData or {}).capacity,
                        message = buildShiftMessage(),
                    })
                end
                Wait(250)
            end
        else
            if not fishing and fishingUiMode ~= 'hidden' then hideFishingUi() end
            if JC.jobId ~= 'fisherman' or JC.state == 'IDLE' then
                fishing = false
                removeRod()
            end
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        local cfg = Sunset.GetJobConfig('fisherman')
        local employed = JC.getCharacterJob() == 'fisherman'
        if employed and cfg and cfg.sellPoint and JC.isNear(cfg.sellPoint.coords, 30.0) then
            JC.drawMarker(cfg.sellPoint.coords, 255, 200, 50)
            if JC.isNear(cfg.sellPoint.coords, cfg.sellRadius or 5.0) then
                JC.showHelp('Press ~INPUT_CONTEXT~ to sell all Fresh Fish in your inventory')
                if contextJustPressed() then CreateThread(attemptSell) end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

TriggerEvent('chat:addSuggestion', '/fish', 'Cast your fishing rod at a marked fishing spot')
TriggerEvent('chat:addSuggestion', '/sellfish', 'Mark the Fish Buyer or sell fish at Del Perro Pier')

AddEventHandler('sunset:jobs:stateChanged', function(_, data)
    if JC.jobId ~= 'fisherman' or fishing or not data then return end
    applyBagState(data.carried, data.capacity, data.pendingValue)
    if fishingUiMode == 'hidden' then return end
    if isBagFull() then
        showFishingFull()
    else
        pushFishingBagUi()
    end
end)

Sunset.Jobs.StartFisherman = startFisherman
Sunset.Jobs.EnsureFishermanShift = function()
    ensureFishermanShiftLoop()
    if fishingUiMode == 'hidden' and not fishing then
        if isBagFull() then
            showFishingFull()
        else
            showFishingShift()
        end
    end
end
