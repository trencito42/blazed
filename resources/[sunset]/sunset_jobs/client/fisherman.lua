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

-- [FIX] MUST be declared before canCastLine(). Previously it was declared
-- AFTER the function, so the closure captured the GLOBAL (nil) instead of the
-- local — every call raised "attempt to perform arithmetic on a nil value",
-- which killed the shift thread and silently disabled E-to-fish + markers.
local lastInventoryClose = 0

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

-- Point-in-polygon client-side (ray casting) pentru zona de pescuit.
-- [DEBUG] Returns (inside, info) — info carries the same values the server
-- checks so client/server agreement can be verified with /fishdebug.
local function pointInZone(pos, zone)
    local inside = false
    local j = #zone
    for i = 1, #zone do
        local xi, yi = zone[i].x, zone[i].y
        local xj, yj = zone[j].x, zone[j].y
        if ((yi > pos.y) ~= (yj > pos.y)) and
           (pos.x < (xj - xi) * (pos.y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function atFishingSpotDetailed()
    local cfg = Sunset.GetJobConfig('fisherman') or {}
    local zone = cfg.fishZone
    local pos  = GetEntityCoords(PlayerPedId())
    local spotIndex, spotDist = nearestSpotIndex()
    local info = {
        x = pos.x, y = pos.y, z = pos.z,
        spotIndex = spotIndex,
        spotDist = spotDist,
        jobId = JC.jobId,
        shiftState = JC.state,
        minZ = cfg.fishZoneMinZ or -5.0,
        maxZ = cfg.fishZoneMaxZ or 12.0,
        mode = 'polygon',
    }

    if not zone or #zone < 3 then
        info.mode = 'radius-fallback'
        local spot = cfg.spots and cfg.spots[spotIndex]
        local zDistance = spot and verticalDist(pos, spot.coords) or math.huge
        info.zDist = zDistance
        info.inside = (spotDist <= catchRadius(cfg)) and (zDistance <= (cfg.catchZTolerance or 0.75))
        return info.inside, info
    end

    info.zoneVertices = #zone
    if pos.z < info.minZ or pos.z > info.maxZ then
        info.inside = false
        info.zRejected = true
        return false, info
    end

    info.inside = pointInZone(pos, zone)
    return info.inside, info
end

local function atFishingSpot()
    return atFishingSpotDetailed()
end

local function removeRod()
    local keepRod = false
    if rod and GetResourceState('sunset_inventory') == 'started' then
        keepRod = exports.sunset_inventory:IsHotbarPropEntity(rod) == true
    end
    if rod and not keepRod and DoesEntityExist(rod) then
        DeleteEntity(rod)
    end
    rod = nil
    if not keepRod then
        ClearPedTasks(PlayerPedId())
    end
end

local function equipRod()
    if GetResourceState('sunset_inventory') == 'started' then
        local existing = exports.sunset_inventory:GetHotbarPropEntity('prop_fishing_rod_01')
        if existing and DoesEntityExist(existing) then
            rod = existing
            return true
        end
    end

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
    if not cfg then return end
    local pos = GetEntityCoords(PlayerPedId())

    -- Spot marker(s)
    if cfg.spots then
        local drawRadius = markerDrawRadius(cfg)
        for _, spot in ipairs(cfg.spots) do
            if horizontalDist(pos, spot.coords) <= drawRadius then
                JC.drawFishingMarker(spot.coords, 52, 152, 219, cfg.markerSize)
            end
        end
    end

    -- [ZONE FIX] Draw the fishing-zone boundary near the player so nobody has
    -- to guess where the invisible polygon is. Edges at water level.
    local zone = cfg.fishZone
    if zone and #zone >= 3 then
        local drawZ = 1.0
        for i, p in ipairs(zone) do
            local n = zone[(i % #zone) + 1]
            local midX, midY = (p.x + n.x) / 2, (p.y + n.y) / 2
            if #(pos - vector3(midX, midY, pos.z)) < 120.0 then
                DrawLine(p.x, p.y, drawZ, n.x, n.y, drawZ, 0, 200, 255, 160)
            end
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

local function fishingZoneCenter()
    local cfg = Sunset.GetJobConfig('fisherman') or {}
    local zone = cfg.fishZone
    if zone and #zone >= 3 then
        local sx, sy, n = 0.0, 0.0, #zone
        for _, p in ipairs(zone) do sx = sx + p.x; sy = sy + p.y end
        return vector3(sx / n, sy / n, 1.0)
    end
    local spot = cfg.spots and cfg.spots[1]
    return spot and spot.coords or nil
end

local function applyShiftBlips()
    JC.clearBlips()
    -- [FLOW FIX] Players had no idea where the invisible polygon was. On shift
    -- start: GPS route + blip + objective pointing at the fishing area, then
    -- the objective flips to the cast prompt once the player arrives.
    local center = fishingZoneCenter()
    if center then
        JC.addBlip(center, { sprite = 68, color = 3, scale = 0.8 }, 'Paleto Bay Fishing Area')
        JC.setWaypoint(center)
    end
    JC.showObjective('Go to the Paleto Bay fishing area', 'Follow the GPS — cast your line at the pontoon')
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
        JC.hideObjective()
    else
        JC.notify(err or 'Could not end shift.', 'error')
    end
end

local function startFisherman()
    local jobId = JC.getCharacterJob()
    if jobId ~= 'fisherman' then
        JC.notify('You must be a Fisherman. Speak with Billy Ray.', 'error', 6000)
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
    JC.notify('Shift started! GPS set to the Paleto Bay fishing area. Press E once you are at the water to cast.', 'info', 8000)
end

local function attemptFish()
    if fishing then return JC.notify('Your line is already cast', 'warning') end
    if not isFishermanShift() then
        return JC.notify('Start a fisherman shift with /work first', 'error')
    end
    local spotIdx = nearestSpotIndex()
    if not atFishingSpot() then
        return JC.notify('You are not in the Paleto Bay fishing area.', 'error')
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
                    message = ('%s caught! %.1f kg — $%s'):format(fishLabel, result.fishKg or 0, result.value or 0),
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
        JC.notify(('%s %.1f kg +$%s. Sell your fish at any 24/7 store.'):format(
            fishLabel2, result.fishKg or 0, result.value or 0), 'success', 5000)
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

-- ── [PHASE 1 DEBUG] /fishdebug — draws the fishing polygon in-world and dumps
--    the SAME values the server checks, so client/server agreement is visible.
local fishDebugEnabled = false
RegisterCommand('fishdebug', function()
    fishDebugEnabled = not fishDebugEnabled
    JC.notify(fishDebugEnabled and 'Fish debug ON — polygon + values drawn.' or 'Fish debug OFF.', 'info')
end, false)

CreateThread(function()
    while true do
        if fishDebugEnabled then
            local cfg = Sunset.GetJobConfig('fisherman') or {}
            local zone = cfg.fishZone
            local inside, info = atFishingSpotDetailed()

            -- Vertices + edges (drawn at water level z=1.0)
            if zone and #zone >= 3 then
                local drawZ = 1.0
                for i, p in ipairs(zone) do
                    DrawMarker(1, p.x, p.y, drawZ, 0, 0, 0, 0, 0, 0,
                        1.0, 1.0, 8.0, 255, 0, 0, 120, false, false, 2, false, nil, nil, false)
                    DrawMarker(4, p.x, p.y, drawZ + 1.0, 0, 0, 0, 0, 0, 0,
                        0.6, 0.6, 0.6, 255, 200, 0, 200, false, false, 2, false, nil, nil, false)
                    local n = zone[(i % #zone) + 1]
                    -- edge line between consecutive vertices
                    DrawLine(p.x, p.y, drawZ + 0.5, n.x, n.y, drawZ + 0.5, 0, 255, 204, 255)
                end
            end

            -- Live readout on screen (left side, stacked)
            local lines = {
                ('pos: %.2f, %.2f, %.2f'):format(info.x, info.y, info.z),
                ('insideFishZone: %s'):format(tostring(inside)),
                ('mode: %s  vertices: %s  zRange: %.1f..%.1f'):format(
                    info.mode, tostring(info.zoneVertices or '-'), info.minZ, info.maxZ),
                ('nearest spot: #%s  dist: %.1fm'):format(tostring(info.spotIndex), info.spotDist or 0),
                ('job: %s  shiftState: %s'):format(tostring(info.jobId), tostring(info.shiftState)),
                ('canCastLine: %s  isFishermanShift: %s'):format(
                    tostring(canCastLine()), tostring(isFishermanShift())),
            }
            if info.zRejected then lines[#lines + 1] = 'REJECTED BY Z LIMIT' end
            for i, line in ipairs(lines) do
                SetTextFont(4)
                SetTextScale(0.3, 0.3)
                SetTextColour(0, 255, 204, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextOutline()
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(('[FISHDEBUG] ' .. line))
                EndTextCommandDisplayText(0.015, 0.30 + (i * 0.022))
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

RegisterCommand('sw', function()
    CreateThread(stopShift)
end, false)

RegisterCommand('stopwork', function()
    CreateThread(stopShift)
end, false)

CreateThread(function()
    local lastObjective = nil
    local function setObjectiveOnce(title, sub)
        local key = tostring(title) .. '|' .. tostring(sub)
        if lastObjective == key then return end
        lastObjective = key
        JC.showObjective(title, sub)
    end
    while true do
        if isFishermanShift() then
            ensureFishermanShiftLoop()
            if not fishing then
                local atSpot = atFishingSpot()
                if atSpot then
                    -- [E FIX] Press E ONCE to cast (IsControlJustPressed OR the
                    -- disabled variant, since fishingshop disables control 38
                    -- near Billy Ray). canCastLine() gates focus/menus/NPC.
                    setObjectiveOnce('Cast your line', '[E] Cast Fishing Rod')
                    if canCastLine() and contextJustPressed() then
                        CreateThread(attemptFish)
                    end
                    Wait(0)
                else
                    setObjectiveOnce('Go to the Paleto Bay fishing area',
                        'Follow the GPS — cast your line at the pontoon')
                    Wait(200)
                end
            else
                setObjectiveOnce('Reel it in', 'Watch for the bite — press E in time')
                Wait(0)
            end
        else
            if lastObjective then
                lastObjective = nil
            end
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
        exports.sunset_ui:Notify('You must be a Fisherman. Speak with Billy Ray.', 'error', 5000)
        return
    end
    if isFishermanShift() then
        exports.sunset_ui:Notify('You already have an active shift. Press E at the pontoon or use /fish.', 'info', 5000)
        return
    end
    CreateThread(startFisherman)
end)
