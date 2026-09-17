-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Slot Machines (client.lua)
-- ═══════════════════════════════════════════════════════════════

local open = false
local closestSlotMachine = nil
local currentSitObj = nil
local isSitting = false

local function DrawText3D(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentSubstringPlayerName(text)
        DrawText(_x, _y)
        local factor = string.len(text) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 140)
    end
end

local function KeyboardInput(textEntry, inputText, maxLength)
    AddTextEntry('FMMC_KEY_TIP1', textEntry)
    DisplayOnscreenKeyboard(1, 'FMMC_KEY_TIP1', '', inputText, '', '', '', maxLength)

    while UpdateOnscreenKeyboard() == 0 do
        Wait(0)
    end

    if UpdateOnscreenKeyboard() == 1 then
        local result = GetOnscreenKeyboardResult()
        Wait(300)
        return result
    else
        Wait(300)
        return nil
    end
end

local slotCam = nil

local function createSlotCam(prop, pos, heading)
    if slotCam then DestroyCam(slotCam, false) slotCam = nil end
    local camPos = nil
    local lookPos = nil
    if DoesEntityExist(prop) then
        camPos = GetOffsetFromEntityInWorldCoords(prop, 0.0, -0.85, 0.55)
        lookPos = GetOffsetFromEntityInWorldCoords(prop, 0.0, 0.0, 0.35)
    else
        local rad = math.rad(heading)
        camPos = vector3(pos.x + math.sin(rad) * 0.85, pos.y - math.cos(rad) * 0.85, pos.z + 0.55)
        lookPos = vector3(pos.x, pos.y, pos.z + 0.35)
    end
    slotCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, 50.0, true, 2)
    PointCamAtCoord(slotCam, lookPos.x, lookPos.y, lookPos.z)
    SetCamActive(slotCam, true)
    RenderScriptCams(true, true, 800, true, true)
end

local function destroySlotCam()
    if slotCam then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(slotCam, false)
        slotCam = nil
    end
end

local currentScene = nil
local spawnedChairs = {}

local function spawnSlotChairs()
    local chairModel = GetHashKey('vw_prop_casino_chair_02a')
    RequestModel(chairModel)
    while not HasModelLoaded(chairModel) do Wait(10) end

    for _, slot in ipairs(Config.Slots or {}) do
        local id = slot.id
        if not spawnedChairs[id] or not DoesEntityExist(spawnedChairs[id]) then
            local existing = GetClosestObjectOfType(slot.coords.x, slot.coords.y, slot.coords.z, 1.4, chairModel, false, false, false)
            if DoesEntityExist(existing) and existing ~= 0 then
                spawnedChairs[id] = existing
            else
                local rad = math.rad(slot.heading)
                local chairX = slot.coords.x + math.sin(rad) * 0.75
                local chairY = slot.coords.y - math.cos(rad) * 0.75
                local chairHeading = (slot.heading + 180.0) % 360.0
                local chairObj = CreateObject(chairModel, chairX, chairY, slot.coords.z, false, false, false)
                SetEntityHeading(chairObj, chairHeading)
                FreezeEntityPosition(chairObj, true)
                SetEntityInvincible(chairObj, true)
                spawnedChairs[id] = chairObj
            end
        end
    end
    SetModelAsNoLongerNeeded(chairModel)
end

local function cleanupSlotChairs()
    for id, chair in pairs(spawnedChairs) do
        if DoesEntityExist(chair) then
            DeleteObject(chair)
        end
    end
    spawnedChairs = {}
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        cleanupSlotChairs()
        destroySlotCam()
        if currentScene then
            NetworkStopSynchronisedScene(currentScene)
            currentScene = nil
        end
    end
end)

local function unsit()
    destroySlotCam()
    if isSitting then
        if currentScene then
            NetworkStopSynchronisedScene(currentScene)
            currentScene = nil
        end
        local playerPed = PlayerPedId()
        ClearPedTasks(playerPed)
        if currentSitObj then
            TriggerServerEvent('sunset_slots:leavePlace', currentSitObj)
            currentSitObj = nil
        end
        isSitting = false
    end
end

