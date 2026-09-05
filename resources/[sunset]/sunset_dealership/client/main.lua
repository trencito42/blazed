local dealerOpen = false
local adminMode = false
local previewVehicle = 0
local previewCamera = 0
local previewBusy = false
local testVehicle = 0
local testDriveActive = false

local function notify(message, kind, duration)
    exports.sunset_ui:Notify(message, kind or 'info', duration)
end

local function loadVehicleModel(modelName)
    local hash = joaat(modelName)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return nil, ('Vehicle model "%s" is not available in this game build.'):format(tostring(modelName))
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(hash) then return nil, 'The vehicle model did not finish loading. Try again.' end
    return hash
end

local function cleanupPreviewArea()
    local p = Sunset.Dealership.preview
    local center = vector3(p.x, p.y, p.z)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= previewVehicle and DoesEntityExist(veh) then
            if #(GetEntityCoords(veh) - center) < 5.0 then
                SetEntityAsMissionEntity(veh, true, true)
                DeleteVehicle(veh)
            end
        end
    end
end

local function clearPreviewCamera()
    ClearFocus()
    ClearHdArea()
    if previewCamera ~= 0 then
        RenderScriptCams(false, true, 300, true, true)
        if DoesCamExist(previewCamera) then
            SetCamActive(previewCamera, false)
            DestroyCam(previewCamera, false)
        end
        previewCamera = 0
    end
end

