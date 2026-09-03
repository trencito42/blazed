local JC = Sunset.JobClient

local function startTrucker()
    local data, err = Sunset.AwaitCallback('sunset:jobs:trucker:start')
    if not data then
        JC.notify(err or 'Could not start trucker shift', 'error')
        return
    end

    local cfg = Sunset.GetJobConfig('trucker')
    JC.clearBlips()
    JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Trucker Depot')

    local truck = JC.spawnVehicle(cfg.truckModel, cfg.depot.spawn, true)
    if not truck then
        Sunset.AwaitCallback('sunset:jobs:cancelWork')
        return
    end
    local trailer = JC.attachTrailer(truck, cfg.trailerModel, cfg.depot.trailerSpawn)
    JC.registerVehiclesWithServer()
    JC.monitorVehicles()

    JC.setWaypoint(data.pickup)
    JC.addBlip(vector3(data.pickup.x, data.pickup.y, data.pickup.z), { sprite = 478, color = 5 }, 'Cargo Pickup')
    JC.notify('Drive to pickup: ' .. (data.label or ''), 'info')

    CreateThread(function()
        while JC.jobId == 'trucker' and JC.state ~= 'IDLE' do
            local ped = PlayerPedId()
            local stage = JC.sessionData and JC.sessionData.stage

            if stage == 'to_pickup' and data.pickup then
                local p = vector3(data.pickup.x, data.pickup.y, data.pickup.z)
                JC.drawMarker(p, 255, 180, 0)
                if JC.isNear(p, cfg.deliveryRadius) and IsPedInAnyVehicle(ped, false) then
                    local ok, newData = Sunset.AwaitCallback('sunset:jobs:trucker:atPickup')
                    if ok then
                        JC.sessionData = newData
                        JC.clearBlips()
                        JC.addBlip(vector3(data.delivery.x, data.delivery.y, data.delivery.z), { sprite = 478, color = 2 }, 'Delivery')
                        JC.setWaypoint(data.delivery)
                        JC.notify('Cargo loaded — deliver to destination', 'success')
                    end
                end
            elseif stage == 'to_delivery' and data.delivery then
                local d = vector3(data.delivery.x, data.delivery.y, data.delivery.z)
                JC.drawMarker(d, 46, 204, 113)
                if JC.isNear(d, cfg.deliveryRadius) and IsPedInAnyVehicle(ped, false) then
                    local result, err2 = Sunset.AwaitCallback('sunset:jobs:trucker:deliver')
                    if result then
                        JC.sessionData.stage = 'return_depot'
                        JC.clearBlips()
                        JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Return Depot')
                        JC.setWaypoint(cfg.depot.coords)
                        JC.notify(('Delivered! +$%s — return truck to depot'):format(result.pay or 0), 'success')
                    elseif err2 then
                        JC.notify(err2, 'error')
                    end
                end
            elseif stage == 'return_depot' then
                JC.drawMarker(cfg.depot.coords, 52, 152, 219)
                if JC.isNear(cfg.depot.coords, cfg.returnRadius or 15.0) and IsPedInAnyVehicle(ped, false) then
                    local ok, err3 = Sunset.AwaitCallback('sunset:jobs:trucker:returnDepot')
                    if ok then
                        JC.deleteVehicles()
                        break
                    elseif err3 then JC.notify(err3, 'error') end
                end
            end
            Wait(0)
        end
    end)
end

Sunset.Jobs = Sunset.Jobs or {}
Sunset.Jobs.StartTrucker = startTrucker
