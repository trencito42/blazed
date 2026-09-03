local JC = Sunset.JobClient
local activeCall = nil
local repairing = false

RegisterNetEvent('sunset:jobs:mechanic:newCall', function(callData)
    activeCall = callData
    JC.notify(('Mechanic call: %s — /work accept or go to customer'):format(
        callData and callData.label or 'Service request'), 'info')
    if callData and callData.coords then
        JC.setWaypoint(callData.coords)
    end
end)

RegisterNetEvent('sunset:jobs:mechanic:applyRepair', function(restoreAmount)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return end

    local engine = GetVehicleEngineHealth(veh)
    local body = GetVehicleBodyHealth(veh)
    local newEngine = math.min(1000.0, engine + (restoreAmount or 500))
    local newBody = math.min(1000.0, body + (restoreAmount or 500) * 0.8)

    SetVehicleEngineHealth(veh, newEngine)
    SetVehicleBodyHealth(veh, newBody)
    if newEngine > 900 and newBody > 900 then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
    end
    JC.notify('Your vehicle was repaired', 'success')
end)

local function getNearbyPlayerInVehicle()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local best, bestDist = nil, 6.0
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            if ped and DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
                local dist = #(myCoords - GetEntityCoords(ped))
                if dist < bestDist then
                    bestDist = dist
                    best = GetPlayerServerId(player)
                end
            end
        end
    end
    return best
end

local function startMechanic()
    local data, err = Sunset.AwaitCallback('sunset:jobs:mechanic:start')
    if not data then
        JC.notify(err or 'Could not go on duty', 'error')
        return
    end

    local cfg = Sunset.GetJobConfig('mechanic')
    JC.clearBlips()
    JC.addBlip(cfg.depot.coords, cfg.depot.blip, 'Mechanic Depot')
    JC.sessionData = data
    JC.notify('On duty — accept /service mechanic calls. Stand near a vehicle and press E to repair.', 'success')

    CreateThread(function()
        while JC.jobId == 'mechanic' and JC.state ~= 'IDLE' do
            if activeCall and activeCall.id and JC.sessionData.stage == 'on_duty' then
                if IsControlJustPressed(0, 38) then
                    Sunset.AwaitCallback('sunset:jobs:mechanic:acceptCall', activeCall.id)
                    JC.sessionData.stage = 'en_route'
                    JC.notify('Call accepted — go to customer', 'success')
                end
            end

            local target = getNearbyPlayerInVehicle()
            if target and not repairing then
                JC.drawMarker(GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(target))), 255, 140, 0)
                if IsControlJustPressed(0, 38) then
                    repairing = true
                    JC.playAnim('mini@repair', 'fixing_a_player', cfg.repairDurationMs or 12000)
                    JC.progress('Repairing vehicle...', cfg.repairDurationMs or 12000)
                    local result, err2 = Sunset.AwaitCallback('sunset:jobs:mechanic:repair', target)
                    repairing = false
                    ClearPedTasks(PlayerPedId())
                    if result then
                        activeCall = nil
                        JC.sessionData.stage = 'on_duty'
                        JC.notify(('Repair complete +$%s'):format(result.pay or 0), 'success')
                    elseif err2 then
                        JC.notify(err2, 'error')
                    end
                end
            end
            Wait(0)
        end
        activeCall = nil
    end)
end

Sunset.Jobs.StartMechanic = startMechanic
Sunset.Jobs.EndMechanic = function()
    return Sunset.AwaitCallback('sunset:jobs:mechanic:endShift')
end
