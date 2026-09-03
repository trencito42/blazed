local JC = Sunset.JobClient

local bagProp = nil
local carryAnimActive = false

local function pointToBin(cfg, bin, label)
    if not bin then return end
    local pos = vector3(bin.x, bin.y, bin.z)
    JC.clearBlips()
    JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Garbage Depot')
    JC.addBlip(pos, { sprite = 318, color = 2, scale = 0.8 }, label or 'Trash Bin')
    JC.setWaypoint(pos)
end

local function getWorkTruck()
    local truck = JC.vehicles[1]
    if truck and DoesEntityExist(truck) then return truck end
    return nil
end

local function getTruckDumpPos(truck, cfg)
    local offset = (cfg and cfg.truckRearOffset) or -4.5
    return GetOffsetFromEntityInWorldCoords(truck, 0.0, offset, 0.0)
end

local function detachBag()
    carryAnimActive = false
    if bagProp and DoesEntityExist(bagProp) then
        DetachEntity(bagProp, true, true)
        DeleteObject(bagProp)
    end
    bagProp = nil
    ClearPedSecondaryTask(PlayerPedId())
end

local function attachBag()
    detachBag()
    local ped = PlayerPedId()
    local model = joaat('prop_cs_rub_binbag_01')
    if not JC.loadModel(model) then return end
    local coords = GetEntityCoords(ped)
    bagProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetEntityCollision(bagProp, false, false)
    AttachEntityToEntity(
        bagProp, ped, GetPedBoneIndex(ped, 57005),
        0.12, 0.0, -0.05, 220.0, 120.0, 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)

    carryAnimActive = true
    CreateThread(function()
        RequestAnimDict('anim@move_m@trash')
        while not HasAnimDictLoaded('anim@move_m@trash') do Wait(10) end
        while carryAnimActive and JC.jobId == 'garbage' do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, 'anim@move_m@trash', 'walk', 3) then
                TaskPlayAnim(p, 'anim@move_m@trash', 'walk', 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(500)
        end
    end)
end

local function registerTruckWithRetry(truck)
    for _ = 1, 6 do
        if not truck or not DoesEntityExist(truck) then return false end
        local netId = NetworkGetNetworkIdFromEntity(truck)
        if netId and netId ~= 0 then
            local ok, err = Sunset.AwaitCallback('sunset:jobs:registerVehicle', netId, nil)
            if ok then return true end
            if err and err ~= 'Work vehicle not networked' then
                JC.notify(err, 'error')
                return false
            end
        end
        Wait(400)
    end
    JC.notify('Could not register work truck — try /work again', 'error')
    return false
end

local function updateObjective(cfg, data)
    if not data then return end
    if data.stage == 'return_unload' then
        JC.showObjective('Garbage Collector', 'Truck full — drive to depot unload', 100)
        return
    end
    local collected = data.collected or 0
    local capacity = data.capacity or cfg.capacity or 8
    local pct = math.floor((collected / math.max(capacity, 1)) * 100)
    if data.carrying then
        JC.showObjective('Garbage Collector', 'Dump the bag at the back of your truck', pct)
    else
        local idx = data.binIndex or 1
        JC.showObjective('Garbage Collector', ('Bin %d — pick up trash (E)'):format(idx), pct)
    end
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
    if not registerTruckWithRetry(truck) then
        JC.deleteVehicles()
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
        return
    end
    JC.monitorVehicles()
    JC.sessionData = data
    updateObjective(cfg, data)

    local firstBin = data.bins and data.bins[data.binIndex or 1]
    if firstBin then
        pointToBin(cfg, firstBin, 'Trash Bin 1')
    else
        JC.setWaypoint(cfg.depot.coords)
    end
    JC.notify('Collect bins on your route — truck capacity: ' .. (data.capacity or 8), 'info')

    CreateThread(function()
        local busy = false
        while JC.jobId == 'garbage' and JC.state ~= 'IDLE' do
            local stage = JC.sessionData and JC.sessionData.stage
            local carrying = JC.sessionData and JC.sessionData.carrying

            if stage == 'collecting' and not carrying then
                local idx = JC.sessionData.binIndex or 1
                local bin = JC.sessionData.bins and JC.sessionData.bins[idx]
                if bin then
                    local pos = vector3(bin.x, bin.y, bin.z)
                    JC.drawMarker(pos, 46, 204, 113)
                    if JC.isNear(pos, cfg.collectRadius or 3.0)
                        and not IsPedInAnyVehicle(PlayerPedId(), false)
                        and not busy
                        and IsControlJustPressed(0, 38) then
                        busy = true
                        JC.playAnim('anim@heists@narcotics@trash', 'pickup', 2500)
                        local newData, err2 = Sunset.AwaitCallback('sunset:jobs:garbage:pickupBin')
                        busy = false
                        if newData then
                            JC.sessionData = newData
                            attachBag()
                            updateObjective(cfg, newData)
                            JC.notify('Take the bag to the back of your truck', 'info')
                        else
                            JC.notify(err2 or 'Could not pick up trash from the bin', 'error')
                        end
                    end
                end
            elseif stage == 'collecting' and carrying then
                local truck = getWorkTruck()
                if truck then
                    local dumpPos = getTruckDumpPos(truck, cfg)
                    JC.drawMarker(dumpPos, 255, 180, 0)
                    if JC.isNear(dumpPos, cfg.dumpRadius or 3.5)
                        and not IsPedInAnyVehicle(PlayerPedId(), false)
                        and not busy
                        and IsControlJustPressed(0, 38) then
                        busy = true
                        JC.playAnim('anim@heists@narcotics@trash', 'drop_front', 2000)
                        local truckNetId = NetworkGetNetworkIdFromEntity(truck)
                        local newData, err2 = Sunset.AwaitCallback('sunset:jobs:garbage:dumpBin', truckNetId)
                        busy = false
                        if newData then
                            detachBag()
                            JC.sessionData = newData
                            JC.notify(('Collected (%d/%d) +$%s'):format(
                                newData.collected, newData.capacity, cfg.payPerBin or 65), 'success')
                            updateObjective(cfg, newData)
                            if newData.stage == 'return_unload' then
                                JC.clearBlips()
                                JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Garbage Depot')
                                JC.setWaypoint(cfg.depot.unload or cfg.depot.coords)
                                JC.notify('Truck full — return to depot to unload', 'info')
                            else
                                local nextBin = newData.bins and newData.bins[newData.binIndex or 1]
                                pointToBin(cfg, nextBin, 'Trash Bin ' .. tostring(newData.binIndex or 1))
                            end
                        else
                            JC.notify(err2 or 'Could not dump the bag at your truck', 'error')
                        end
                    end
                else
                    JC.notify('Your trash truck is missing', 'error')
                end
            elseif stage == 'return_unload' then
                local unload = cfg.depot.unload or cfg.depot.coords
                JC.drawMarker(unload, 52, 152, 219)
                if JC.isNear(unload, 8.0) and IsPedInAnyVehicle(PlayerPedId(), false) and not busy then
                    busy = true
                    local result, err2 = Sunset.AwaitCallback('sunset:jobs:garbage:unload')
                    busy = false
                    if result then
                        detachBag()
                        JC.deleteVehicles()
                        JC.notify(('Shift complete! Unload bonus +$%s'):format(result.bonus or 0), 'success')
                        break
                    elseif err2 then
                        JC.notify(err2, 'error')
                    end
                end
            end
            Wait(0)
        end
        detachBag()
    end)
end

Sunset.Jobs.StartGarbage = startGarbage
