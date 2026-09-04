local JC = Sunset.JobClient

local function pointToDelivery(cfg, target, label)
    if not target then return end
    local pos = vector3(target.coords.x, target.coords.y, target.coords.z)
    JC.clearBlips()
    JC.addBlip(cfg.warehouse.coords, cfg.warehouse.blip, 'Courier Warehouse')
    JC.addBlip(pos, { sprite = 478, color = 3, scale = 0.85 }, label or 'Delivery')
    JC.setWaypoint(pos)
end

local function startCourier()
    local data, err = Sunset.AwaitCallback('sunset:jobs:courier:start')
    if not data then
        JC.notify(err or 'Could not start courier shift', 'error')
        return
    end

    local cfg = Sunset.GetJobConfig('courier')
    JC.clearBlips()
    JC.addBlip(cfg.warehouse.coords, cfg.warehouse.blip, 'Courier Warehouse')
    JC.sessionData = data
    JC.setWaypoint(cfg.warehouse.coords)
    JC.showObjective('Courier', 'Pick up a package at the warehouse', 0)
    JC.notify('Go to the warehouse loading dock to pick up packages', 'info')

    CreateThread(function()
        local busy = false
        while JC.jobId == 'courier' and JC.state ~= 'IDLE' do
            local stage = JC.sessionData and JC.sessionData.stage

            if stage == 'pickup' or (stage == 'delivering' and not JC.sessionData.hasPackage) then
                JC.drawMarker(cfg.warehouse.coords, 255, 180, 0)
                if JC.isNear(cfg.warehouse.coords, cfg.pickupRadius) and not busy and not IsPedInAnyVehicle(PlayerPedId(), false) then
                    busy = true
                    JC.playAnim('anim@heists@box_carry@', 'idle', 2000)
                    local ok, newData = Sunset.AwaitCallback('sunset:jobs:courier:pickup')
                    busy = false
                    if ok then
                        JC.sessionData = newData
                        local idx = newData.deliveryIndex or 1
                        local target = newData.deliveries[idx]
                        if target then
                            pointToDelivery(cfg, target, 'Delivery: ' .. (target.label or ''))
                            JC.showObjective('Courier', ('Deliver package %d/%d to %s'):format(
                                idx, newData.total or 1, target.label or 'the address'),
                                math.floor(((idx - 1) / math.max(newData.total or 1, 1)) * 100))
                            JC.notify('Deliver to ' .. (target.label or 'address'), 'info')
                        end
                    end
                end
            elseif stage == 'delivering' and JC.sessionData.hasPackage then
                local idx = JC.sessionData.deliveryIndex or 1
                local target = JC.sessionData.deliveries and JC.sessionData.deliveries[idx]
                if target then
                    local pos = vector3(target.coords.x, target.coords.y, target.coords.z)
                    JC.drawMarker(pos, 46, 204, 113)
                    if JC.isNear(pos, cfg.deliveryRadius) and not busy and not IsPedInAnyVehicle(PlayerPedId(), false) then
                        busy = true
                        JC.playAnim('anim@heists@box_carry@', 'idle', 2000)
                        local result, err2 = Sunset.AwaitCallback('sunset:jobs:courier:deliver')
                        busy = false
                        if result then
                            JC.notify(('Delivered +$%s'):format(result.pay or 0), 'success')
                            if result.completed then
                                JC.clearBlips()
                                break
                            elseif result.data then
                                JC.sessionData = result.data
                                JC.clearBlips()
                                JC.addBlip(cfg.warehouse.coords, cfg.warehouse.blip, 'Courier Warehouse')
                                JC.setWaypoint(cfg.warehouse.coords)
                                JC.showObjective('Courier', 'Return to the warehouse for the next package',
                                    math.floor(((JC.sessionData.delivered or 0) / math.max(JC.sessionData.total or 1, 1)) * 100))
                                JC.notify('Return to warehouse for next package', 'info')
                            end
                        elseif err2 then
                            JC.notify(err2, 'error')
                        end
                    end
                end
            end
            Wait(0)
        end
    end)
end

Sunset.Jobs.StartCourier = startCourier
