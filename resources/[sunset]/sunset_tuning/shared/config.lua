SunsetTuning = SunsetTuning or {}

SunsetTuning.InteractRadius = 6.0
SunsetTuning.SaveBaseCost = 750
SunsetTuning.DynoCost = 250
SunsetTuning.FlashCost = 150

-- GTA V performance slots. Level 0 means factory, positive levels map to the
-- available mod index on that specific vehicle (and are clamped client-side).
SunsetTuning.HardwareSlots = {
    engine = { label = 'Engine', modType = 11, maxLevel = 4, unitCost = 1800 },
    brakes = { label = 'Brakes', modType = 12, maxLevel = 3, unitCost = 1200 },
    transmission = { label = 'Transmission', modType = 13, maxLevel = 3, unitCost = 1600 },
    suspension = { label = 'Suspension', modType = 15, maxLevel = 4, unitCost = 1100 },
    armor = { label = 'Armor', modType = 16, maxLevel = 5, unitCost = 1500 },
}

SunsetTuning.FeatureCosts = {
    turbo = 4500,
    launchControl = 2200,
    pop = 950,
    flames = 800,
    antiLag = 2400,
    drift = 1400,
    hud = 350,
    sportMap = 2200,
    raceMap = 5200,
    customMapStep = 55,
    cosmetics = 600,
    vanityPlate = 1800,
}

SunsetTuning.Stages = {
    civil = { label = 'Silent (Civil)', power = 1.0, torque = 1.0, grip = 1.0, popIntensity = 0.35 },
    sport = { label = 'Normal (Sport)', power = 1.06, torque = 1.05, grip = 1.0, popIntensity = 0.65 },
    race = { label = 'Aggressive (Race)', power = 1.14, torque = 1.12, grip = 0.94, popIntensity = 1.0 },
}

SunsetTuning.ExhaustModes = {
    pop_bang = { label = 'Pop & Bang', flames = false, diesel = false },
    flames = { label = 'Flammen', flames = true, diesel = false },
    diesel = { label = 'Diesel', flames = false, diesel = true },
    extra = { label = 'Extra Loud', flames = true, diesel = false },
}

SunsetTuning.Shops = {
    {
        id = 'lsc_main',
        label = 'LS Customs — ECU Bay',
        coords = vector3(-337.52, -136.57, 39.01),
        dyno = vector4(-339.85, -142.35, 39.01, 68.0),
        blip = { sprite = 72, color = 47, scale = 0.85 },
    },
    {
        id = 'lsc_harmony',
        label = 'Harmony Tuning',
        coords = vector3(1174.82, 2640.45, 37.75),
        dyno = vector4(1178.35, 2636.10, 37.75, 90.0),
        blip = { sprite = 72, color = 47, scale = 0.8 },
    },
}

--- Factory map — nothing enabled until player saves a tune.
SunsetTuning.ProfileVersion = 2

function SunsetTuning.StockTune()
    return {
        profileVersion = SunsetTuning.ProfileVersion,
        stage = 'civil',
        power = 0,
        torque = 0,
        throttleResponse = 0,
        topSpeed = 0,
        shiftSpeed = 0,
        regenBraking = 0,
        exhaust = 'pop_bang',
        pop = {
            enabled = false,
            rpmMax = 88,
            durationMs = 100,
            secondBurst = false,
            burstStage = 'civil',
        },
        flames = { enabled = false, color = { r = 255, g = 120, b = 40 } },
        antiLag = { enabled = false, intensity = 55 },
        drift = { enabled = false, grip = 45 },
        hardware = {
            engine = 0,
            brakes = 0,
            transmission = 0,
            suspension = 0,
            armor = 0,
            turbo = false,
            launchControl = false,
        },
        handling = {
            steering = 100,
            brakePower = 100,
            suspension = 100,
            traction = 100,
        },
        hud = { enabled = false },
        dyno = { lastHp = 0, lastTorque = 0, lastRunAt = 0 },
    }
