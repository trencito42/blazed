local JC = Sunset.JobClient

local function pointToBin(cfg, bin, label)
    if not bin then return end
    local pos = vector3(bin.x, bin.y, bin.z)
    JC.clearBlips()
    JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Garbage Depot')
    JC.addBlip(pos, { sprite = 318, color = 2, scale = 0.8 }, label or 'Trash Bin')
    JC.setWaypoint(pos)
end

local function startGarbage()
    local data, err = Sunset.AwaitCallback('sunset:jobs:garbage:start')
    if not data then
        JC.notify(err or 'Could not start garbage route', 'error')
        return
    end

    local cfg = Sunset.GetJobConfig('garbage')
    JC.clearBlips()
    JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Garbage Depot')

    local truck = JC.spawnVehicle(cfg.truckModel, cfg.depot.spawn, true)
    if not truck then
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
        return
    end
    JC.registerVehiclesWithServer()
    JC.monitorVehicles()
    JC.sessionData = data

    local firstBin = data.bins and data.bins[data.binIndex or 1]
    if firstBin then
        pointToBin(cfg, firstBin, 'Trash Bin 1')
    else
        JC.setWaypoint(cfg.depot.coords)
    end
    JC.notify('Collect bins on your route — truck capacity: ' .. (data.capacity or 8), 'info')

    CreateThread(function()
        local collecting = false
        while JC.jobId == 'garbage' and JC.state ~= 'IDLE' do
            local stage = JC.sessionData and JC.sessionData.stage

            if stage == 'collecting' then
                local idx = JC.sessionData.binIndex or 1
                local bin = JC.sessionData.bins and JC.sessionData.bins[idx]
                if bin then
                    local pos = vector3(bin.x, bin.y, bin.z)
                    JC.drawMarker(pos, 46, 204, 113)
                    if JC.isNear(pos, cfg.collectRadius) and not IsPedInAnyVehicle(PlayerPedId(), false) and not collecting then
                        collecting = true
                        JC.playAnim('anim@heists@narcotics@trash', 'pickup', 2500)
                        local ok, newData = Sunset.AwaitCallback('sunset:jobs:garbage:collectBin')
                        collecting = false
                        if ok then
                            JC.sessionData = newData
                            JC.notify(('Collected (%d/%d)'):format(newData.collected, newData.capacity), 'success')
                            if newData.stage == 'return_unload' then
                                JC.clearBlips()
                                JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Garbage Depot')
                                JC.setWaypoint(cfg.depot.unload or cfg.depot.coords)
                                JC.notify('Truck full — return to depot to unload', 'info')
                            else
                                local nextBin = newData.bins and newData.bins[newData.binIndex or 1]
                                pointToBin(cfg, nextBin, 'Trash Bin ' .. tostring(newData.binIndex or 1))
                            end
                        end
                    end
                end
            elseif stage == 'return_unload' then
                local unload = cfg.depot.unload or cfg.depot.coords
                JC.drawMarker(unload, 52, 152, 219)
                if JC.isNear(unload, 8.0) and IsPedInAnyVehicle(PlayerPedId(), false) then
                    local ok = Sunset.AwaitCallback('sunset:jobs:garbage:unload')
                    if ok then
                        JC.deleteVehicles()
                        break
                    end
                end
            end
            Wait(0)
        end
    end)
end

Sunset.Jobs.StartGarbage = startGarbage
