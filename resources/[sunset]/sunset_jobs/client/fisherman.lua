local JC = Sunset.JobClient
local fishing = false
local rod = nil
local selling = false
local fishingUiMode = 'hidden'

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

local function fishingUi(action, data)
    exports.sunset_ui:Send(action, data or {})
end

local function hideFishingUi()
    fishingUiMode = 'hidden'
    fishingUi('fishingHide', {})
end

local function buildShiftMessage()
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

local function showFishingState(state, extra)
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
        local d = #(pos - spot.coords)
        if d < bestDist then bestDist = d; best = i end
    end
    return best, bestDist
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
            JC.sessionData = result.session
            local cfg = Sunset.GetJobConfig('fisherman')
            local spotIdx = nearestSpotIndex()
            local spot = cfg.spots and cfg.spots[spotIdx]
            if spot then
                JC.setWaypoint(spot.coords)
            end
            showFishingShift()
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
    showFishingShift()
    JC.notify(('Fishing bag: %d/%d. Catch with E or /fish; use /sellfish at any time to mark the buyer.'):format(
        data.carried or 0, data.capacity or 2), 'info', 9000)

    CreateThread(function()
        while JC.jobId == 'fisherman' and JC.state ~= 'IDLE' do
            local spotIdx, spotDist = nearestSpotIndex()
            local cfg2 = Sunset.GetJobConfig('fisherman')
            local spot = cfg2.spots[spotIdx]

            if spot and spotDist <= (cfg2.catchRadius or 8.0) then
                JC.drawMarker(spot.coords, 52, 152, 219)
            end

            local sell = cfg2.sellPoint.coords
            if (JC.sessionData.pendingValue or 0) > 0 then
                JC.drawMarker(sell, 255, 200, 50)
                if JC.isNear(sell, cfg2.sellRadius or 5.0) then
                    JC.showHelp(('Press ~INPUT_CONTEXT~ to sell your fish ($%d before buyer bonus)'):format(
                        JC.sessionData.pendingValue or 0))
                end
            end
            Wait(0)
        end
        fishing = false
        hideFishingUi()
        removeRod()
    end)
end

local function attemptFish()
    if fishing then return JC.notify('Your line is already cast', 'warning') end
    if JC.jobId ~= 'fisherman' or JC.state == 'IDLE' then
        return JC.notify('Start a fisherman shift with /work first', 'error')
    end
    local spotIdx, spotDist = nearestSpotIndex()
    local cfg = Sunset.GetJobConfig('fisherman')
    local spot = cfg.spots and cfg.spots[spotIdx]
    if spotDist > (cfg.catchRadius or 8.0) then
        return JC.notify('Stand inside a blue fishing marker', 'error')
    end

    fishing = true
    fishingUiMode = 'hidden'
    alignPlayerAtSpot(spot)

    local cast, err = Sunset.AwaitCallback('sunset:jobs:fisherman:cast', spotIdx)
    if not cast then
        fishing = false
        return JC.notify(err or 'Could not cast', 'error')
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
        if IsControlJustPressed(0, 38) then
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
            if IsControlJustPressed(0, 38) then reeled = true break end
            Wait(0)
        end

        if reeled then
            result, reelErr = Sunset.AwaitCallback('sunset:jobs:fisherman:reel', spotIdx, token)
            if result then
                showFishingState('success', { message = 'You caught a fish!' })
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
        JC.sessionData.pendingValue = result.pendingValue
        JC.sessionData.carried = result.carried
        JC.sessionData.capacity = result.capacity
        local sellLabel = cfg.sellPoint.label or 'Fish Buyer'
        JC.setWaypoint(cfg.sellPoint.coords)
        showFishingShift(('Caught! Bag %d/%d · %s — /sellfish'):format(
            result.carried or 0, result.capacity or 2, sellLabel))
        JC.notify(('Fresh Fish added to inventory (%d/%d). Buyer marked on GPS; press E or /sellfish there.'):format(
            result.carried or 0, result.capacity or 2), 'success', 9000)
    else
        local _, distance = nearestSpotIndex()
        if distance <= (cfg.catchRadius or 8.0) then
            showFishingState('idle')
            fishingUiMode = 'idle'
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

CreateThread(function()
    while true do
        if JC.jobId == 'fisherman' and JC.state ~= 'IDLE' and not fishing then
            local _, distance = nearestSpotIndex()
            local cfg = Sunset.GetJobConfig('fisherman')
            if distance <= (cfg.catchRadius or 8.0) then
                if fishingUiMode ~= 'idle' then
                    showFishingState('idle')
                    fishingUiMode = 'idle'
                end
                if IsControlJustPressed(0, 38) then
                    CreateThread(attemptFish)
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
                Wait(400)
            end
        else
            if not fishing and fishingUiMode ~= 'hidden' then hideFishingUi() end
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
                if IsControlJustPressed(0, 38) then CreateThread(attemptSell) end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

TriggerEvent('chat:addSuggestion', '/fish', 'Cast your fishing rod at a marked fishing spot')
TriggerEvent('chat:addSuggestion', '/sellfish', 'Mark the Fish Buyer or sell fish at Del Perro Pier')

Sunset.Jobs.StartFisherman = startFisherman