end

function SunsetTuning.DefaultTune()
    return SunsetTuning.StockTune()
end

local function migrateLegacyTune(raw, def)
    -- v1 tunes used power/torque 85-120 centered at 100; map to 0-100 profile scale
    local power = tonumber(raw.power)
    if power and power >= 85 and power <= 120 then
        raw.power = math.max(0, math.min(100, math.floor((power - 100) * 2.5 + 50)))
    end
    local torque = tonumber(raw.torque)
    if torque and torque >= 85 and torque <= 120 then
        raw.torque = math.max(0, math.min(100, math.floor((torque - 100) * 2.5 + 50)))
    end
    if raw.stage == 'sport' and (raw.power or 0) < 15 then raw.power = 25 end
    if raw.stage == 'race' and (raw.power or 0) < 25 then raw.power = 45 end
    raw.profileVersion = SunsetTuning.ProfileVersion
    return raw
end

function SunsetTuning.SanitizeTune(raw, caps)
    local def = SunsetTuning.StockTune()
    if type(raw) ~= 'table' then return def end

    if (tonumber(raw.profileVersion) or 1) < (SunsetTuning.ProfileVersion or 2) then
        raw = migrateLegacyTune(raw, def)
    end

    local limits = (type(caps) == 'table' and caps.limits) or {}
    local powerMax = limits.power or 100
    local topMax = limits.topSpeed or 100
    local shiftMax = limits.shiftSpeed or 100
    local regenMax = limits.regen or 100

    local stage = tostring(raw.stage or def.stage)
    if not SunsetTuning.Stages[stage] then stage = def.stage end

    local exhaust = tostring(raw.exhaust or def.exhaust)
    if not SunsetTuning.ExhaustModes[exhaust] then exhaust = def.exhaust end

    local pop = type(raw.pop) == 'table' and raw.pop or {}
    local flames = type(raw.flames) == 'table' and raw.flames or {}
    local antiLag = type(raw.antiLag) == 'table' and raw.antiLag or {}
    local drift = type(raw.drift) == 'table' and raw.drift or {}
    local hardware = type(raw.hardware) == 'table' and raw.hardware or {}
    local handling = type(raw.handling) == 'table' and raw.handling or {}
    local hud = type(raw.hud) == 'table' and raw.hud or {}
    local dyno = type(raw.dyno) == 'table' and raw.dyno or {}

    local turboAllowed = not caps or caps.turboBoost or caps.factoryTurbo
    local hardwareTurbo = hardware.turbo == true and turboAllowed

    local popsAllowed = (caps == nil) or (caps.popsAndBangs ~= false)
    local flamesAllowed = (caps == nil) or (caps.flames ~= false)
    local antiLagAllowed = (caps == nil) or (caps.antiLag ~= false)

    return {
        profileVersion = SunsetTuning.ProfileVersion,
        stage = stage,
        power = math.max(0, math.min(powerMax, math.floor(tonumber(raw.power) or def.power))),
        torque = math.max(0, math.min(powerMax, math.floor(tonumber(raw.torque) or def.torque))),
        throttleResponse = math.max(0, math.min(100, math.floor(tonumber(raw.throttleResponse) or def.throttleResponse))),
        topSpeed = math.max(0, math.min(topMax, math.floor(tonumber(raw.topSpeed) or def.topSpeed))),
        shiftSpeed = math.max(0, math.min(shiftMax, math.floor(tonumber(raw.shiftSpeed) or def.shiftSpeed))),
        regenBraking = math.max(0, math.min(regenMax, math.floor(tonumber(raw.regenBraking) or def.regenBraking))),
        exhaust = exhaust,
        pop = {
            enabled = popsAllowed and pop.enabled == true or false,
            rpmMax = math.max(70, math.min(100, math.floor(tonumber(pop.rpmMax) or def.pop.rpmMax))),
            durationMs = math.max(40, math.min(250, math.floor(tonumber(pop.durationMs) or def.pop.durationMs))),
            secondBurst = pop.secondBurst == true,
            burstStage = SunsetTuning.Stages[tostring(pop.burstStage or stage)] and tostring(pop.burstStage or stage) or stage,
        },
        flames = {
            enabled = flamesAllowed and (flames.enabled == true or exhaust == 'flames' or exhaust == 'extra') or false,
            color = {
                r = math.max(0, math.min(255, math.floor(tonumber(flames.color and flames.color.r) or 255))),
                g = math.max(0, math.min(255, math.floor(tonumber(flames.color and flames.color.g) or 120))),
                b = math.max(0, math.min(255, math.floor(tonumber(flames.color and flames.color.b) or 40))),
            },
        },
        antiLag = {
            enabled = antiLagAllowed and antiLag.enabled == true or false,
            intensity = math.max(0, math.min(100, math.floor(tonumber(antiLag.intensity) or def.antiLag.intensity))),
        },
        drift = {
            enabled = drift.enabled == true,
            grip = math.max(20, math.min(80, math.floor(tonumber(drift.grip) or def.drift.grip))),
        },
        hardware = {
            engine = math.max(0, math.min(4, math.floor(tonumber(hardware.engine) or 0))),
            brakes = math.max(0, math.min(3, math.floor(tonumber(hardware.brakes) or 0))),
            transmission = math.max(0, math.min(3, math.floor(tonumber(hardware.transmission) or 0))),
            suspension = math.max(0, math.min(4, math.floor(tonumber(hardware.suspension) or 0))),
            armor = math.max(0, math.min(5, math.floor(tonumber(hardware.armor) or 0))),
            turbo = hardwareTurbo == true,
            launchControl = hardware.launchControl == true,
        },
        handling = {
            steering = math.max(85, math.min(120, math.floor(tonumber(handling.steering) or 100))),
            brakePower = math.max(85, math.min(140, math.floor(tonumber(handling.brakePower) or 100))),
            suspension = math.max(80, math.min(130, math.floor(tonumber(handling.suspension) or 100))),
            traction = math.max(75, math.min(120, math.floor(tonumber(handling.traction) or 100))),
        },
        hud = { enabled = hud.enabled == true },
        dyno = {
            lastHp = math.max(0, math.floor(tonumber(dyno.lastHp) or 0)),
            lastTorque = math.max(0, math.floor(tonumber(dyno.lastTorque) or 0)),
            lastRunAt = math.max(0, math.floor(tonumber(dyno.lastRunAt) or 0)),
        },
    }
