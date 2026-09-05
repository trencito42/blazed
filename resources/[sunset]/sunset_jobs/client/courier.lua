local JC = Sunset.JobClient

local packageProp = nil
local carryAnimActive = false
local courierUiKey = nil

local function hideCourierUi()
    courierUiKey = nil
    exports.sunset_ui:Send('courierHide', {})
end

local function showCourierUi(state, data, force)
    data = data or {}
    data.state = state
    data.title = data.title or 'Courier'
    local key = table.concat({ state or '', data.counter or '', data.message or '', data.detail or '',
        tostring(data.progress or 0), data.key or '' }, '|')
    if not force and courierUiKey == key then return end
    courierUiKey = key
    exports.sunset_ui:Send('courierShow', data)
end

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
    local idx = math.min(data.deliveryIndex or (delivered + 1), total)

    if data.hasPackage then
        local target = data.deliveries and data.deliveries[idx]
        showCourierUi('route', {
            counter = ('Package %d/%d'):format(idx, total),
            message = 'Follow GPS to delivery',
            detail = target and target.label or 'Delivery address',
            progress = pct,
        })
    elseif data.stage == 'pickup' or (data.stage == 'delivering' and not data.hasPackage) then
        showCourierUi('route', {
            counter = ('Package %d/%d'):format(idx, total),
            message = 'Return to the warehouse',
            detail = 'Loading dock marked on GPS',
            progress = pct,
        })
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
    JC.hideObjective()
    updateObjective(cfg, data)
    JC.notify('Go to the warehouse loading dock to pick up packages', 'info')

    CreateThread(function()
        local busy = false
        while JC.jobId == 'courier' and JC.state ~= 'IDLE' do
            local session = JC.sessionData
            local stage = session and session.stage

            if stage == 'pickup' or (stage == 'delivering' and session and not session.hasPackage) then
                JC.drawMarker(cfg.warehouse.coords, 255, 180, 0)
                local nearPickup = JC.isNear(cfg.warehouse.coords, cfg.pickupRadius)
                local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
                local total = session and session.total or 1
                local idx = math.min((session and session.deliveryIndex) or ((session and session.delivered or 0) + 1), total)
                local pct = math.floor(((session and session.delivered or 0) / math.max(total, 1)) * 100)
                if nearPickup and not busy and not inVehicle then
                    showCourierUi('prompt', {
                        counter = ('Package %d/%d'):format(idx, total),
                        message = 'Press {key} to pick up package',
                        detail = 'Courier Warehouse · Loading Dock',
                        progress = pct,
                        key = 'E',
                    })
                    if IsControlJustPressed(0, 38) then
                        busy = true
                        showCourierUi('working', {
                            counter = ('Package %d/%d'):format(idx, total),
                            message = 'Collecting package',
                            detail = 'Preparing delivery manifest',
                            progress = pct,
                        }, true)
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
                            courierUiKey = nil
                        end
                    end
                elseif nearPickup and inVehicle then
                    showCourierUi('blocked', {
                        counter = ('Package %d/%d'):format(idx, total),
                        message = 'Exit the vehicle',
                        detail = 'Pick up the package on foot',
                        progress = pct,
                    })
                else
                    updateObjective(cfg, session)
                end
            elseif stage == 'delivering' and session and session.hasPackage then
                local idx = session.deliveryIndex or 1
                local target = session.deliveries and session.deliveries[idx]
                if target then
                    local pos = vector3(target.coords.x, target.coords.y, target.coords.z)
                    JC.drawMarker(pos, 46, 204, 113)
                    local nearDelivery = JC.isNear(pos, cfg.deliveryRadius)
                    local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
                    local total = session.total or 1
                    local pct = math.floor(((session.delivered or 0) / math.max(total, 1)) * 100)
                    if nearDelivery and not busy and not inVehicle then
                        showCourierUi('prompt', {
                            counter = ('Package %d/%d'):format(idx, total),
                            message = 'Press {key} to deliver package',
                            detail = target.label or 'Delivery address',
                            progress = pct,
                            key = 'E',
                        })
                        if IsControlJustPressed(0, 38) then
                            busy = true
                            showCourierUi('working', {
                                counter = ('Package %d/%d'):format(idx, total),
                                message = 'Handing over package',
                                detail = target.label or 'Delivery address',
                                progress = pct,
                            }, true)
                            JC.playAnim('anim@heists@box_carry@', 'idle', 2000)
                            local result, err2 = Sunset.AwaitCallback('sunset:jobs:courier:deliver')
                            busy = false
                            if result then
                                detachPackage()
                                JC.notify(('Delivered +$%s'):format(result.pay or 0), 'success')
                                showCourierUi(result.completed and 'complete' or 'success', {
                                    counter = ('Package %d/%d'):format(idx, total),
                                    message = result.completed and 'Route complete' or ('Delivered · +$%s'):format(result.pay or 0),
                                    detail = result.completed and 'All packages delivered successfully' or 'Return to warehouse for the next package',
                                    progress = math.floor((idx / math.max(total, 1)) * 100),
                                }, true)
                                Wait(result.completed and 1700 or 1000)
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
                                courierUiKey = nil
                            end
                        end
                    elseif nearDelivery and inVehicle then
                        showCourierUi('blocked', {
                            counter = ('Package %d/%d'):format(idx, total),
                            message = 'Exit the vehicle',
                            detail = 'Deliver the package on foot at ' .. (target.label or 'the address'),
                            progress = pct,
                        })
                    else
                        updateObjective(cfg, session)
                    end
                end
            end
            Wait(0)
        end
        detachPackage()
        hideCourierUi()
        JC.hideObjective()
    end)
end

RegisterNetEvent('sunset:jobs:sessionEnded', function(jobId)
    if jobId ~= 'courier' then return end
    detachPackage()
    hideCourierUi()
end)

Sunset.Jobs.StartCourier = startCourier
