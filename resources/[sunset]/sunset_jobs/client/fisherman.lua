local JC = Sunset.JobClient
local fishing = false

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
    JC.notify('Fish at marked spots, then sell at the pier buyer', 'info')

    CreateThread(function()
        while JC.jobId == 'fisherman' and JC.state ~= 'IDLE' do
            local spotIdx, spotDist = nearestSpotIndex()
            local cfg2 = Sunset.GetJobConfig('fisherman')
            local spot = cfg2.spots[spotIdx]

            if spot and spotDist <= (cfg2.catchRadius or 8.0) and not fishing then
                JC.drawMarker(spot.coords, 52, 152, 219)
                if IsControlJustPressed(0, 38) then
                    fishing = true
                    JC.playAnim('amb@world_human_stand_fishing@idle_a', 'idle_c', 1000)
                    JC.progress('Fishing...', cfg2.minigameDurationMs or 8000)
                    local result, err2 = Sunset.AwaitCallback('sunset:jobs:fisherman:catch', spotIdx)
                    fishing = false
                    ClearPedTasks(PlayerPedId())
                    if result then
                        JC.sessionData.pendingValue = result.pendingValue
                        JC.notify(('Caught fish worth $%s (total pending $%s)'):format(
                            result.value, result.pendingValue), 'success')
                    elseif err2 then
                        JC.notify(err2, 'error')
                    end
                end
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
    end)
end

Sunset.Jobs.StartFisherman = startFisherman
