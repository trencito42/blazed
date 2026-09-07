local STC = SunsetTuningClient
local dynoActive = false
local dynoResult = nil

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function getDriverVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return 0 end
    return veh
end

local function estimatePower(veh, tune)
    local model = GetEntityModel(veh)
    local driveForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce')
    local maxVel = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    local mass = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass')
    local mult = STC.getStageMultipliers(tune)
    local baseHp = math.floor((driveForce * maxVel * 42.0) + (mass * 0.08))
    local hp = math.floor(baseHp * mult.power)
    local torque = math.floor(hp * (0.72 + mult.torque * 0.18))
    return math.max(80, math.min(980, hp)), math.max(90, math.min(1100, torque))
end

function RunDynoTest(shop, onComplete)
    if dynoActive then return end
    local veh = getDriverVehicle()
    if veh == 0 then
        notify('Trebuie sa fii la volan pentru dyno', 'error')
        return
    end

    dynoActive = true
    dynoResult = nil
    notify('Dyno pornit — accelereaza la maxim!', 'info')

    local start = GetGameTimer()
    local peakSpeed = 0.0
    local peakRpm = 0.0
    FreezeEntityPosition(veh, false)

    if shop and shop.dyno then
        SetEntityCoords(veh, shop.dyno.x, shop.dyno.y, shop.dyno.z, false, false, false, false)
        SetEntityHeading(veh, shop.dyno.w)
        SetVehicleOnGroundProperly(veh)
    end

    CreateThread(function()
        while dynoActive and GetGameTimer() - start < 12000 do
            Wait(50)
            if not DoesEntityExist(veh) then break end
            local speed = GetEntitySpeed(veh) * 3.6
            local rpm = GetVehicleCurrentRpm(veh)
            if speed > peakSpeed then peakSpeed = speed end
            if rpm > peakRpm then peakRpm = rpm end
        end

        dynoActive = false
        local state = STC.appliedVehicles[veh]
        local tune = state and state.tune or SunsetTuning.DefaultTune()
        local hp, torque = estimatePower(veh, tune)
        local bonus = math.floor(peakSpeed * 1.4 + peakRpm * 120)
        hp = math.min(980, hp + math.floor(bonus * 0.35))
        torque = math.min(1100, torque + math.floor(bonus * 0.28))

        dynoResult = { hp = hp, torque = torque, peakSpeed = math.floor(peakSpeed), peakRpm = math.floor(peakRpm * 100) }
        if onComplete then onComplete(dynoResult) end
        notify(('Dyno: %d CP / %d Nm (max %d km/h)'):format(hp, torque, dynoResult.peakSpeed), 'success')
    end)
end

function IsDynoActive()
    return dynoActive
end

function GetDynoResult()
    return dynoResult
end

SunsetTuningClient.RunDynoTest = RunDynoTest
SunsetTuningClient.IsDynoActive = IsDynoActive
SunsetTuningClient.GetDynoResult = GetDynoResult