end

function SunsetTuning.IsStockTune(raw)
    if type(raw) ~= 'table' then return true end
    local tune = SunsetTuning.SanitizeTune(raw)
    if tune.stage ~= 'civil' or tune.power ~= 0 or tune.torque ~= 0 then return false end
    if tune.throttleResponse ~= 0 or tune.topSpeed ~= 0 or tune.shiftSpeed ~= 0 or tune.regenBraking ~= 0 then return false end
    if tune.pop.enabled or tune.antiLag.enabled or tune.drift.enabled or tune.hud.enabled then return false end
    if tune.flames.enabled then return false end
    for key in pairs(SunsetTuning.HardwareSlots) do
        if (tune.hardware[key] or 0) > 0 then return false end
    end
    if tune.hardware.turbo or tune.hardware.launchControl then return false end
    if tune.handling.steering ~= 100 or tune.handling.brakePower ~= 100
        or tune.handling.suspension ~= 100 or tune.handling.traction ~= 100 then return false end
    if (tune.dyno.lastHp or 0) > 0 then return false end
    return true
end

function SunsetTuning.HasPerformanceChanges(raw)
    local tune = SunsetTuning.SanitizeTune(raw)
    if tune.stage ~= 'civil' or tune.power ~= 0 or tune.torque ~= 0 or tune.drift.enabled then return true end
    if tune.throttleResponse ~= 0 or tune.topSpeed ~= 0 or tune.shiftSpeed ~= 0 or tune.regenBraking ~= 0 then return true end
    for key in pairs(SunsetTuning.HardwareSlots) do
        if (tune.hardware[key] or 0) > 0 then return true end
    end
    if tune.hardware.turbo or tune.hardware.launchControl then return true end
    return tune.handling.steering ~= 100 or tune.handling.brakePower ~= 100
        or tune.handling.suspension ~= 100 or tune.handling.traction ~= 100
