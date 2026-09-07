SunsetTuningClient = SunsetTuningClient or {}
local STC = SunsetTuningClient

STC.appliedVehicles = {}
STC.plateTunes = {}
STC.persistedPlates = {}

function STC.normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

function STC.plateOf(veh)
    if not veh or veh == 0 then return '' end
    return STC.normalizePlate(GetVehicleNumberPlateText(veh))
end

function STC.getStageMultipliers(tune)
    local stage = SunsetTuning.Stages[tune.stage] or SunsetTuning.Stages.civil
    local powerPct = (tonumber(tune.power) or 100) / 100.0
    local torquePct = (tonumber(tune.torque) or 100) / 100.0
    return {
        power = stage.power * powerPct,
        torque = stage.torque * torquePct,
        grip = stage.grip,
        popIntensity = stage.popIntensity,
    }
end

local function cacheOriginalHandling(veh)
    local state = STC.appliedVehicles[veh]
    if state and state.base then return state.base end
    local base = {
        driveForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce'),
        driveInertia = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fDriveInertia'),
        maxVel = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel'),
        tractionMax = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax'),
        tractionMin = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMin'),
        tractionLat = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveLateral'),
    }
    STC.appliedVehicles[veh] = STC.appliedVehicles[veh] or {}
    STC.appliedVehicles[veh].base = base
    return base
end

local function setHandlingFloat(veh, field, value)
    if value and value > 0 then
        SetVehicleHandlingFloat(veh, 'CHandlingData', field, value)
    end
end

local function restoreBaseHandling(veh)
    local state = STC.appliedVehicles[veh]
    local base = state and state.base
    if not base then return end
    setHandlingFloat(veh, 'fInitialDriveForce', base.driveForce)
    setHandlingFloat(veh, 'fDriveInertia', base.driveInertia)
    setHandlingFloat(veh, 'fInitialDriveMaxFlatVel', base.maxVel)
    setHandlingFloat(veh, 'fTractionCurveMax', base.tractionMax)
    setHandlingFloat(veh, 'fTractionCurveMin', base.tractionMin)
    setHandlingFloat(veh, 'fTractionCurveLateral', base.tractionLat)
    SetVehicleEnginePowerMultiplier(veh, 1.0)
    SetVehicleEngineTorqueMultiplier(veh, 1.0)
    ModifyVehicleTopSpeed(veh, 0.0)
    SetVehicleTurboPressure(veh, 0.0)
end

function ApplyTune(veh, tune, persist)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    tune = SunsetTuning.SanitizeTune(tune)
    local mult = STC.getStageMultipliers(tune)
    local base = cacheOriginalHandling(veh)
    local isStock = SunsetTuning.IsStockTune(tune)

    if isStock then
        restoreBaseHandling(veh)
    else
        setHandlingFloat(veh, 'fInitialDriveForce', base.driveForce * mult.power)
        setHandlingFloat(veh, 'fDriveInertia', base.driveInertia * (0.92 + (mult.torque * 0.08)))
        setHandlingFloat(veh, 'fInitialDriveMaxFlatVel', base.maxVel * (0.98 + (mult.power * 0.04)))

        local gripMult = mult.grip
        if tune.drift.enabled then
            local driftGrip = (tonumber(tune.drift.grip) or 45) / 100.0
            gripMult = gripMult * (0.55 + driftGrip * 0.45)
        end

        setHandlingFloat(veh, 'fTractionCurveMax', base.tractionMax * gripMult)
        setHandlingFloat(veh, 'fTractionCurveMin', base.tractionMin * gripMult)
        setHandlingFloat(veh, 'fTractionCurveLateral', base.tractionLat * (gripMult * 0.96))

        SetVehicleEnginePowerMultiplier(veh, mult.power)
        SetVehicleEngineTorqueMultiplier(veh, mult.torque)
        ModifyVehicleTopSpeed(veh, math.floor((mult.power - 1.0) * 22.0))

        if tune.antiLag.enabled then
            SetVehicleTurboPressure(veh, 0.65 + ((tonumber(tune.antiLag.intensity) or 55) / 180.0))
        else
            SetVehicleTurboPressure(veh, 0.0)
        end
    end

    local plate = STC.plateOf(veh)
    STC.appliedVehicles[veh] = STC.appliedVehicles[veh] or {}
    STC.appliedVehicles[veh].tune = tune
    STC.appliedVehicles[veh].mult = mult

    if plate ~= '' then
        STC.plateTunes[plate] = tune
        if persist then
            STC.persistedPlates[plate] = true
            if GetResourceState('sunset_vehicles') == 'started' then
                if isStock then
                    pcall(function() exports.sunset_vehicles:SetVehicleProp('ecu', nil) end)
                else
                    pcall(function() exports.sunset_vehicles:SetVehicleProp('ecu', tune) end)
                end
            end
        end
    end

    return true
end

function GetTuneForPlate(plate)
    plate = STC.normalizePlate(plate)
    if STC.plateTunes[plate] then return STC.plateTunes[plate] end
    return SunsetTuning.StockTune()
end

function ExportTuneForStore(veh)
    if not veh or veh == 0 then return nil end
    local plate = STC.plateOf(veh)
    if plate ~= '' and STC.persistedPlates[plate] and STC.plateTunes[plate] then
        local tune = STC.plateTunes[plate]
        if not SunsetTuning.IsStockTune(tune) then return tune end
    end
    return nil
end

exports('ApplyTune', ApplyTune)
exports('GetTuneForPlate', GetTuneForPlate)
exports('ExportTuneForStore', ExportTuneForStore)
exports('FormatVehicleInfo', function(ecu)
    return SunsetTuning.BuildVehicleInfo(ecu)
end)

RegisterNetEvent('sunset:tuning:client:applyByPlate', function(plate, tune)
    plate = STC.normalizePlate(plate)
    if type(tune) == 'table' then
        tune = SunsetTuning.SanitizeTune(tune)
        STC.plateTunes[plate] = tune
        STC.persistedPlates[plate] = true
    end
    local activeTune = STC.plateTunes[plate]
    if not activeTune then return end
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if STC.plateOf(veh) == plate then
            ApplyTune(veh, activeTune, STC.persistedPlates[plate] == true)
        end
    end
end)

RegisterNetEvent('sunset:tuning:client:loadPlateTune', function(plate, tune, persisted)
    plate = STC.normalizePlate(plate)
    if persisted and tune then
        STC.plateTunes[plate] = SunsetTuning.SanitizeTune(tune)
        STC.persistedPlates[plate] = true
    else
        STC.plateTunes[plate] = nil
        STC.persistedPlates[plate] = nil
    end
end)

AddEventHandler('entityRemoved', function(entity)
    STC.appliedVehicles[entity] = nil
end)

CreateThread(function()
    while true do
        Wait(2500)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then goto continue end
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 or STC.appliedVehicles[veh] then goto continue end
        local plate = STC.plateOf(veh)
        if plate ~= '' and STC.persistedPlates[plate] and STC.plateTunes[plate] then
            ApplyTune(veh, STC.plateTunes[plate], false)
        end
        ::continue::
    end
end)
