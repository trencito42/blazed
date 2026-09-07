local STC = SunsetTuningClient
local dynoActive = false
local dynoResult = nil
local dynoHud = {
    active = false,
    phase = '',
    secondsLeft = 0,
    rpm = 0,
    peakRpm = 0,
    progress = 0,
}

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

local function estimatePower(veh, tune, peakRpm)
    local driveForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce')
    local maxVel = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    local mass = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass')
    local mult = STC.getStageMultipliers(tune)
    local rpmFactor = math.max(0.35, peakRpm or 0.5)

    local baseHp = math.floor((driveForce * maxVel * 42.0) + (mass * 0.08))
    local hp = math.floor(baseHp * mult.power * (0.72 + rpmFactor * 0.38))
    local torque = math.floor(hp * (0.72 + mult.torque * 0.18))
    return math.max(80, math.min(980, hp)), math.max(90, math.min(1100, torque))
end

local function placeOnDyno(veh, shop)
    if not shop or not shop.dyno then return false end
    local d = shop.dyno
    SetEntityCoords(veh, d.x, d.y, d.z, false, false, false, false)
    SetEntityHeading(veh, d.w or 0.0)
    SetVehicleOnGroundProperly(veh)
    Wait(100)
    return true
end

local function drawDynoHud()
    if not dynoHud.active then return end

    local barW, barH = 0.22, 0.018
    local cx, cy = 0.5, 0.88
    DrawRect(cx, cy, barW + 0.004, barH + 0.008, 0, 0, 0, 160)
    DrawRect(cx - (barW / 2) + (barW * dynoHud.progress / 2), cy, barW * dynoHud.progress, barH, 255, 119, 0, 220)

    SetTextFont(4)
    SetTextScale(0.55, 0.55)
    SetTextColour(255, 177, 28, 255)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(dynoHud.phase)
    DrawText(0.5, 0.80)

    SetTextFont(4)
    SetTextScale(0.42, 0.42)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(
        ('RPM %d%%  |  MAX %d%%  |  %ds'):format(
            math.floor(dynoHud.rpm * 100),
            math.floor(dynoHud.peakRpm * 100),
            math.max(0, dynoHud.secondsLeft)
        )
    )
    DrawText(0.5, 0.835)

    SetTextFont(4)
    SetTextScale(0.36, 0.36)
    SetTextColour(200, 200, 200, 200)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName('Tine W / accelerația apasata — masina e pe stand, nu trebuie sa mergi')
    DrawText(0.5, 0.905)
end

CreateThread(function()
    while true do
        if dynoHud.active then
            drawDynoHud()
            DisableControlAction(0, 75, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

function RunDynoTest(shop, onComplete)
    if dynoActive then return end
    local veh = getDriverVehicle()
    if veh == 0 then
        notify('Trebuie sa fii la volan pentru dyno', 'error')
        return
    end

    dynoActive = true
    dynoResult = nil

    if not placeOnDyno(veh, shop) then
        dynoActive = false
        notify('Stand dyno indisponibil la acest shop', 'error')
        return
    end

    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleHandbrake(veh, true)
    SetVehicleCurrentRpm(veh, 0.2)

    dynoHud.active = true
    dynoHud.peakRpm = 0.0
    dynoHud.progress = 0.0

    for i = 3, 1, -1 do
        dynoHud.phase = ('PREGATIRE DYNO... %d'):format(i)
        dynoHud.secondsLeft = i
        Wait(1000)
    end

    dynoHud.phase = 'ACCELEREAZA ACUM — TINE W!'
    local testMs = 10000
    local start = GetGameTimer()
    local peakRpm = 0.0

    FreezeEntityPosition(veh, true)

    while GetGameTimer() - start < testMs do
        if not DoesEntityExist(veh) then break end
        local elapsed = GetGameTimer() - start
        local rpm = GetVehicleCurrentRpm(veh)
        if rpm > peakRpm then peakRpm = rpm end
        dynoHud.rpm = rpm
        dynoHud.peakRpm = peakRpm
        dynoHud.progress = math.min(1.0, elapsed / testMs)
        dynoHud.secondsLeft = math.ceil((testMs - elapsed) / 1000)
        Wait(0)
    end

    FreezeEntityPosition(veh, false)
    SetVehicleHandbrake(veh, false)
    dynoHud.active = false
    dynoActive = false

    if peakRpm < 0.35 then
        notify('RPM prea mic — tine W apasat pe stand pana se termina testul', 'error')
        if onComplete then onComplete(nil) end
        return
    end

    local state = STC.appliedVehicles[veh]
    local tune = state and state.tune or SunsetTuning.StockTune()
    local hp, torque = estimatePower(veh, tune, peakRpm)

    dynoResult = {
        hp = hp,
        torque = torque,
        peakSpeed = 0,
        peakRpm = math.floor(peakRpm * 100),
    }

    if onComplete then onComplete(dynoResult) end
    notify(('Dyno finalizat: %d CP / %d Nm (RPM max %d%%)'):format(hp, torque, dynoResult.peakRpm), 'success')
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
