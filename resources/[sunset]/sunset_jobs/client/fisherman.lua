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

local function verticalDist(pos, coords)
    return math.abs(pos.z - coords.z)
end

local function catchRadius(cfg)
    return (cfg and cfg.catchRadius) or 15.0
end

local function markerDrawRadius(cfg)
    return (cfg and cfg.markerDrawRadius) or 45.0
end

local function contextJustPressed()
    return IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38)
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

local function sessionBagPayload()
    local carried, capacity = bagCounts()
    return { carried = carried, capacity = capacity }
end

local function isFishermanShift()
    return JC.jobId == 'fisherman' and JC.state and JC.state ~= 'IDLE'
end

local function applyBagState(carried, capacity, pendingValue)
    JC.sessionData = JC.sessionData or {}
    if carried ~= nil then JC.sessionData.carried = carried end
    if capacity ~= nil then JC.sessionData.capacity = capacity end
    if pendingValue ~= nil then JC.sessionData.pendingValue = pendingValue end
end

local function fishingUi(action, data)
    exports.sunset_ui:Send(action, data or {})
end

local function hideFishingUi()
    fishingUiMode = 'hidden'
    fishingUi('fishingHide', {})
end

local function buildFullBagMessage()
    local carried, capacity = bagCounts()
    local cfg = Sunset.GetJobConfig('fisherman')
    local sellLabel = cfg and cfg.sellPoint and cfg.sellPoint.label or 'Fish Buyer'
    return ('Bag full %d/%d — yellow marker or /sellfish to sell at %s'):format(
        carried, capacity, sellLabel)
end

local function buildShiftMessage()
    if isBagFull() then
        return buildFullBagMessage()
    end
    return 'Blue marker: E or /fish · /sellfish marks the buyer'
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
    fishingUiMode = state
    fishingUi('fishingShow', payload)
end

local function showFishingShift()
    showFishingState('shift', {
        title = 'Fisherman',
        message = buildShiftMessage(),
    })
end

local function showFishingFull()
    showFishingState('full', {
        title = 'Bag Full',
        message = buildFullBagMessage(),
    })
end

local function refreshSpotUi()
    if isBagFull() then
        showFishingFull()
    else
        showFishingState('idle')
    end
end

local function nearestSpotIndex()
    local cfg = Sunset.GetJobConfig('fisherman') or {}
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist = 1, 999999.0
    for i, spot in ipairs(cfg.spots or {}) do
        local d = horizontalDist(pos, spot.coords)
        if d < bestDist then bestDist = d; best = i end
    end
    return best, bestDist
end

local function atFishingSpot()
    local spotIndex, distance = nearestSpotIndex()
    local cfg = Sunset.GetJobConfig('fisherman')
    local spot = cfg and cfg.spots and cfg.spots[spotIndex]
    local zDistance = spot and verticalDist(GetEntityCoords(PlayerPedId()), spot.coords) or math.huge
    return distance <= catchRadius(cfg) and zDistance <= (cfg.catchZTolerance or 0.75), distance, cfg, zDistance
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

local function drawShiftMarkers(cfg)
    if not cfg or not cfg.spots then return end
    local pos = GetEntityCoords(PlayerPedId())
    local drawRadius = markerDrawRadius(cfg)
    for _, spot in ipairs(cfg.spots) do
        if horizontalDist(pos, spot.coords) <= drawRadius then
            JC.drawFishingMarker(spot.coords, 52, 152, 219, cfg.markerSize)
        end
    end
    local sell = cfg.sellPoint and cfg.sellPoint.coords
    if sell and isBagFull() then
        if horizontalDist(pos, sell) <= drawRadius then
            JC.drawMarker(sell, 255, 200, 50)
        end
    end
end

local function ensureFishermanShiftLoop()
    if shiftLoopActive then return end
    shiftLoopActive = true
    CreateThread(function()
        while isFishermanShift() do
            drawShiftMarkers(Sunset.GetJobConfig('fisherman'))
            Wait(0)
        end
        shiftLoopActive = false
    end)
end

local function applyShiftBlips(data)
    local cfg = Sunset.GetJobConfig('fisherman')
    JC.clearBlips()
    for i, spot in ipairs(cfg.spots or {}) do
        JC.addBlip(spot.coords, spot.blip or { sprite = 68, color = 3 }, 'Fishing Spot ' .. i)
    end
    JC.addBlip(cfg.sellPoint.coords, cfg.sellPoint.blip, cfg.sellPoint.label or 'Fish Buyer')
    JC.sessionData = data or JC.sessionData or {}
    JC.hideObjective()
    if isBagFull() then
        JC.setWaypoint(cfg.sellPoint.coords)
        showFishingFull()
    else
        if cfg.spots and cfg.spots[1] then
            JC.setWaypoint(cfg.spots[1].coords)
        end
        local atSpot = atFishingSpot()
        if atSpot then
            refreshSpotUi()
        else
            showFishingShift()
        end
    end
    ensureFishermanShiftLoop()
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
    if not result then
        return JC.notify(sellErr or 'Could not sell the fish. Stay inside the yellow marker and try again.', 'error')
    end

    JC.notify(('Sold %d fish for $%s'):format(result.count or 0, result.amount or 0), 'success')
    applyBagState(0, (result.session and result.session.capacity) or (JC.sessionData and JC.sessionData.capacity), 0)
    if result.session then
        JC.sessionData = result.session
        JC.sessionData.carried = 0
        JC.sessionData.pendingValue = 0
    end
    local spotIdx = nearestSpotIndex()
    local spot = cfg.spots and cfg.spots[spotIdx]
    if spot then JC.setWaypoint(spot.coords) end
    if atFishingSpot() then
        refreshSpotUi()
    else
        showFishingShift()
    end
    JC.notify('Shift still active — stand in a blue marker and press E to fish.', 'info', 7000)
