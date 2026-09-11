SunsetTuningClient = SunsetTuningClient or {}
local STC = SunsetTuningClient
local TC = SunsetTuning.TuneCalculator

STC.modelBaselines = STC.modelBaselines or {}

local function readBaselineFromVehicle(veh)
    local baseline = {}
    for _, field in ipairs(TC.GetBaselineFields()) do
        baseline[field] = GetVehicleHandlingFloat(veh, 'CHandlingData', field)
    end
    baseline.mods = {}
    SetVehicleModKit(veh, 0)
    for key, slot in pairs(SunsetTuning.HardwareSlots or {}) do
        baseline.mods[key] = GetVehicleMod(veh, slot.modType)
    end
    baseline.turbo = IsToggleModOn(veh, 18)
    return baseline
end

function STC.getModelHash(veh)
    return GetEntityModel(veh)
end

function CaptureModelBaseline(veh)
    return STC.captureModelBaseline(veh)
end
exports('CaptureModelBaseline', CaptureModelBaseline)

function STC.captureModelBaseline(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local modelHash = STC.getModelHash(veh)
    if STC.modelBaselines[modelHash] then return STC.modelBaselines[modelHash] end
    STC.modelBaselines[modelHash] = readBaselineFromVehicle(veh)
    return STC.modelBaselines[modelHash]
end

function STC.getVehicleCapabilities(veh)
    local modelHash = STC.getModelHash(veh)
    local modelName = GetDisplayNameFromVehicleModel(modelHash)
    if modelName then modelName = modelName:lower() end
    -- Prefer spawn model name from entity if available via plate cache
    local classId = GetVehicleClass(veh)
    return SunsetTuning.ProfileResolver.Resolve(modelName, classId)
end

function STC.restoreBaselineHandling(veh, baseline)
    if not baseline then return end
    for field, value in pairs(baseline) do
        if type(field) == 'string' and field:sub(1, 1) == 'f' and type(value) == 'number' then
            SetVehicleHandlingFloat(veh, 'CHandlingData', field, value)
        end
    end
    SetVehicleModKit(veh, 0)
    if baseline.mods then
        for key, slot in pairs(SunsetTuning.HardwareSlots or {}) do
            SetVehicleMod(veh, slot.modType, baseline.mods[key] or -1, false)
        end
    end
    ToggleVehicleMod(veh, 18, baseline.turbo == true)
    SetVehicleEnginePowerMultiplier(veh, 0.0)
    SetVehicleEngineTorqueMultiplier(veh, 1.0)
    ModifyVehicleTopSpeed(veh, 0.0)
    SetVehicleTurboPressure(veh, 0.0)
    pcall(function() EnableVehicleExhaustPops(veh, false) end)
end
