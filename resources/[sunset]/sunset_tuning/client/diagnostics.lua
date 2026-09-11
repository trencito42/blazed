local function isAdmin()
    local ok, level = pcall(function()
        return exports.sunset_admin:GetAdminLevel()
    end)
    return ok and (tonumber(level) or 0) >= 2
end

local function printLine(msg)
    print(('[ECU DEBUG] %s'):format(msg))
    exports.sunset_ui:Notify(msg, 'info', 8000)
end

RegisterCommand('ecudebug', function()
    if not isAdmin() then
        exports.sunset_ui:Notify('ECU debug requires admin level 2+.', 'error')
        return
    end

    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        exports.sunset_ui:Notify('Sit in a vehicle to run ECU debug.', 'error')
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)
    local modelHash = GetEntityModel(veh)
    local display = GetDisplayNameFromVehicleModel(modelHash)
    local classId = GetVehicleClass(veh)
    local plate = SunsetTuningClient.plateOf(veh)
    local modelName = SunsetTuningClient.plateModels[plate] or (display and display:lower()) or 'unknown'
    local caps = SunsetTuning.ProfileResolver.Resolve(modelName, classId)
    local state = SunsetTuningClient.appliedVehicles[veh]
    local tune = state and state.tune or GetTuneForPlate(plate)
    local baseline = SunsetTuningClient.modelBaselines[modelHash]
    local calculated = state and state.calculated

    printLine(('Model: %s (hash %s) plate %s'):format(modelName, modelHash, plate))
    printLine(('Class: %d | Profile: %s | Source: %s'):format(classId, caps.archetype or '?', caps.profileSource or '?'))
    printLine(('Propulsion: %s | Induction: %s | Label: %s'):format(caps.propulsion, caps.induction, SunsetTuning.ProfileResolver.DisplayLabel(caps)))
    printLine(('Supported: %s | Pops: %s | Turbo: %s | EV regen: %s'):format(
        tostring(caps.supported), tostring(caps.popsAndBangs), tostring(caps.turboBoost), tostring(caps.regenBraking)))

    if baseline then
        printLine(('Baseline driveForce=%.4f maxVel=%.2f'):format(baseline.fInitialDriveForce or 0, baseline.fInitialDriveMaxFlatVel or 0))
    else
        printLine('Baseline: NOT CAPTURED')
    end

    if tune then
        printLine(('Saved tune: stage=%s power=%d torque=%d v%d'):format(
            tune.stage, tune.power or 0, tune.torque or 0, tune.profileVersion or 1))
    end

    if calculated and calculated.handling then
        printLine(('Applied driveForce=%.4f maxVel=%.2f torqueMult=%.3f'):format(
            calculated.handling.fInitialDriveForce or 0,
            calculated.handling.fInitialDriveMaxFlatVel or 0,
            calculated.engineTorqueMult or 1.0))
    end
end, false)