end

local function startFisherman()
    local data, err = Sunset.AwaitCallback('sunset:jobs:fisherman:start')
    if not data then
        JC.notify(err or 'Could not start fishing', 'error')
        return
    end
    JC.jobId = 'fisherman'
    if not JC.state or JC.state == 'IDLE' then
        JC.state = 'STARTING'
    end
    applyShiftBlips(data)
    local carried, capacity = bagCounts()
    JC.notify(('Fishing bag: %d/%d. Stand in a blue marker and press E or /fish.'):format(
        carried, capacity), 'info', 9000)
end

local function attemptFish()
    if fishing then return JC.notify('Your line is already cast', 'warning') end
    if not isFishermanShift() then
        return JC.notify('Start a fisherman shift with /work first', 'error')
    end
    local spotIdx, spotDist = nearestSpotIndex()
    local cfg = Sunset.GetJobConfig('fisherman')
    local spot = cfg.spots and cfg.spots[spotIdx]
    local spotZDist = spot and verticalDist(GetEntityCoords(PlayerPedId()), spot.coords) or math.huge
    if spotDist > catchRadius(cfg) or spotZDist > (cfg.catchZTolerance or 0.75) then
        return JC.notify('Stand inside the blue fishing marker', 'error')
    end
    if isBagFull() then
        local carried, capacity = bagCounts()
        JC.setWaypoint(cfg.sellPoint.coords)
        showFishingFull()
        return JC.notify(('Fishing bag full (%d/%d). Head to the Fish Buyer or use /sellfish.'):format(
            carried, capacity), 'warning', 8000)
    end

    fishing = true
    alignPlayerAtSpot(spot)

    local cast, err = Sunset.AwaitCallback('sunset:jobs:fisherman:cast', spotIdx)
    if not cast then
        fishing = false
        if err and string.find(string.lower(err), 'bag full', 1, true) then
            JC.setWaypoint(cfg.sellPoint.coords)
            showFishingFull()
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
                showFishingState('success', {
                    message = ('You caught a fish worth $%s!'):format(result.value or 0),
                    value = result.value,
                    carried = result.carried,
                    capacity = result.capacity,
                })
                Wait(1800)
            else
                showFishingState('failed', { message = reelErr or 'The fish escaped' })
                Wait(1800)
            end
        else
            Sunset.AwaitCallback('sunset:jobs:fisherman:miss', token)
            showFishingState('failed', { message = 'Too slow — the fish escaped' })
            Wait(1800)
        end
    end

    removeRod()
    fishing = false

    if result then
        applyBagState(result.carried, result.capacity, result.pendingValue)
        if isBagFull() then
            JC.setWaypoint(cfg.sellPoint.coords)
            showFishingFull()
            JC.notify(('Bag full (%d/%d). Go to Fish Buyer or /sellfish.'):format(
                result.carried or 0, result.capacity or 2), 'success', 9000)
        else
            refreshSpotUi()
            JC.notify(('Fresh Fish worth $%s added (%d/%d). Bag value: $%s. Press E to cast again.'):format(
                result.value or 0, result.carried or 0, result.capacity or 2,
                result.pendingValue or result.value or 0), 'success', 7000)
        end
    else
        refreshSpotUi()
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
        if isFishermanShift() then
            ensureFishermanShiftLoop()
            if not fishing then
                JC.hideObjective()
                local atSpot = atFishingSpot()
                if atSpot then
                    if isBagFull() then
                        if fishingUiMode ~= 'full' then showFishingFull() end
                    elseif fishingUiMode ~= 'idle' then
                        refreshSpotUi()
                    else
                        fishingUi('fishingUpdate', {
                            state = 'idle',
                            carried = (JC.sessionData or {}).carried,
                            capacity = (JC.sessionData or {}).capacity,
                        })
                    end
                    EnableControlAction(0, 38, true)
                    if not isBagFull() then
                        JC.showHelp('Press ~INPUT_CONTEXT~ to cast your line')
                        if contextJustPressed() then
                            CreateThread(attemptFish)
                        end
                    else
                        JC.showHelp('Bag full — /sellfish or go to the yellow Fish Buyer marker')
                    end
                    Wait(0)
                else
                    if isBagFull() then
                        if fishingUiMode ~= 'full' then showFishingFull() end
                    elseif fishingUiMode ~= 'hidden' then
                        hideFishingUi()
                    end
                    Wait(200)
                end
            else
                Wait(0)
            end
        else
            if fishingUiMode ~= 'hidden' then hideFishingUi() end
            fishing = false
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

RegisterNetEvent('sunset:jobs:sessionEnded', function(jobId)
    if jobId ~= 'fisherman' then return end
    hideFishingUi()
    fishing = false
    removeRod()
end)

Sunset.Jobs.StartFisherman = startFisherman
Sunset.Jobs.EnsureFishermanShift = function()
    if not isFishermanShift() then return end
    applyShiftBlips(JC.sessionData)
end