end

function SunsetTuning.BuildVehicleInfo(raw)
    if type(raw) ~= 'table' or SunsetTuning.IsStockTune(raw) then
        return {
            tuned = false,
            stock = true,
            summary = 'Mapa ECU stock',
            chips = { 'STOCK' },
            lines = {
                { label = 'ECU', value = 'Factory map' },
            },
            tune = nil,
        }
    end

    local tune = SunsetTuning.SanitizeTune(raw)
    local stage = SunsetTuning.Stages[tune.stage] or SunsetTuning.Stages.civil
    local exhaust = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang

    local chips = { string.upper(tune.stage) }
    chips[#chips + 1] = exhaust.label:upper()
    if tune.pop.enabled then chips[#chips + 1] = 'POP&BANG' end
    if tune.flames.enabled then chips[#chips + 1] = 'FLAMES' end
    if tune.antiLag.enabled then chips[#chips + 1] = 'ANTI-LAG' end
    if tune.drift.enabled then chips[#chips + 1] = 'DRIFT' end
    if tune.hud.enabled then chips[#chips + 1] = 'HUD' end
    if tune.hardware.turbo then chips[#chips + 1] = 'TURBO' end
    if tune.hardware.engine > 0 then chips[#chips + 1] = 'ENGINE ' .. tune.hardware.engine end
    if tune.dyno.lastHp > 0 then chips[#chips + 1] = tune.dyno.lastHp .. ' HP' end

    local lines = {
        { label = 'STAGE', value = stage.label },
        { label = 'POWER', value = tune.power .. '%' },
        { label = 'TORQUE', value = tune.torque .. '%' },
        { label = 'EXHAUST', value = exhaust.label },
        { label = 'POP & BANG', value = tune.pop.enabled and 'On' or 'Off' },
        { label = 'FLAMES', value = tune.flames.enabled and 'On' or 'Off' },
        { label = 'FLAME COLOR', value = ('RGB %d/%d/%d'):format(tune.flames.color.r, tune.flames.color.g, tune.flames.color.b) },
        { label = 'RPM POP', value = tune.pop.rpmMax .. '%' },
        { label = 'ANTI-LAG', value = tune.antiLag.enabled and ('On (' .. tune.antiLag.intensity .. '%)') or 'Off' },
        { label = 'DRIFT', value = tune.drift.enabled and ('On · grip ' .. tune.drift.grip .. '%') or 'Off' },
        { label = 'ENGINE', value = ('Level %d/4'):format(tune.hardware.engine) },
        { label = 'TURBO', value = tune.hardware.turbo and 'Installed' or 'Stock' },
        { label = 'TRANSMISSION', value = ('Level %d/3'):format(tune.hardware.transmission) },
        { label = 'BRAKES', value = ('Level %d/3'):format(tune.hardware.brakes) },
        { label = 'SUSPENSION', value = ('Level %d/4'):format(tune.hardware.suspension) },
        { label = 'HUD ECU', value = tune.hud.enabled and 'On' or 'Off' },
    }

    if tune.dyno.lastHp > 0 then
        lines[#lines + 1] = {
            label = 'DYNO',
            value = tune.dyno.lastHp .. ' HP / ' .. tune.dyno.lastTorque .. ' Nm',
        }
    end

    return {
        tuned = true,
        stock = false,
        summary = stage.label .. ' · ' .. exhaust.label,
        chips = chips,
        lines = lines,
        tune = tune,
    }
end

local function sameRgb(a, b)
    a, b = type(a) == 'table' and a or {}, type(b) == 'table' and b or {}
    return tonumber(a.r) == tonumber(b.r) and tonumber(a.g) == tonumber(b.g) and tonumber(a.b) == tonumber(b.b)
end

-- Server-authoritative quote. Upgrades cost money; removing/rebalancing parts
-- Server-authoritative quote. Upgrades cost money; removing/rebalancing parts
-- only costs the workshop/flash fee, so a client cannot invent a cheap total.
function SunsetTuning.CalculateInstallCost(oldRaw, newRaw, oldCosmetics, newCosmetics, flash)
    local oldTune = SunsetTuning.SanitizeTune(oldRaw)
    local newTune = SunsetTuning.SanitizeTune(newRaw)
    local feature = SunsetTuning.FeatureCosts
    local partsCost = 0
    local hasChanges = false

    for key, slot in pairs(SunsetTuning.HardwareSlots) do
        local delta = math.max(0, (newTune.hardware[key] or 0) - (oldTune.hardware[key] or 0))
        if delta > 0 then
            partsCost = partsCost + delta * slot.unitCost
            hasChanges = true
        end
    end
    if newTune.hardware.turbo and not oldTune.hardware.turbo then partsCost = partsCost + feature.turbo hasChanges = true end
    if newTune.hardware.launchControl and not oldTune.hardware.launchControl then partsCost = partsCost + feature.launchControl hasChanges = true end
    if newTune.pop.enabled ~= oldTune.pop.enabled then
        if newTune.pop.enabled then partsCost = partsCost + feature.pop end
        hasChanges = true
    end
    if newTune.flames.enabled ~= oldTune.flames.enabled then
        if newTune.flames.enabled then partsCost = partsCost + feature.flames end
        hasChanges = true
    end
    if newTune.antiLag.enabled ~= oldTune.antiLag.enabled then
        if newTune.antiLag.enabled then partsCost = partsCost + feature.antiLag end
        hasChanges = true
    end
    if newTune.drift.enabled ~= oldTune.drift.enabled then
        if newTune.drift.enabled then partsCost = partsCost + feature.drift end
        hasChanges = true
    end
    if newTune.hud.enabled ~= oldTune.hud.enabled then
        if newTune.hud.enabled then partsCost = partsCost + feature.hud end
        hasChanges = true
    end
    if newTune.stage ~= oldTune.stage then
        partsCost = partsCost + (newTune.stage == 'race' and feature.raceMap or newTune.stage == 'sport' and feature.sportMap or 0)
        hasChanges = true
    end
    if newTune.exhaust ~= oldTune.exhaust then
        hasChanges = true
    end
    if (newTune.pop.rpmMax or 88) ~= (oldTune.pop.rpmMax or 88) then
        hasChanges = true
    end
    if newTune.antiLag.intensity ~= oldTune.antiLag.intensity or newTune.drift.grip ~= oldTune.drift.grip then
        hasChanges = true
    end
    if not sameRgb(newTune.flames.color, oldTune.flames.color) then
        hasChanges = true
    end
    local mapDelta = math.abs(newTune.power - oldTune.power) + math.abs(newTune.torque - oldTune.torque)
        + math.abs((newTune.throttleResponse or 50) - (oldTune.throttleResponse or 50))
        + math.abs((newTune.topSpeed or 0) - (oldTune.topSpeed or 0))
        + math.abs((newTune.shiftSpeed or 0) - (oldTune.shiftSpeed or 0))
        + math.abs((newTune.regenBraking or 0) - (oldTune.regenBraking or 0))
        + math.abs(newTune.handling.steering - oldTune.handling.steering)
        + math.abs(newTune.handling.brakePower - oldTune.handling.brakePower)
        + math.abs(newTune.handling.suspension - oldTune.handling.suspension)
        + math.abs(newTune.handling.traction - oldTune.handling.traction)
    if mapDelta > 0 then
        partsCost = partsCost + mapDelta * feature.customMapStep
        hasChanges = true
    end

    local oldCos = SunsetTuning.SanitizeCosmetics(oldCosmetics)
    local newCos = SunsetTuning.SanitizeCosmetics(newCosmetics)
    if not sameRgb(oldCos.primary, newCos.primary) or not sameRgb(oldCos.secondary, newCos.secondary)
        or oldCos.pearl ~= newCos.pearl or oldCos.wheel ~= newCos.wheel or oldCos.windowTint ~= newCos.windowTint
        or oldCos.paintType ~= newCos.paintType then
        partsCost = partsCost + feature.cosmetics
        hasChanges = true
    end
    if newCos.plateText ~= '' and newCos.plateText ~= oldCos.plateText then
        partsCost = partsCost + feature.vanityPlate
        hasChanges = true
    end

    -- Neons cost
    if newCos.neon and newCos.neon.enabled and not (oldCos.neon and oldCos.neon.enabled) then
        partsCost = partsCost + 500
        hasChanges = true
    elseif newCos.neon and newCos.neon.enabled and not sameRgb(oldCos.neon.color, newCos.neon.color) then
        partsCost = partsCost + 150
        hasChanges = true
    elseif newCos.neon and oldCos.neon and (newCos.neon.front ~= oldCos.neon.front or newCos.neon.back ~= oldCos.neon.back or newCos.neon.left ~= oldCos.neon.left or newCos.neon.right ~= oldCos.neon.right) then
        hasChanges = true
    end

    -- Xenon cost
    if newCos.xenon and not oldCos.xenon then
        partsCost = partsCost + 350
        hasChanges = true
    elseif newCos.xenon and newCos.xenonColor ~= oldCos.xenonColor then
        partsCost = partsCost + 100
        hasChanges = true
    end

    -- Wheels cost
    if newCos.wheelType ~= oldCos.wheelType or (newCos.mods and oldCos.mods and newCos.mods.wheels ~= oldCos.mods.wheels) then
        partsCost = partsCost + 400
        hasChanges = true
    end

    -- Tyre smoke cost
    if newCos.tyreSmoke and not oldCos.tyreSmoke then
        partsCost = partsCost + 300
        hasChanges = true
    elseif newCos.tyreSmoke and not sameRgb(oldCos.tyreSmokeColor, newCos.tyreSmokeColor) then
        partsCost = partsCost + 150
        hasChanges = true
    end

    -- Visual body mods cost
    if newCos.mods and oldCos.mods then
        for k, v in pairs(newCos.mods) do
            if k ~= 'wheels' and v ~= oldCos.mods[k] then
                partsCost = partsCost + 250
                hasChanges = true
            end
        end
    end

    if not hasChanges then
        return 0
    end

    local cost = partsCost + SunsetTuning.SaveBaseCost + (flash and SunsetTuning.FlashCost or 0)
    return math.max(0, math.floor(cost))
end

function SunsetTuning.DefaultCosmetics()
    return {
        primary = { r = 0, g = 0, b = 0 },
        secondary = { r = 111, g = 111, b = 111 },
        paintType = 0,
        pearl = 0,
        wheel = 0,
        plateText = '',
        windowTint = 0,
        xenon = false,
        xenonColor = 0,
        neon = {
            enabled = false,
            front = true,
            back = true,
            left = true,
            right = true,
            color = { r = 0, g = 150, b = 255 },
        },
        wheelType = 0,
        tyreSmoke = false,
        tyreSmokeColor = { r = 255, g = 255, b = 255 },
        mods = {
            spoiler = -1,
            frontBumper = -1,
            rearBumper = -1,
            sideSkirt = -1,
            exhaust = -1,
            rollCage = -1,
            grille = -1,
            hood = -1,
            leftFender = -1,
            rightFender = -1,
            roof = -1,
            wheels = -1,
            livery = -1,
        },
    }
end

function SunsetTuning.SanitizeCosmetics(raw)
    local def = SunsetTuning.DefaultCosmetics()
    if type(raw) ~= 'table' then return def end
    local function rgb(src, fallback)
        src = type(src) == 'table' and src or {}
        return {
            r = math.max(0, math.min(255, math.floor(tonumber(src.r) or fallback.r))),
            g = math.max(0, math.min(255, math.floor(tonumber(src.g) or fallback.g))),
            b = math.max(0, math.min(255, math.floor(tonumber(src.b) or fallback.b))),
        }
    end
    local plate = tostring(raw.plateText or ''):upper():gsub('[^A-Z0-9]', '')
    if #plate > 8 then plate = plate:sub(1, 8) end

    local rawNeon = type(raw.neon) == 'table' and raw.neon or {}
    local neon = {
        enabled = rawNeon.enabled == true,
        front = rawNeon.front ~= false,
        back = rawNeon.back ~= false,
        left = rawNeon.left ~= false,
        right = rawNeon.right ~= false,
        color = rgb(rawNeon.color, def.neon.color),
    }

    local rawMods = type(raw.mods) == 'table' and raw.mods or {}
    local mods = {
        spoiler = math.max(-1, math.min(100, math.floor(tonumber(rawMods.spoiler) or def.mods.spoiler))),
        frontBumper = math.max(-1, math.min(100, math.floor(tonumber(rawMods.frontBumper) or def.mods.frontBumper))),
        rearBumper = math.max(-1, math.min(100, math.floor(tonumber(rawMods.rearBumper) or def.mods.rearBumper))),
        sideSkirt = math.max(-1, math.min(100, math.floor(tonumber(rawMods.sideSkirt) or def.mods.sideSkirt))),
        exhaust = math.max(-1, math.min(100, math.floor(tonumber(rawMods.exhaust) or def.mods.exhaust))),
        rollCage = math.max(-1, math.min(100, math.floor(tonumber(rawMods.rollCage) or def.mods.rollCage))),
        grille = math.max(-1, math.min(100, math.floor(tonumber(rawMods.grille) or def.mods.grille))),
        hood = math.max(-1, math.min(100, math.floor(tonumber(rawMods.hood) or def.mods.hood))),
        leftFender = math.max(-1, math.min(100, math.floor(tonumber(rawMods.leftFender) or def.mods.leftFender))),
        rightFender = math.max(-1, math.min(100, math.floor(tonumber(rawMods.rightFender) or def.mods.rightFender))),
        roof = math.max(-1, math.min(100, math.floor(tonumber(rawMods.roof) or def.mods.roof))),
        wheels = math.max(-1, math.min(250, math.floor(tonumber(rawMods.wheels) or def.mods.wheels))),
        livery = math.max(-1, math.min(100, math.floor(tonumber(rawMods.livery) or def.mods.livery))),
    }

    return {
        primary = rgb(raw.primary, def.primary),
        secondary = rgb(raw.secondary, def.secondary),
        paintType = math.max(0, math.min(5, math.floor(tonumber(raw.paintType) or 0))),
        pearl = math.max(0, math.min(160, math.floor(tonumber(raw.pearl) or def.pearl))),
        wheel = math.max(0, math.min(160, math.floor(tonumber(raw.wheel) or def.wheel))),
        plateText = plate,
        windowTint = math.max(0, math.min(6, math.floor(tonumber(raw.windowTint) or def.windowTint))),
        xenon = raw.xenon == true,
        xenonColor = math.max(0, math.min(12, math.floor(tonumber(raw.xenonColor) or def.xenonColor))),
        neon = neon,
        wheelType = math.max(0, math.min(12, math.floor(tonumber(raw.wheelType) or def.wheelType))),
        tyreSmoke = raw.tyreSmoke == true,
        tyreSmokeColor = rgb(raw.tyreSmokeColor, def.tyreSmokeColor),
        mods = mods,
    }
end
