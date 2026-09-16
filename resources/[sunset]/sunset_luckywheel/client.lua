-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — 3D Lucky Wheel (client.lua)
-- ═══════════════════════════════════════════════════════════════

local isRolling = false
local luckywheel = nil
local inCasino = false

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

local function ensureWheel()
    if not DoesEntityExist(luckywheel) then
        luckywheel = GetClosestObjectOfType(Config.WheelPos.x, Config.WheelPos.y, Config.WheelPos.z, 5.0, Config.WheelModel, false, false, false)
        if not DoesEntityExist(luckywheel) or luckywheel == 0 then
            RequestModel(Config.WheelModel)
            while not HasModelLoaded(Config.WheelModel) do Wait(10) end
            luckywheel = CreateObject(Config.WheelModel, Config.WheelPos.x, Config.WheelPos.y, Config.WheelPos.z, false, false, true)
            SetEntityHeading(luckywheel, 0.0)
            SetModelAsNoLongerNeeded(Config.WheelModel)
        end
    end
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(coords - Config.WheelPos)

        if dist < 40.0 then
            ensureWheel()
            if dist < 2.5 and not isRolling then
                sleep = 0
                DrawText3D(Config.SpinPos + vector3(0, 0, 0.3), '~p~[E]~s~ Spin The Lucky Wheel (100 Chips / Cooldown: 1h)')
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('sunset:luckywheel:requestSpin')
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('sunset:luckywheel:doRoll', function(priceIndex, spinnerPedNetId)
    isRolling = true
    ensureWheel()

    -- If spinner ped is valid, play spin animation
    local spinnerPed = spinnerPedNetId and NetToPed(spinnerPedNetId) or nil
    if spinnerPed and DoesEntityExist(spinnerPed) then
        local isMale = IsPedMale(spinnerPed)
        local animDict = isMale and 'anim_casino_a@amb@casino@games@lucky7wheel@male' or 'anim_casino_a@amb@casino@games@lucky7wheel@female'
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(10) end
        TaskPlayAnim(spinnerPed, animDict, 'armraisedidle_to_spinningidle_high', 8.0, -8.0, 4000, 0, 0, false, false, false)
    end

    CreateThread(function()
        local speedIntCnt = 1
        local rollspeed = 1.0
        local winAngle = (priceIndex - 1) * 18.0
        local rollAngle = winAngle + (360.0 * 8)
        local midLength = (rollAngle / 2)

        while speedIntCnt > 0 do
            local retval = GetEntityRotation(luckywheel, 1)
            if rollAngle > midLength then
                speedIntCnt = speedIntCnt + 1
            else
                speedIntCnt = speedIntCnt - 1
                if speedIntCnt < 0 then speedIntCnt = 0 end
            end
            rollspeed = speedIntCnt / 10.0
            local _y = retval.y - rollspeed
            rollAngle = rollAngle - rollspeed
            SetEntityRotation(luckywheel, 0.0, _y, 0.0, 2, true)
            Wait(0)
        end
        isRolling = false
    end)
end)