local function sit(slotData)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local prop = nil
    
    if slotData.prop then
        prop = GetClosestObjectOfType(pedCoords.x, pedCoords.y, pedCoords.z, 2.0, GetHashKey(slotData.prop), false, false, false)
    end
    if not DoesEntityExist(prop) and Config.SlotProps then
        for _, propHash in ipairs(Config.SlotProps) do
            prop = GetClosestObjectOfType(pedCoords.x, pedCoords.y, pedCoords.z, 2.0, propHash, false, false, false)
            if DoesEntityExist(prop) then break end
        end
    end

    local pos = DoesEntityExist(prop) and GetEntityCoords(prop) or slotData.coords
    local heading = DoesEntityExist(prop) and GetEntityHeading(prop) or (slotData.heading or 0.0)
    local id = ('%.2f_%.2f_%.2f'):format(pos.x, pos.y, pos.z)

    local occupied = Sunset.AwaitCallback('sunset:slots:getPlace', id)
    if occupied then
        exports.sunset_ui:Notify('This slot machine is currently in use.', 'error')
        return
    end

    -- Find casino chair for this slot machine
    local chair = spawnedChairs[slotData.id]
    if not DoesEntityExist(chair) then
        chair = GetClosestObjectOfType(pos.x, pos.y, pos.z, 1.4, GetHashKey('vw_prop_casino_chair_02a'), false, false, false)
        if not DoesEntityExist(chair) then
            chair = GetClosestObjectOfType(pos.x, pos.y, pos.z, 1.4, GetHashKey('vw_prop_casino_chair_01a'), false, false, false)
        end
    end

    local chairPos = nil
    local chairHeading = nil

    if DoesEntityExist(chair) then
        chairPos = GetEntityCoords(chair)
        chairHeading = GetEntityHeading(chair)
    else
        chairPos = DoesEntityExist(prop) and GetOffsetFromEntityInWorldCoords(prop, 0.0, -0.75, 0.0) or vector3(pos.x, pos.y, pos.z)
        chairHeading = (heading + 180.0) % 360.0
    end

    currentSitObj = id
    isSitting = true
    TriggerServerEvent('sunset_slots:takePlace', id)

    -- Play casino synchronized sitting scene (1:1 identical posture to blackjack)
    local animDict = 'anim_casino_b@amb@casino@games@shared@player@'
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end

    local scene = NetworkCreateSynchronisedScene(chairPos.x, chairPos.y, chairPos.z, 0.0, 0.0, chairHeading, 2, true, true, 1065353216, 0, 1065353216)
    NetworkAddPedToSynchronisedScene(ped, scene, animDict, 'idle_cardgames', 2.0, -2.0, 13, 16, 1148846080, 0)
    NetworkStartSynchronisedScene(scene)
    currentScene = scene
    
    -- Smoothly transition camera to slot machine screen
    createSlotCam(prop, pos, heading)
    Wait(600)

    -- Prompt for bet chips using ox_lib modal
    local input = lib.inputDialog('Diamond Slot Machine', {
        { type = 'number', label = 'Starting Chips Bet', default = 500, min = Config.MinBet or 50, max = 50000, required = true }
    })

    local betAmount = input and tonumber(input[1])
    if betAmount and betAmount >= (Config.MinBet or 50) then
        TriggerServerEvent('sunset_slots:BetsAndMoney', betAmount)
    else
        unsit()
        if input then
            exports.sunset_ui:Notify(('Invalid bet amount. Minimum bet is %d chips.'):format(Config.MinBet or 50), 'error')
        end
    end
end

RegisterNetEvent('sunset_slots:UpdateSlots', function(chips)
    SetNuiFocus(true, true)
    open = true
    SendNUIMessage({
        showPacanele = 'open',
        coinAmount = tonumber(chips)
    })
end)

RegisterNetEvent('sunset_slots:unsit', function()
    unsit()
end)

RegisterNUICallback('exitWith', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    open = false
    local coins = tonumber(data and data.coinAmount) or 0
    TriggerServerEvent('sunset_slots:PayOutRewards', coins)
    if Config.SittingEnabled then
        unsit()
    end
end)

RegisterNUICallback('sendHook', function(data, cb)
    cb('ok')
end)

-- ── Proximity loop ──
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local inRange = false

        for _, slot in ipairs(Config.Slots or {}) do
            local dist = #(coords - slot.coords)
            if dist < 45.0 then
                inRange = true
            end
            if dist < 6.0 then
                sleep = 0
                DrawMarker(1, slot.coords.x, slot.coords.y, slot.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.8, 0.8, 0.6,
                    255, 200, 0, 80,
                    false, false, 2, false, nil, nil, false)
                DrawMarker(2, slot.coords.x, slot.coords.y, slot.coords.z + 0.2,
                    0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                    0.2, 0.2, 0.2,
                    255, 200, 0, 180,
                    true, true, 2, false, nil, nil, false)
                if dist < 1.8 and not open and not isSitting then
                    DrawText3D(vector3(slot.coords.x, slot.coords.y, slot.coords.z + 0.3), '~y~[E]~s~ Play Slot Machine')
                    if IsControlJustReleased(0, 38) then -- E
                        sit(slot)
                    end
                end
            end
        end

        if inRange and not next(spawnedChairs) then
            spawnSlotChairs()
        elseif not inRange and next(spawnedChairs) then
            cleanupSlotChairs()
        end

        Wait(sleep)
    end
end)


