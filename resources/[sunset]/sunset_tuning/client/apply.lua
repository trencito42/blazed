SunsetTuningClient = SunsetTuningClient or {}
local STC = SunsetTuningClient
local TC = SunsetTuning.TuneCalculator
local PR = SunsetTuning.ProfileResolver

STC.appliedVehicles = STC.appliedVehicles or {}
STC.plateTunes = STC.plateTunes or {}
STC.persistedPlates = STC.persistedPlates or {}
STC.plateModels = STC.plateModels or {}

function STC.normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

function STC.plateOf(veh)
    if not veh or veh == 0 then return '' end
    return STC.normalizePlate(GetVehicleNumberPlateText(veh))
end

function STC.getStageMultipliers(tune)
    local stage = SunsetTuning.Stages[tune.stage] or SunsetTuning.Stages.civil
    local powerPct = 1.0 + ((tonumber(tune.power) or 0) / 100.0) * 0.14
    local torquePct = 1.0 + ((tonumber(tune.torque) or 0) / 100.0) * 0.12
    return {
        power = stage.power * powerPct,
        torque = stage.torque * torquePct,
        grip = stage.grip,
        popIntensity = stage.popIntensity,
    }
end

local function applyHardware(veh, tune, baseline, caps)
    if not caps or not caps.hardware then return end
    SetVehicleModKit(veh, 0)
    for key, slot in pairs(SunsetTuning.HardwareSlots or {}) do
        local count = math.max(0, GetNumVehicleMods(veh, slot.modType))
        local level = math.max(0, math.min(tonumber(tune.hardware[key]) or 0, count))
        SetVehicleMod(veh, slot.modType, level > 0 and (level - 1) or -1, false)
    end
    if caps.turboBoost or caps.factoryTurbo then
        ToggleVehicleMod(veh, 18, tune.hardware.turbo == true)
    else
        ToggleVehicleMod(veh, 18, baseline.turbo == true)
    end
end

local function applyCalculated(veh, calculated)
    local handling = calculated.handling or {}
    for field, value in pairs(handling) do
        if type(value) == 'number' and value > 0 then
            SetVehicleHandlingFloat(veh, 'CHandlingData', field, value)
        end
    end
    SetVehicleEnginePowerMultiplier(veh, calculated.enginePowerMult or 0.0)
    SetVehicleEngineTorqueMultiplier(veh, calculated.engineTorqueMult or 1.0)
    ModifyVehicleTopSpeed(veh, calculated.topSpeedMod or 0.0)
    SetVehicleTurboPressure(veh, calculated.turboPressure or 0.0)
    pcall(function() EnableVehicleExhaustPops(veh, calculated.exhaustPops == true) end)
end

function ApplyTune(veh, tune, persist, modelName)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end

    local classId = GetVehicleClass(veh)
    if not modelName or modelName == '' then
        modelName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
        if modelName then modelName = modelName:lower() end
    end

    local caps = SunsetTuning.ProfileResolver.Resolve(modelName, classId)
    if not caps.supported then return false end

    tune = SunsetTuning.SanitizeTune(tune, caps)
    local baseline = STC.captureModelBaseline(veh)
    if not baseline then return false end

    -- Idempotent: always restore stock baseline before applying tune
    STC.restoreBaselineHandling(veh, baseline)

    local calculated = TC.Compute(baseline, tune, caps)
    if not calculated.isStock then
        applyHardware(veh, tune, baseline, caps)
        applyCalculated(veh, calculated)
    end

    local mult = STC.getStageMultipliers(tune)
    local plate = STC.plateOf(veh)
    STC.appliedVehicles[veh] = {
        tune = tune,
        mult = mult,
        caps = caps,
        baseline = baseline,
        calculated = calculated,
        model = modelName,
    }

    if plate ~= '' then
        STC.plateTunes[plate] = tune
        STC.plateModels[plate] = modelName
        if persist then
            STC.persistedPlates[plate] = true
            if GetResourceState('sunset_vehicles') == 'started' then
                if calculated.isStock then
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
exports('GetVehicleCapabilities', function(veh)
    if not veh or veh == 0 then return nil end
    return STC.getVehicleCapabilities(veh)
end)

RegisterNetEvent('sunset:tuning:client:applyByPlate', function(plate, tune, modelName)
    plate = STC.normalizePlate(plate)
    if type(tune) == 'table' then
        tune = SunsetTuning.SanitizeTune(tune)
        STC.plateTunes[plate] = tune
        STC.persistedPlates[plate] = true
        if modelName then STC.plateModels[plate] = modelName end
    end
    local activeTune = STC.plateTunes[plate]
    if not activeTune then return end
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if STC.plateOf(veh) == plate then
            ApplyTune(veh, activeTune, false, STC.plateModels[plate])
        end
    end
end)

RegisterNetEvent('sunset:tuning:client:loadPlateTune', function(plate, tune, persisted, modelName)
    plate = STC.normalizePlate(plate)
    if persisted and tune then
        STC.plateTunes[plate] = SunsetTuning.SanitizeTune(tune)
        STC.persistedPlates[plate] = true
        if modelName then STC.plateModels[plate] = modelName end
    else
        STC.plateTunes[plate] = nil
        STC.persistedPlates[plate] = nil
        STC.plateModels[plate] = nil
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
            ApplyTune(veh, STC.plateTunes[plate], false, STC.plateModels[plate])
        end
        ::continue::
    end
end)
