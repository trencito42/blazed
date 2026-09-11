-- Shared idempotent tune → handling calculation.
-- Input: baseline handling table + sanitized tune + vehicle capabilities.
-- Output: final handling floats + engine multipliers (applied once from baseline).

SunsetTuning.TuneCalculator = SunsetTuning.TuneCalculator or {}
local TC = SunsetTuning.TuneCalculator

local HANDLING_FIELDS = {
    'fInitialDriveForce',
    'fDriveInertia',
    'fInitialDriveMaxFlatVel',
    'fTractionCurveMax',
    'fTractionCurveMin',
    'fTractionCurveLateral',
    'fBrakeForce',
    'fSteeringLock',
    'fSuspensionForce',
    'fSuspensionReboundDamp',
    'fLowSpeedTractionLossMult',
    'fClutchChangeRateScaleUpShift',
    'fClutchChangeRateScaleDownShift',
}

function TC.GetBaselineFields()
    return HANDLING_FIELDS
end

local function norm01(value, max)
    max = max or 100
    return math.max(0, math.min(1, (tonumber(value) or 0) / max))
end

local function stageCurve(stage, powerNorm)
    local stageMult = 1.0
    if stage == 'sport' or stage == 'stage1' then stageMult = 1.04 end
    if stage == 'race' or stage == 'stage2' then stageMult = 1.08 end
    if stage == 'stage3' then stageMult = 1.12 end
    -- Per-vehicle powerNorm already capped by profile limits
    return 1.0 + (stageMult - 1.0) + (powerNorm * 0.14)
end

function TC.Compute(baseline, tune, caps)
    baseline = type(baseline) == 'table' and baseline or {}
    tune = SunsetTuning.SanitizeTune(tune, caps)
    caps = caps or {}

    local out = {}
    for _, field in ipairs(HANDLING_FIELDS) do
        out[field] = baseline[field]
    end

    if SunsetTuning.IsStockTune(tune) then
        return {
            handling = out,
            enginePowerMult = 0.0,
            engineTorqueMult = 1.0,
            topSpeedMod = 0.0,
            turboPressure = 0.0,
            exhaustPops = false,
            isStock = true,
        }
    end

    local limits = caps.limits or {}
    local powerMax = limits.power or 65
    local powerNorm = norm01(tune.power, powerMax)
    local torqueNorm = norm01(tune.torque or tune.power, powerMax)
    local throttleNorm = norm01(tune.throttleResponse or 50, 100)
    local topNorm = norm01(tune.topSpeed or 0, limits.topSpeed or 45)
    local shiftNorm = norm01(tune.shiftSpeed or 0, limits.shiftSpeed or 70)
    local regenNorm = norm01(tune.regenBraking or 0, limits.regen or 80)

    local isElectric = caps.propulsion == 'electric' or caps.propulsion == 'hybrid'
    local driveMult = stageCurve(tune.stage, powerNorm)

    if isElectric then
        -- EV: torque response + top speed tradeoff, no combustion multipliers
        local accelBias = 0.92 + (powerNorm * 0.12) + (throttleNorm * 0.06)
        local topBias = 1.0 + (topNorm * 0.05) - (powerNorm * 0.02)
        out.fInitialDriveForce = (baseline.fInitialDriveForce or 0.3) * accelBias
        out.fDriveInertia = (baseline.fDriveInertia or 1.0) * (1.05 - throttleNorm * 0.08)
        out.fInitialDriveMaxFlatVel = (baseline.fInitialDriveMaxFlatVel or 140.0) * topBias
        out.fBrakeForce = (baseline.fBrakeForce or 1.0) * (1.0 + regenNorm * 0.08)
    else
        local gripMult = 1.0
        if tune.drift and tune.drift.enabled then
            local driftGrip = norm01(tune.drift.grip, 80)
            gripMult = 0.55 + driftGrip * 0.45
        end

        local accelBias = driveMult + (torqueNorm * 0.06)
        local topBias = 1.0 + (topNorm * 0.04) - (shiftNorm * 0.015)

        out.fInitialDriveForce = (baseline.fInitialDriveForce or 0.3) * accelBias
        out.fDriveInertia = (baseline.fDriveInertia or 1.0) * (0.96 + torqueNorm * 0.08)
        out.fInitialDriveMaxFlatVel = (baseline.fInitialDriveMaxFlatVel or 140.0) * topBias
        out.fTractionCurveMax = (baseline.fTractionCurveMax or 2.2) * gripMult
        out.fTractionCurveMin = (baseline.fTractionCurveMin or 2.0) * gripMult
        out.fTractionCurveLateral = (baseline.fTractionCurveLateral or 22.0) * (gripMult * 0.98)

        local handling = tune.handling or {}
        out.fBrakeForce = (baseline.fBrakeForce or 1.0) * ((handling.brakePower or 100) / 100.0)
        out.fSteeringLock = (baseline.fSteeringLock or 40.0) * math.min(1.12, (handling.steering or 100) / 100.0)
        out.fSuspensionForce = (baseline.fSuspensionForce or 2.0) * ((handling.suspension or 100) / 100.0)
        out.fSuspensionReboundDamp = (baseline.fSuspensionReboundDamp or 1.0) * (0.95 + ((handling.suspension or 100) / 1000.0))
        out.fLowSpeedTractionLossMult = (baseline.fLowSpeedTractionLossMult or 1.0) * math.max(0.6, 1.8 - ((handling.traction or 100) / 100.0))

        if caps.shiftSpeed and baseline.fClutchChangeRateScaleUpShift then
            local shiftBoost = 1.0 + shiftNorm * 0.35
            out.fClutchChangeRateScaleUpShift = baseline.fClutchChangeRateScaleUpShift * shiftBoost
            out.fClutchChangeRateScaleDownShift = (baseline.fClutchChangeRateScaleDownShift or 2.0) * shiftBoost
        end
    end

    -- Use ONLY engine power multiplier OR drive force boost — not both stacked heavily
    local enginePowerMult = 0.0
    local engineTorqueMult = 1.0 + (torqueNorm * 0.08)
    local topSpeedMod = math.floor(topNorm * 12.0)

    local turboPressure = 0.0
    if tune.hardware and tune.hardware.turbo and tune.antiLag and tune.antiLag.enabled and caps.antiLag then
        turboPressure = 0.45 + norm01(tune.antiLag.intensity, 100) * 0.35
    end

    local exhaustPops = false
    if caps.popsAndBangs and tune.pop and tune.pop.enabled then
        exhaustPops = true
    end

    return {
        handling = out,
        enginePowerMult = enginePowerMult,
        engineTorqueMult = engineTorqueMult,
        topSpeedMod = topSpeedMod,
        turboPressure = turboPressure,
        exhaustPops = exhaustPops,
        isStock = false,
    }
end
