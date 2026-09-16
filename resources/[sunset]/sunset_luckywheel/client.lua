-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — 3D Lucky Wheel (client.lua)
-- ═══════════════════════════════════════════════════════════════

local isRolling = false
local luckywheel = nil
local basewheel = nil
local wheelPos = vector3(1111.05, 229.85, -50.64)
local spinPos = vector3(1110.88, 228.87, -49.85)

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

local function spawnWheel()
    local wheelModel = GetHashKey('vw_prop_vw_luckywheel_02a')
    local baseModel = GetHashKey('vw_prop_vw_luckywheel_01a')

    RequestModel(baseModel)
    while not HasModelLoaded(baseModel) do Wait(10) end

    if not DoesEntityExist(basewheel) then
        basewheel = CreateObject(baseModel, wheelPos.x, wheelPos.y, wheelPos.z, false, false, true)
        SetEntityHeading(basewheel, 0.0)
        FreezeEntityPosition(basewheel, true)
    end
    SetModelAsNoLongerNeeded(baseModel)

    RequestModel(wheelModel)
    while not HasModelLoaded(wheelModel) do Wait(10) end

    if not DoesEntityExist(luckywheel) then
        luckywheel = CreateObject(wheelModel, wheelPos.x, wheelPos.y, wheelPos.z, false, false, true)
        SetEntityHeading(luckywheel, 0.0)
        FreezeEntityPosition(luckywheel, true)
    end
    SetModelAsNoLongerNeeded(wheelModel)
end

local function cleanupWheel()
    if DoesEntityExist(luckywheel) then DeleteObject(luckywheel) luckywheel = nil end
    if DoesEntityExist(basewheel) then DeleteObject(basewheel) basewheel = nil end
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        cleanupWheel()
    end
end)

CreateThread(function()
    while true do
        local sleep = 600
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(coords - wheelPos)

        if dist < 45.0 then
            if not DoesEntityExist(luckywheel) then spawnWheel() end
            if dist < 2.5 and not isRolling then
                sleep = 0
                DrawText3D(spinPos + vector3(0, 0, 0.3), '~p~[E]~s~ Spin The Lucky Wheel (100 Chips / Cooldown: 1h)')
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('sunset:luckywheel:requestSpin')
                end
            end
        elseif dist >= 80.0 and DoesEntityExist(luckywheel) then
            cleanupWheel()
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('sunset:luckywheel:doRoll', function(priceIndex, spinnerPedNetId)
    isRolling = true
    spawnWheel()

    local spinnerPed = spinnerPedNetId and NetToPed(spinnerPedNetId) or nil
    if spinnerPed and DoesEntityExist(spinnerPed) then
        CreateThread(function()
            local isMale = IsPedMale(spinnerPed)
            local dict = isMale and 'anim_casino_a@amb@casino@games@lucky7wheel@male' or 'anim_casino_a@amb@casino@games@lucky7wheel@female'
            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do Wait(10) end

            TaskPlayAnim(spinnerPed, dict, 'enter_right_to_baseidle', 8.0, -8.0, -1, 0, 0, false, false, false)
            Wait(1200)
            TaskPlayAnim(spinnerPed, dict, 'enter_to_armraisedidle', 8.0, -8.0, -1, 0, 0, false, false, false)
            Wait(800)
            TaskPlayAnim(spinnerPed, dict, 'armraisedidle_to_spinningidle_high', 8.0, -8.0, -1, 0, 0, false, false, false)
            Wait(2500)
            ClearPedTasks(spinnerPed)
        end)
    end

    CreateThread(function()
        SetEntityRotation(luckywheel, 0.0, 0.0, 0.0, 1, true)
        local speedIntCnt = 1
        local rollspeed = 1.0
        local winAngle = (priceIndex - 1) * 18.0
        local rollAngle = winAngle + (360.0 * 8)
        local midLength = (rollAngle / 2)
        local intCnt = 0

        PlaySoundFromCoord(-1, 'Spin_Start', wheelPos.x, wheelPos.y, wheelPos.z, 'dlc_vw_casino_lucky_wheel_sounds', 0, 0, 0)

        while speedIntCnt > 0 do
            local retval = GetEntityRotation(luckywheel, 1)
            if rollAngle > midLength then
                speedIntCnt = speedIntCnt + 1
            else
                speedIntCnt = speedIntCnt - 1
                if speedIntCnt < 0 then speedIntCnt = 0 end
            end
            intCnt = intCnt + 1
            rollspeed = speedIntCnt / 10.0
            local _y = retval.y - rollspeed
            rollAngle = rollAngle - rollspeed
            SetEntityRotation(luckywheel, 0.0, _y, 0.0, 1, true)
            Wait(0)
        end

        PlaySoundFromCoord(-1, 'Spin_Stop', wheelPos.x, wheelPos.y, wheelPos.z, 'dlc_vw_casino_lucky_wheel_sounds', 0, 0, 0)
        Wait(500)
        PlaySoundFromCoord(-1, 'Win', wheelPos.x, wheelPos.y, wheelPos.z, 'dlc_vw_casino_lucky_wheel_sounds', 0, 0, 0)
        isRolling = false
    end)
end)
