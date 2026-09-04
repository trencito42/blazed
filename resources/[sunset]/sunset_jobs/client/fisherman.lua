local JC = Sunset.JobClient
local fishing = false
local rod = nil

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
    JC.addBlip(cfg.sellPoint.coords, cfg.sellPoint.blip, 'Fish Buyer')
    JC.sessionData = data
    if cfg.spots and cfg.spots[1] then
        JC.setWaypoint(cfg.spots[1].coords)
    end
    JC.showObjective('Fishing', 'Stand in a blue marker and press E or type /fish', 0)
    JC.notify('At a blue fishing marker, press E or use /fish. Reel in when BITE appears.', 'info', 9000)

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
                if JC.isNear(sell, cfg2.sellRadius) and IsControlJustPressed(0, 38) then
                    local ok, result = Sunset.AwaitCallback('sunset:jobs:fisherman:sell')
                    if ok then
                        JC.notify(('Sold catch for $%s'):format(result and result.amount or 0), 'success')
                        break
                    end
                end
            end
            Wait(0)
        end
        fishing = false
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
    if spotDist > (cfg.catchRadius or 8.0) then
        return JC.notify('Stand inside a blue fishing marker', 'error')
    end

    fishing = true
    local cast, err = Sunset.AwaitCallback('sunset:jobs:fisherman:cast', spotIdx)
    if not cast then fishing = false return JC.notify(err or 'Could not cast', 'error') end

    equipRod()
    JC.playAnim('amb@world_human_stand_fishing@idle_a', 'idle_c', -1)
    JC.showObjective('Line cast', 'Wait for a bite…', 25)
    Wait(tonumber(cast.delayMs) or 3000)
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    JC.showObjective('BITE!', 'Press E now to reel the fish in', 75)

    local deadline = GetGameTimer() + (tonumber(cast.windowMs) or 1400)
    local reeled = false
    while GetGameTimer() <= deadline do
        if IsControlJustPressed(0, 38) then reeled = true break end
        Wait(0)
    end
    local result, reelErr
    if reeled then
        result, reelErr = Sunset.AwaitCallback('sunset:jobs:fisherman:reel', spotIdx, cast.token)
    else
        Sunset.AwaitCallback('sunset:jobs:fisherman:miss', cast.token)
    end
    removeRod()
    fishing = false
    if reeled and result then
        JC.sessionData.pendingValue = result.pendingValue
        JC.showObjective('Fishing', ('Catch value $%s · total $%s — /fish again or sell'):format(
            result.value, result.pendingValue), 50)
        JC.notify(('Caught fish worth $%s'):format(result.value), 'success')
    else
        JC.showObjective('Fishing', 'Fish escaped — press E or /fish to cast again', 0)
        JC.notify(reelErr or 'Too late — the fish escaped', 'warning')
    end
end

RegisterCommand('fish', function()
    CreateThread(attemptFish)
end, false)

CreateThread(function()
    while true do
        if JC.jobId == 'fisherman' and JC.state ~= 'IDLE' and not fishing then
            local _, distance = nearestSpotIndex()
            if distance <= ((Sunset.GetJobConfig('fisherman').catchRadius or 8.0)) and IsControlJustPressed(0, 38) then
                CreateThread(attemptFish)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

TriggerEvent('chat:addSuggestion', '/fish', 'Cast your fishing rod at a marked fishing spot')

Sunset.Jobs.StartFisherman = startFisherman