local function setupPreviewCamera(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local camPos = Sunset.Dealership.camera
    local coords = GetEntityCoords(vehicle)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local lookZ = coords.z + math.max(0.45, ((maxDim.z + minDim.z) * 0.5) + 0.25)

    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    SetHdArea(coords.x, coords.y, coords.z, 50.0)

    if previewCamera == 0 or not DoesCamExist(previewCamera) then
        previewCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end
    SetCamCoord(previewCamera, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(previewCamera, coords.x, coords.y, lookZ)
    SetCamFov(previewCamera, 40.0)
    SetCamActive(previewCamera, true)
    RenderScriptCams(true, true, 400, true, true)
end

local function deletePreview()
    if previewVehicle ~= 0 and DoesEntityExist(previewVehicle) then
        SetEntityAsMissionEntity(previewVehicle, true, true)
        DeleteVehicle(previewVehicle)
    end
    previewVehicle = 0
    clearPreviewCamera()
end

local function closeDealer()
    dealerOpen = false
    adminMode = false
    deletePreview()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('dealershipHide', {})
end

local function showPreview(modelName)
    if previewBusy then return end
    previewBusy = true
    if previewVehicle ~= 0 and DoesEntityExist(previewVehicle) then
        SetEntityAsMissionEntity(previewVehicle, true, true)
        DeleteVehicle(previewVehicle)
        previewVehicle = 0
    end
    cleanupPreviewArea()

    local hash, err = loadVehicleModel(modelName)
    if not hash then
        previewBusy = false
        return notify(err, 'error')
    end

    local p = Sunset.Dealership.preview
    previewVehicle = CreateVehicle(hash, p.x, p.y, p.z, p.w, false, false)
    if previewVehicle == 0 then
        SetModelAsNoLongerNeeded(hash)
        previewBusy = false
        return notify('The preview vehicle could not be created.', 'error')
    end
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetEntityInvincible(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetVehicleDirtLevel(previewVehicle, 0.0)
    SetVehicleOnGroundProperly(previewVehicle)
    FreezeEntityPosition(previewVehicle, true)
    SetVehicleEngineHealth(previewVehicle, 1000.0)
    SetVehicleBodyHealth(previewVehicle, 1000.0)
    SetVehiclePetrolTankHealth(previewVehicle, 1000.0)
    SetModelAsNoLongerNeeded(hash)
    setupPreviewCamera(previewVehicle)
    previewBusy = false
end

local function openDealer(asAdmin)
    if dealerOpen or testDriveActive or IsNuiFocused() then return end
    local data, err = Sunset.AwaitCallback('sunset:dealership:getCatalog', asAdmin == true)
    if not data then return notify(err or 'The dealership catalog could not be loaded.', 'error') end
    dealerOpen = true
    adminMode = asAdmin == true
    exports.sunset_ui:Send('dealershipShow', data)
    exports.sunset_ui:SetFocus(true, true)
end

RegisterCommand('dealership', function()
    CreateThread(function() openDealer(false) end)
end, false)

RegisterCommand('dealershipadmin', function()
    CreateThread(function() openDealer(true) end)
end, false)

AddEventHandler('sunset:nui:dealershipClose', closeDealer)

AddEventHandler('sunset:nui:dealershipSelect', function(data)
    if not dealerOpen or not data or not data.model then return end
    showPreview(data.model)
end)

AddEventHandler('sunset:nui:dealershipRotate', function(data)
    if previewVehicle == 0 or not DoesEntityExist(previewVehicle) then return end
    local amount = data and tonumber(data.direction) or 1
    SetEntityHeading(previewVehicle, GetEntityHeading(previewVehicle) + (amount >= 0 and 15.0 or -15.0))
end)

local function refreshDealer()
    local data, err = Sunset.AwaitCallback('sunset:dealership:getCatalog', adminMode)
    if data then exports.sunset_ui:Send('dealershipUpdate', data) end
    if err then notify(err, 'error') end
end

AddEventHandler('sunset:nui:dealershipBuy', function(data)
    if not dealerOpen or adminMode or not data or not data.model then return end
    CreateThread(function()
        local result, err = Sunset.AwaitCallback('sunset:dealership:purchase', data.model)
        if not result then
            notify(err or 'The vehicle could not be purchased.', 'error', 7000)
            refreshDealer()
            return
        end
        notify(('%s purchased. Plate %s is waiting at Legion Garage.'):format(
            result.label or result.model, result.plate), 'success', 8000)
        refreshDealer()
    end)
end)

local function endTestDrive(message)
    if not testDriveActive then return end
    testDriveActive = false
    TriggerEvent('sunset:ui:jobObjective', { hide = true })
    local ped = PlayerPedId()
    if testVehicle ~= 0 and DoesEntityExist(testVehicle) then
        if IsPedInVehicle(ped, testVehicle, false) then TaskLeaveVehicle(ped, testVehicle, 16) Wait(500) end
        TriggerServerEvent('sunset:dealership:endTestDrive', NetworkGetNetworkIdFromEntity(testVehicle))
    end
    testVehicle = 0
    local ret = Sunset.Dealership.testDriveReturn
    SetEntityCoordsNoOffset(ped, ret.x, ret.y, ret.z, false, false, false)
    SetEntityHeading(ped, ret.w or 0.0)
    notify(message or 'Test drive finished. You have been returned to the dealership.', 'info', 6000)
end

AddEventHandler('sunset:nui:dealershipTestDrive', function(data)
    if not dealerOpen or adminMode or not data or not data.model then return end
    CreateThread(function()
        local drive, err = Sunset.AwaitCallback('sunset:dealership:testDrive', data.model)
        if not drive then return notify(err or 'Test drive is not available.', 'error') end
        local hash, modelErr = loadVehicleModel(drive.model)
        if not hash then return notify(modelErr, 'error') end
        closeDealer()
        local deadline = GetGameTimer() + 7000
        testVehicle = 0
        while testVehicle == 0 and GetGameTimer() < deadline do
            testVehicle = NetworkGetEntityFromNetworkId(tonumber(drive.netId) or 0)
            if testVehicle == 0 then Wait(100) end
        end
        SetModelAsNoLongerNeeded(hash)
        if testVehicle == 0 or not DoesEntityExist(testVehicle) then
            TriggerServerEvent('sunset:dealership:endTestDrive', drive.netId)
            return notify('The test-drive vehicle did not stream in. Try again.', 'error')
        end
        SetEntityAsMissionEntity(testVehicle, true, true)
        Entity(testVehicle).state:set('sunsetProtectedVehicle', true, false)
        SetVehicleNumberPlateText(testVehicle, 'TESTDRIV')
        SetVehicleDirtLevel(testVehicle, 0.0)
        SetVehicleFuelLevel(testVehicle, GetVehicleHandlingFloat(testVehicle, 'CHandlingData', 'fPetrolTankVolume'))
        TaskWarpPedIntoVehicle(PlayerPedId(), testVehicle, -1)
        TriggerEvent('sunset:vehicles:setEngineState', testVehicle, true)
        testDriveActive = true

        local seconds = math.max(15, tonumber(drive.seconds) or 60)
        for remaining = seconds, 1, -1 do
            if not testDriveActive or testVehicle == 0 or not DoesEntityExist(testVehicle) then break end
            TriggerEvent('sunset:ui:jobObjective', {
                title = 'Test drive — ' .. (drive.label or drive.model),
                subtitle = ('%d seconds remaining · the vehicle cannot be stored'):format(remaining),
                progress = math.floor(((seconds - remaining) / seconds) * 100),
            })
            Wait(1000)
        end
        if testDriveActive then endTestDrive() end
    end)
end)

AddEventHandler('sunset:nui:dealershipAdminSave', function(data)
    if not dealerOpen or not adminMode then return end
    if not data or not data.model or not IsModelInCdimage(joaat(data.model)) or not IsModelAVehicle(joaat(data.model)) then
        return notify(('"%s" is not a valid vehicle spawn model in this game build.'):format(
            data and tostring(data.model) or ''), 'error', 7000)
    end
    CreateThread(function()
        local result, err = Sunset.AwaitCallback('sunset:dealership:adminSave', data)
        if not result then return notify(err or 'The dealership entry could not be saved.', 'error', 7000) end
        notify(('Dealership entry %s saved.'):format(data.model or ''), 'success')
        exports.sunset_ui:Send('dealershipUpdate', {
            dealership = Sunset.Dealership.label, admin = true, vehicles = result.vehicles,
        })
    end)
end)

AddEventHandler('sunset:nui:dealershipAdminDelete', function(data)
    if not dealerOpen or not adminMode or not data or not data.model then return end
    CreateThread(function()
        local result, err = Sunset.AwaitCallback('sunset:dealership:adminDelete', data.model)
        if not result then return notify(err or 'The dealership entry could not be deleted.', 'error') end
        deletePreview()
        notify(('Removed %s from the dealership catalog.'):format(data.model), 'success')
        exports.sunset_ui:Send('dealershipUpdate', {
            dealership = Sunset.Dealership.label, admin = true, vehicles = result.vehicles,
        })
    end)
end)

CreateThread(function()
    local cfg = Sunset.Dealership
    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, cfg.blip.sprite)
    SetBlipColour(blip, cfg.blip.color)
    SetBlipScale(blip, cfg.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label)
    EndTextCommandSetBlipName(blip)

    while true do
        local ped = PlayerPedId()
        local distance = #(GetEntityCoords(ped) - cfg.coords)
        if distance < 40.0 then
            DrawMarker(1, cfg.coords.x, cfg.coords.y, cfg.coords.z - 0.98, 0, 0, 0, 0, 0, 0,
                2.4, 2.4, 0.8, 255, 140, 0, 180, false, false, 2, false, nil, nil, false)
            if distance <= cfg.interactionRadius and not dealerOpen and not testDriveActive then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to browse vehicles')
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustPressed(0, 38) then CreateThread(function() openDealer(false) end) end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    Wait(3500)
    TriggerEvent('chat:addSuggestion', '/dealership', 'Open the vehicle dealership while standing at Premium Deluxe Motorsport')
    TriggerEvent('chat:addSuggestion', '/dealershipadmin', 'Manage dealership stock, prices and availability (Admin 3+)')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deletePreview()
    if testVehicle ~= 0 and DoesEntityExist(testVehicle) then
        TriggerServerEvent('sunset:dealership:endTestDrive', NetworkGetNetworkIdFromEntity(testVehicle))
    end
end)
