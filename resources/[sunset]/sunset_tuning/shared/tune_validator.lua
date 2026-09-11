SunsetTuning.TuneValidator = SunsetTuning.TuneValidator or {}
local TV = SunsetTuning.TuneValidator
local PR = SunsetTuning.ProfileResolver

function TV.Validate(tune, caps)
    if not caps or not caps.supported then
        return false, 'This vehicle does not support ECU tuning.'
    end

    tune = SunsetTuning.SanitizeTune(tune, caps)

    if not caps.popsAndBangs and tune.pop and tune.pop.enabled then
        return false, 'Pop & bang is not available on this vehicle.'
    end
    if not caps.flames and tune.flames and tune.flames.enabled then
        return false, 'Exhaust flames are not available on this vehicle.'
    end
    if not caps.antiLag and tune.antiLag and tune.antiLag.enabled then
        return false, 'Anti-lag is not available on this vehicle.'
    end
    if not caps.turboBoost and tune.hardware and tune.hardware.turbo then
        return false, 'Turbo is not supported on this vehicle profile.'
    end
    if caps.propulsion == 'electric' then
        if tune.hardware and (tune.hardware.turbo or tune.hardware.launchControl) then
            return false, 'Invalid hardware for electric vehicle.'
        end
        if tune.pop and tune.pop.enabled then return false, 'Exhaust features invalid for EV.' end
    end

    if tune.hardware and tune.hardware.turbo and not caps.factoryTurbo then
        local hasTurboMod = tune.hardware.turbo == true
        if hasTurboMod and not caps.turboBoost then
            return false, 'Turbo upgrade not supported without profile.'
        end
    end

    if tune.hardware and tune.hardware.turbo == false and tune.antiLag and tune.antiLag.enabled then
        return false, 'Anti-lag requires a turbo.'
    end

    return true, tune
end

function TV.ValidateForModel(tune, model, classId)
    local caps = PR.Resolve(model, classId)
    return TV.Validate(tune, caps)
end
