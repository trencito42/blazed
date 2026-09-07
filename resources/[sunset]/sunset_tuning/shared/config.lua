SunsetTuning = SunsetTuning or {}

SunsetTuning.InteractRadius = 6.0
SunsetTuning.SaveBaseCost = 750
SunsetTuning.DynoCost = 250
SunsetTuning.FlashCost = 150

SunsetTuning.Stages = {
    civil = { label = 'Silent (Civil)', power = 0.98, torque = 0.98, grip = 1.02, popIntensity = 0.35 },
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
        dyno = vector4(-336.15, -142.85, 39.01, 250.0),
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

function SunsetTuning.DefaultTune()
    return {
        stage = 'sport',
        power = 100,
        torque = 100,
        exhaust = 'pop_bang',
        pop = {
            enabled = true,
            rpmMax = 92,
            durationMs = 100,
            secondBurst = true,
            burstStage = 'sport',
        },
        antiLag = { enabled = false, intensity = 55 },
        drift = { enabled = false, grip = 45 },
        hud = { enabled = true },
        dyno = { lastHp = 0, lastTorque = 0, lastRunAt = 0 },
    }
end

function SunsetTuning.SanitizeTune(raw)
    local def = SunsetTuning.DefaultTune()
    if type(raw) ~= 'table' then return def end

    local stage = tostring(raw.stage or def.stage)
    if not SunsetTuning.Stages[stage] then stage = 'sport' end

    local exhaust = tostring(raw.exhaust or def.exhaust)
    if not SunsetTuning.ExhaustModes[exhaust] then exhaust = 'pop_bang' end

    local pop = type(raw.pop) == 'table' and raw.pop or {}
    local antiLag = type(raw.antiLag) == 'table' and raw.antiLag or {}
    local drift = type(raw.drift) == 'table' and raw.drift or {}
    local hud = type(raw.hud) == 'table' and raw.hud or {}
    local dyno = type(raw.dyno) == 'table' and raw.dyno or {}

    return {
        stage = stage,
        power = math.max(85, math.min(120, math.floor(tonumber(raw.power) or def.power))),
        torque = math.max(85, math.min(120, math.floor(tonumber(raw.torque) or def.torque))),
        exhaust = exhaust,
        pop = {
            enabled = pop.enabled ~= false,
            rpmMax = math.max(70, math.min(100, math.floor(tonumber(pop.rpmMax) or def.pop.rpmMax))),
            durationMs = math.max(40, math.min(250, math.floor(tonumber(pop.durationMs) or def.pop.durationMs))),
            secondBurst = pop.secondBurst ~= false,
            burstStage = SunsetTuning.Stages[tostring(pop.burstStage or stage)] and tostring(pop.burstStage or stage) or stage,
        },
        antiLag = {
            enabled = antiLag.enabled == true,
            intensity = math.max(0, math.min(100, math.floor(tonumber(antiLag.intensity) or def.antiLag.intensity))),
        },
        drift = {
            enabled = drift.enabled == true,
            grip = math.max(20, math.min(80, math.floor(tonumber(drift.grip) or def.drift.grip))),
        },
        hud = { enabled = hud.enabled ~= false },
        dyno = {
            lastHp = math.max(0, math.floor(tonumber(dyno.lastHp) or 0)),
            lastTorque = math.max(0, math.floor(tonumber(dyno.lastTorque) or 0)),
            lastRunAt = math.max(0, math.floor(tonumber(dyno.lastRunAt) or 0)),
        },
    }
end

function SunsetTuning.BuildVehicleInfo(raw)
    if type(raw) ~= 'table' then
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
    local stage = SunsetTuning.Stages[tune.stage] or SunsetTuning.Stages.sport
    local exhaust = SunsetTuning.ExhaustModes[tune.exhaust] or SunsetTuning.ExhaustModes.pop_bang

    local chips = { string.upper(tune.stage) }
    chips[#chips + 1] = exhaust.label:upper()
    if tune.pop.enabled then chips[#chips + 1] = 'POP&BANG' end
    if tune.antiLag.enabled then chips[#chips + 1] = 'ANTI-LAG' end
    if tune.drift.enabled then chips[#chips + 1] = 'DRIFT' end
    if tune.hud.enabled then chips[#chips + 1] = 'HUD' end
    if tune.dyno.lastHp > 0 then chips[#chips + 1] = tune.dyno.lastHp .. ' CP' end

    local lines = {
        { label = 'STAGE', value = stage.label },
        { label = 'PUTERE', value = tune.power .. '%' },
        { label = 'CUPLU', value = tune.torque .. '%' },
        { label = 'EVACUARE', value = exhaust.label },
        { label = 'POP & BANG', value = tune.pop.enabled and 'Activ' or 'Oprit' },
        { label = 'RPM POP', value = tune.pop.rpmMax .. '%' },
        { label = 'ANTI-LAG', value = tune.antiLag.enabled and ('Activ (' .. tune.antiLag.intensity .. '%)') or 'Oprit' },
        { label = 'DRIFT', value = tune.drift.enabled and ('Activ · grip ' .. tune.drift.grip .. '%') or 'Oprit' },
        { label = 'HUD ECU', value = tune.hud.enabled and 'Activ' or 'Oprit' },
    }

    if tune.dyno.lastHp > 0 then
        lines[#lines + 1] = {
            label = 'DYNO',
            value = tune.dyno.lastHp .. ' CP / ' .. tune.dyno.lastTorque .. ' Nm',
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
