local JC = Sunset.JobClient

local packageProp = nil
local carryAnimActive = false

local function pointToDelivery(cfg, target, label)
    if not target then return end
    local pos = vector3(target.coords.x, target.coords.y, target.coords.z)
    JC.clearBlips()
    JC.addBlip(cfg.warehouse.coords, cfg.warehouse.blip, 'Courier Warehouse')
    JC.addBlip(pos, { sprite = 478, color = 3, scale = 0.85 }, label or 'Delivery')
    JC.setWaypoint(pos)
end

local function detachPackage()
    carryAnimActive = false
    if packageProp and DoesEntityExist(packageProp) then
        DetachEntity(packageProp, true, true)
        DeleteObject(packageProp)
    end
    packageProp = nil
    ClearPedSecondaryTask(PlayerPedId())
end

local function attachPackage(cfg)
    detachPackage()
    local ped = PlayerPedId()
    local modelName = (cfg and cfg.packageProp) or 'prop_cs_cardbox_01'
    local model = joaat(modelName)
    if not JC.loadModel(model) then return false end
    local coords = GetEntityCoords(ped)
    packageProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetEntityCollision(packageProp, false, false)
    AttachEntityToEntity(
        packageProp, ped, GetPedBoneIndex(ped, 60309),
        0.025, 0.08, 0.255, -145.0, 290.0, 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)

    carryAnimActive = true
    CreateThread(function()
        RequestAnimDict('anim@heists@box_carry@')
        while not HasAnimDictLoaded('anim@heists@box_carry@') do Wait(10) end
        while carryAnimActive and JC.jobId == 'courier' do
            local p = PlayerPedId()
            if JC.sessionData and JC.sessionData.hasPackage then
                if not IsEntityPlayingAnim(p, 'anim@heists@box_carry@', 'idle', 3) then
                    TaskPlayAnim(p, 'anim@heists@box_carry@', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end
            Wait(500)
        end
    end)
    return true
end

local function updateObjective(cfg, data)
    if not data then return end
    local total = data.total or 1
    local delivered = data.delivered or 0
    local pct = math.floor((delivered / math.max(total, 1)) * 100)

    if data.hasPackage then
        local idx = data.deliveryIndex or 1
        local target = data.deliveries and data.deliveries[idx]
        JC.showObjective('Courier', ('Deliver package %d/%d to %s'):format(
            idx, total, target and target.label or 'the address'), pct)
    elseif data.stage == 'pickup' or (data.stage == 'delivering' and not data.hasPackage) then
        JC.showObjective('Courier', 'Pick up a package at the warehouse (E)', pct)
    end
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
    updateObjective(cfg, data)
    JC.notify('Go to the warehouse loading dock to pick up packages', 'info')

    CreateThread(function()
        local busy = false
        while JC.jobId == 'courier' and JC.state ~= 'IDLE' do
            local session = JC.sessionData
            local stage = session and session.stage

            if stage == 'pickup' or (stage == 'delivering' and session and not session.hasPackage) then
                JC.drawMarker(cfg.warehouse.coords, 255, 180, 0)
                if JC.isNear(cfg.warehouse.coords, cfg.pickupRadius)
                    and not busy
                    and not IsPedInAnyVehicle(PlayerPedId(), false) then
                    JC.showHelp('Press ~INPUT_CONTEXT~ to pick up a package')
                    if IsControlJustPressed(0, 38) then
                        busy = true
                        JC.playAnim('anim@heists@box_carry@', 'idle', 2000)
                        local newData, err2 = Sunset.AwaitCallback('sunset:jobs:courier:pickup')
                        busy = false
                        if newData then
                            JC.sessionData = newData
                            attachPackage(cfg)
                            updateObjective(cfg, newData)
                            local idx = newData.deliveryIndex or 1
                            local target = newData.deliveries and newData.deliveries[idx]
                            if target then
                                pointToDelivery(cfg, target, 'Delivery: ' .. (target.label or ''))
                                JC.notify('Deliver to ' .. (target.label or 'address'), 'info')
                            end
                        else
                            JC.notify(err2 or 'Could not pick up package at the warehouse', 'error')
                        end
                    end
                end
            elseif stage == 'delivering' and session and session.hasPackage then
                local idx = session.deliveryIndex or 1
                local target = session.deliveries and session.deliveries[idx]
                if target then
                    local pos = vector3(target.coords.x, target.coords.y, target.coords.z)
                    JC.drawMarker(pos, 46, 204, 113)
                    if JC.isNear(pos, cfg.deliveryRadius)
                        and not busy
                        and not IsPedInAnyVehicle(PlayerPedId(), false) then
                        JC.showHelp('Press ~INPUT_CONTEXT~ to deliver the package')
                        if IsControlJustPressed(0, 38) then
                            busy = true
                            JC.playAnim('anim@heists@box_carry@', 'idle', 2000)
                            local result, err2 = Sunset.AwaitCallback('sunset:jobs:courier:deliver')
                            busy = false
                            if result then
                                detachPackage()
                                JC.notify(('Delivered +$%s'):format(result.pay or 0), 'success')
                                if result.completed then
                                    JC.clearBlips()
                                    JC.hideObjective()
                                    break
                                elseif result.data then
                                    JC.sessionData = result.data
                                    updateObjective(cfg, result.data)
                                    JC.clearBlips()
                                    JC.addBlip(cfg.warehouse.coords, cfg.warehouse.blip, 'Courier Warehouse')
                                    JC.setWaypoint(cfg.warehouse.coords)
                                    JC.notify('Return to warehouse for next package', 'info')
                                end
                            else
                                JC.notify(err2 or 'Could not deliver the package', 'error')
                            end
                        end
                    end
                end
            end
            Wait(0)
        end
        detachPackage()
    end)
end

Sunset.Jobs.StartCourier = startCourier
