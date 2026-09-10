local JC = Sunset.JobClient
local fishing = false
local rod = nil
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

local BAIT_SHOP_COORDS = vector3(-1602.11, 5203.87, 4.31)
local BAIT_SHOP_RADIUS = 2.5

local function isShopMenuOpen()
    if GetResourceState('sunset_fishingshop') ~= 'started' then return false end
    local ok, result = pcall(function() return exports.sunset_fishingshop:IsMenuOpen() end)
    return ok and result == true
end

local function nearBaitShop()
    return #(GetEntityCoords(PlayerPedId()) - BAIT_SHOP_COORDS) < BAIT_SHOP_RADIUS
end

local function canCastLine()
    if IsNuiFocused() or IsPauseMenuActive() then return false end
    if isShopMenuOpen() then return false end
    if (GetGameTimer() - lastInventoryClose) <= 500 then return false end
    if GetResourceState('sunset_fishingshop') == 'started' then
        local ok, nearNpc = pcall(function() return exports.sunset_fishingshop:IsNearBillyRay() end)
        if ok and nearNpc then return false end
    end
    if nearBaitShop() then return false end
    return true
end

-- Block E for 500ms after inventory closes so drop-pickup interaction
-- doesn't accidentally trigger a fishing cast
local lastInventoryClose = 0
AddEventHandler('sunset:nui:inventoryClose', function()
    lastInventoryClose = GetGameTimer()
end)

local function isFishermanShift()
    return JC.jobId == 'fisherman' and JC.state and JC.state ~= 'IDLE'
end

local function fishingUi(action, data)
    exports.sunset_ui:Send(action, data or {})
end

local function hideFishingUi()
    fishingUi('fishingHide', {})
end

local function showFishingState(state, extra)
    local payload = { state = state }
    if extra then
        for k, v in pairs(extra) do payload[k] = v end
    end
    fishingUi('fishingShow', payload)
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

local function applyShiftBlips()
    JC.clearBlips()
    JC.hideObjective()
    ensureFishermanShiftLoop()
end

local function stopShift()
    if not isFishermanShift() then
        JC.notify('No active shift.', 'info')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:jobs:cancelWork')
    if ok then
        JC.notify('Shift ended.', 'info')
        JC.jobId = nil
        JC.state = 'IDLE'
        fishing = false
        removeRod()
        hideFishingUi()
        JC.clearBlips()
    else
        JC.notify(err or 'Could not end shift.', 'error')
    end
end

local function startFisherman()
    local jobId = JC.getCharacterJob()
    if jobId ~= 'fisherman' then
        JC.notify('Trebuie sa fii angajat Pescar. Vorbeste cu Billy Ray.', 'error', 6000)
        return
    end

    local data, err = Sunset.AwaitCallback('sunset:jobs:fisherman:start')
    if not data then
        JC.notify(err or 'Could not start fishing', 'error')
        return
    end
    JC.jobId = 'fisherman'
    if not JC.state or JC.state == 'IDLE' then
        JC.state = 'STARTING'
    end
    applyShiftBlips()
    JC.notify('Tura inceput! Mergi la pontoon Paleto Bay si apasa E sa pescuiesti.', 'info', 7000)
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
        return JC.notify('Nu esti in zona de pescuit Paleto Bay.', 'error')
    end

    fishing = true

    local cast, err = Sunset.AwaitCallback('sunset:jobs:fisherman:cast', spotIdx)
    if not cast then
        fishing = false
        return JC.notify(err or 'Could not cast', 'error', 8000)
    end

    -- Avertizare fara momeala
    if (cast.baitTier or 0) == 0 then
        JC.notify('No bait! Catch chance is low. Buy bait from Fishing Supply.', 'warning', 5000)
    end

    -- Animatie scurta de aruncare
    local castDict = 'amb@world_human_stand_fishing@idle_a'
    RequestAnimDict(castDict)
    local dictTimer = GetGameTimer() + 3000
    while not HasAnimDictLoaded(castDict) and GetGameTimer() < dictTimer do Wait(50) end
    if HasAnimDictLoaded(castDict) then
        TaskPlayAnim(PlayerPedId(), castDict, 'idle_a', 3.0, -3.0, 900, 0, 0, false, false, false)
        Wait(800)
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
                local fishLabel = (result.fishItem or 'fish'):gsub('fish_', ''):gsub('^%l', string.upper)
                showFishingState('success', {
                    message = ('%s caught! $%s'):format(fishLabel, result.value or 0),
                    value = result.value,
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
        local fishLabel2 = ((result.fishItem or 'fish'):gsub('fish_', ''):gsub('^%l', string.upper))
        JC.notify(('%s +$%s. Vinde pestele la orice magazin 24/7.'):format(
            fishLabel2, result.value or 0), 'success', 5000)
    elseif not early and reelErr then
        JC.notify(reelErr, 'warning')
    elseif not early then
        JC.notify('Too late — the fish escaped', 'warning')
    else
        JC.notify('Too early — the fish escaped', 'warning')
    end

    hideFishingUi()
end

RegisterCommand('fish', function()
    CreateThread(attemptFish)
end, false)

RegisterCommand('sw', function()
    CreateThread(stopShift)
end, false)

RegisterCommand('stopwork', function()
    CreateThread(stopShift)
end, false)

CreateThread(function()
    while true do
        if isFishermanShift() then
            ensureFishermanShiftLoop()
            if not fishing then
                JC.hideObjective()
                local atSpot = atFishingSpot()
                if atSpot then
                    if canCastLine() and contextJustPressed() then
                        CreateThread(attemptFish)
                    end
                    Wait(0)
                else
                    Wait(200)
                end
            else
                Wait(0)
            end
        else
            hideFishingUi()
            fishing = false
            Wait(400)
        end
    end
end)

TriggerEvent('chat:addSuggestion', '/fish', 'Cast your fishing rod in the Paleto Bay fishing area')
TriggerEvent('chat:addSuggestion', '/sw', 'End your current work shift')
TriggerEvent('chat:addSuggestion', '/stopwork', 'End your current work shift')

RegisterNetEvent('sunset:jobs:sessionEnded', function(jobId)
    if jobId ~= 'fisherman' then return end
    hideFishingUi()
    fishing = false
    removeRod()
end)

Sunset.Jobs.StartFisherman = startFisherman
Sunset.Jobs.EnsureFishermanShift = function()
    if not isFishermanShift() then return end
    applyShiftBlips()
end

exports('IsFishermanShiftActive', function()
    return isFishermanShift()
end)

-- Event triggerabil din alte resurse (ex. sunset_fishingshop NPC)
AddEventHandler('sunset:client:startFishermanShift', function()
    local jobId = JC.getCharacterJob()
    if jobId ~= 'fisherman' then
        exports.sunset_ui:Notify('Trebuie sa fii angajat Pescar. Vorbeste cu Billy Ray.', 'error', 5000)
        return
    end
    if isFishermanShift() then
        exports.sunset_ui:Notify('Ai deja o tură activă. Apasă E la pontoon sau /fish.', 'info', 5000)
        return
    end
    CreateThread(startFisherman)
end)
