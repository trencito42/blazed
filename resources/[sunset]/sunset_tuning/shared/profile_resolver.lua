SunsetTuning.ProfileResolver = SunsetTuning.ProfileResolver or {}

local PR = SunsetTuning.ProfileResolver
local Profiles = SunsetTuning.VehicleProfiles or {}
local FactoryTurbo = SunsetTuning.FactoryTurboModels or {}

local ELECTRIC_MODELS = {
    raiden = true, cyclone = true, tezeract = true, neon = true, imorgon = true,
    voltic = true, khamelion = true, surge = true, dilettante = true, iwagen = true,
}

local function normalizeModel(model)
    if type(model) == 'number' then
        -- joaat hash passed — caller should pass string when possible
        return nil
    end
    return tostring(model or ''):lower()
end

local function defaultLimits(archetype)
    if archetype == 'super' then return { power = 80, topSpeed = 55, shiftSpeed = 80, regen = 0, throttle = 85 } end
    if archetype == 'sport' or archetype == 'muscle' then return { power = 65, topSpeed = 45, shiftSpeed = 72, regen = 0, throttle = 80 } end
    if archetype == 'motorcycle' then return { power = 68, topSpeed = 50, shiftSpeed = 75, regen = 0, throttle = 82 } end
    if archetype == 'suv' then return { power = 52, topSpeed = 34, shiftSpeed = 58, regen = 0, throttle = 75 } end
    if archetype == 'ev_super' then return { power = 88, topSpeed = 60, shiftSpeed = 0, regen = 75, throttle = 90 } end
    if archetype == 'ev_sport' or archetype == 'ev_roadster' then return { power = 78, topSpeed = 52, shiftSpeed = 0, regen = 78, throttle = 88 } end
    return { power = 50, topSpeed = 32, shiftSpeed = 58, regen = 0, throttle = 75 }
end

local function archetypeFromClass(classId)
    if classId == 7 then return 'super' end
    if classId == 6 or classId == 5 then return 'sport' end
    if classId == 4 then return 'muscle' end
    if classId == 8 then return 'motorcycle' end
    if classId == 2 or classId == 9 then return 'suv' end
    if classId == 13 then return 'bicycle' end
    if classId == 14 or classId == 15 or classId == 16 then return 'aircraft' end
    if classId == 0 or classId == 1 then return 'compact' end
    return 'sedan'
end

local function buildCapabilities(profile, modelName, classId)
    local propulsion = profile.propulsion or 'petrol'
    local induction = profile.induction or 'naturally_aspirated'
    local archetype = profile.archetype or archetypeFromClass(classId)
    local isElectric = propulsion == 'electric' or propulsion == 'hybrid' and induction == 'electric'
    local isBicycle = archetype == 'bicycle' or classId == 13
    local isMotorcycle = archetype == 'motorcycle' or classId == 8
    local isBoat = classId == 14
    local isAircraft = classId == 15 or classId == 16
    local hasCombustion = not isElectric and not isBicycle and not isBoat and not isAircraft
    local hasExhaust = hasCombustion and not isElectric
    local factoryTurbo = FactoryTurbo[modelName] == true or induction == 'turbo' or induction == 'supercharged'
    local limits = profile.limits or defaultLimits(archetype)

    return {
        supported = not isBicycle and not isBoat and not isAircraft,
        model = modelName,
        classId = classId,
        archetype = archetype,
        propulsion = propulsion,
        induction = induction,
        drivetrain = profile.drivetrain or 'rwd',
        drivetrainLabel = (profile.drivetrain or 'rwd'):upper(),
        profileSource = profile.source or 'resolver',

        hasEngine = not isBicycle,
        hasCombustionEngine = hasCombustion,
        hasExhaust = hasExhaust,
        factoryTurbo = factoryTurbo,
        singleSpeed = isElectric,

        -- UI capability flags
        power = not isBicycle,
        torqueResponse = not isBicycle,
        throttleResponse = true,
        topSpeed = not isBicycle,
        shiftSpeed = hasCombustion and not isElectric,
        launchControl = not isBicycle and not isElectric,
        tractionControl = not isBicycle,
        differential = hasCombustion and (profile.drivetrain == 'awd' or profile.drivetrain == 'rwd'),
        regenBraking = isElectric,
        turboBoost = hasCombustion and factoryTurbo,
        turboResponse = hasCombustion and factoryTurbo,
        antiLag = hasCombustion and factoryTurbo,
        popsAndBangs = hasExhaust,
        flames = hasExhaust,
        revLimiter = hasCombustion,
        exhaustModes = hasExhaust,
        drift = hasCombustion and not isMotorcycle,
        hud = not isBicycle,
        hardware = hasCombustion,
        presets = not isBicycle,

        limits = limits,
    }
end

function PR.Resolve(model, classId)
    local modelName = normalizeModel(model)
    if not modelName or modelName == '' then
        return buildCapabilities({ propulsion = 'petrol', archetype = 'sedan', source = 'default' }, 'unknown', classId or 1)
    end

    if ELECTRIC_MODELS[modelName] then
        local p = Profiles[modelName] or { propulsion = 'electric', induction = 'electric', archetype = 'ev_sport' }
        p.source = Profiles[modelName] and 'model_override' or 'electric_list'
        return buildCapabilities(p, modelName, classId)
    end

    if Profiles[modelName] then
        local p = Profiles[modelName]
        p.source = 'model_override'
        return buildCapabilities(p, modelName, classId)
    end

    local archetype = archetypeFromClass(classId or 1)
    if archetype == 'bicycle' then
        return buildCapabilities({ propulsion = 'human', archetype = 'bicycle', source = 'class_fallback' }, modelName, classId)
    end

    -- Unknown add-on: hide combustion-specific extras until profile is configured
    local caps = buildCapabilities({
        propulsion = 'petrol',
        induction = 'naturally_aspirated',
        archetype = archetype,
        source = 'unknown_addon',
        limits = defaultLimits(archetype),
    }, modelName, classId)
    caps.turboBoost = false
    caps.turboResponse = false
    caps.antiLag = false
    caps.popsAndBangs = false
    caps.flames = false
    caps.revLimiter = false
    caps.exhaustModes = false
    caps.factoryTurbo = false
    return caps
end

function PR.ResolveFromEntityData(model, classId)
    return PR.Resolve(model, classId)
end

function PR.DisplayLabel(caps)
    if not caps then return 'UNKNOWN' end
    if not caps.supported then return 'NOT SUPPORTED' end
    if caps.propulsion == 'electric' then return 'ELECTRIC' end
    if caps.propulsion == 'hybrid' then return 'HYBRID' end
    if caps.induction == 'turbo' or caps.induction == 'supercharged' then
        return ('TURBO %s'):format(caps.propulsion:upper())
    end
    if caps.archetype == 'motorcycle' then return 'MOTORCYCLE' end
    return caps.propulsion:upper()
end
