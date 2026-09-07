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

--- Keep the car level and pinned — never teleport inside LS Customs (causes flip).
local function captureDynoPose(veh)
    local coords = GetEntityCoords(veh)
    local heading = GetEntityHeading(veh)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
    }
end

local function pinVehicle(veh, pose)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not pose then return end
    SetEntityCoords(veh, pose.x, pose.y, pose.z, false, false, false, true)
    SetEntityRotation(veh, 0.0, 0.0, pose.heading, 2, true)
    SetEntityVelocity(veh, 0.0, 0.0, 0.0)
    SetVehicleForwardSpeed(veh, 0.0)
end

-- The handbrake holds the car on the rollers. Re-applying coordinates and
-- forward speed every frame cancels GTA's throttle/RPM simulation, so only
-- correct the vehicle if it has actually drifted off the stand.
local function holdVehicleOnDyno(veh, pose)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not pose then return end
    SetVehicleHandbrake(veh, true)
    local coords = GetEntityCoords(veh)
    local dx, dy, dz = coords.x - pose.x, coords.y - pose.y, coords.z - pose.z
    if (dx * dx + dy * dy) > 0.64 or math.abs(dz) > 0.45 then
        pinVehicle(veh, pose)
    end
end

local function prepareDynoVehicle(veh)
    local pose = captureDynoPose(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleHandbrake(veh, true)
    SetEntityCollision(veh, true, true)
    pinVehicle(veh, pose)
    Wait(50)
    pinVehicle(veh, pose)
    return pose
end

local function releaseDynoVehicle(veh, pose)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleHandbrake(veh, false)
    if pose then pinVehicle(veh, pose) end
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
    AddTextComponentSubstringPlayerName('Tine W apasat — masina sta pe loc pe stand')
    DrawText(0.5, 0.905)
end

CreateThread(function()
    while true do
        if dynoHud.active then
            drawDynoHud()
            EnableControlAction(0, 71, true)   -- vehicle accelerate
            DisableControlAction(0, 75, true)  -- exit vehicle
            DisableControlAction(0, 59, true)  -- steer left
            DisableControlAction(0, 60, true)  -- steer right
            DisableControlAction(0, 63, true)
            DisableControlAction(0, 64, true)
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
    STC.dynoActive = true
    dynoResult = nil

    local pose = prepareDynoVehicle(veh)

    dynoHud.active = true
    dynoHud.peakRpm = 0.0
    dynoHud.progress = 0.0

    for i = 3, 1, -1 do
        dynoHud.phase = ('PREGATIRE DYNO... %d'):format(i)
        dynoHud.secondsLeft = i
        pinVehicle(veh, pose)
        Wait(1000)
    end

    dynoHud.phase = 'ACCELEREAZA ACUM — TINE W!'
    local testMs = 10000
    local start = GetGameTimer()
    local peakRpm = 0.0
    local nextPositionCheck = 0

    while GetGameTimer() - start < testMs do
        if not DoesEntityExist(veh) then break end
        local elapsed = GetGameTimer() - start
        if elapsed >= nextPositionCheck then
            holdVehicleOnDyno(veh, pose)
            nextPositionCheck = elapsed + 250
        end
        local rpm = GetVehicleCurrentRpm(veh)
        if rpm > peakRpm then peakRpm = rpm end
        dynoHud.rpm = rpm
        dynoHud.peakRpm = peakRpm
        dynoHud.progress = math.min(1.0, elapsed / testMs)
        dynoHud.secondsLeft = math.ceil((testMs - elapsed) / 1000)
        Wait(0)
    end

    releaseDynoVehicle(veh, pose)
    dynoHud.active = false
    dynoActive = false
    STC.dynoActive = false

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
