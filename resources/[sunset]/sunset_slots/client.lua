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

local function unsit()
    if isSitting then
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

    currentSitObj = id
    isSitting = true
    TriggerServerEvent('sunset_slots:takePlace', id)

    local offsetX = slotData.offsetX or 0.0
    local offsetY = slotData.offsetY or -0.55
    local offsetZ = slotData.offsetZ or -0.45
    local posX = pos.x + offsetX
    local posY = pos.y + offsetY
    local posZ = pos.z - offsetZ

    TaskStartScenarioAtPosition(ped, 'PROP_HUMAN_SEAT_BENCH', posX, posY, posZ, heading, 0, true, true)
    Wait(1000)

    -- Prompt for bet chips
    local betInput = KeyboardInput('Enter starting chips bet (e.g. 500):', '500', 6)
    local betAmount = tonumber(betInput)
    if betAmount and betAmount >= (Config.MinBet or 50) then
        TriggerServerEvent('sunset_slots:BetsAndMoney', betAmount)
    else
        unsit()
        if betInput then
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
        local nearSlot = false

        for _, slot in ipairs(Config.Slots or {}) do
            local dist = #(coords - slot.coords)
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

        Wait(sleep)
    end
end)


