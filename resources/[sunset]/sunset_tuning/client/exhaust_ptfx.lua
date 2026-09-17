--- Low-level exhaust particle + sound layer (entity-bone attached only — no ground spawns).

local STC = SunsetTuningClient
STC.ExhaustPtfx = STC.ExhaustPtfx or {}
local EP = STC.ExhaustPtfx
EP.loaded = {}

local ASSETS = { 'core', 'veh_xs_vehicle_mods' }
local EXHAUST_BONES = { 'exhaust' }
for i = 2, 16 do EXHAUST_BONES[#EXHAUST_BONES + 1] = 'exhaust_' .. i end

local DEFAULT_FLAME = { r = 255, g = 120, b = 40 }

function EP.normalizeColor(color)
    if type(color) ~= 'table' then return DEFAULT_FLAME end
    return {
        r = math.max(0, math.min(255, math.floor(tonumber(color.r) or DEFAULT_FLAME.r))),
        g = math.max(0, math.min(255, math.floor(tonumber(color.g) or DEFAULT_FLAME.g))),
        b = math.max(0, math.min(255, math.floor(tonumber(color.b) or DEFAULT_FLAME.b))),
    }
end

function EP.ensureAssets()
    for _, asset in ipairs(ASSETS) do
        if not EP.loaded[asset] then RequestNamedPtfxAsset(asset) end
    end
    local deadline = GetGameTimer() + 10000
    while GetGameTimer() < deadline do
        local ready = true
        for _, asset in ipairs(ASSETS) do
            if not HasNamedPtfxAssetLoaded(asset) then ready = false break end
        end
        if ready then
            for _, asset in ipairs(ASSETS) do EP.loaded[asset] = true end
            return true
        end
        Wait(10)
    end
    EP.loaded.core = HasNamedPtfxAssetLoaded('core')
    return EP.loaded.core == true
end

CreateThread(function()
    EP.ensureAssets()
    RequestScriptAudioBank('DLC_TUNER_CAR_MEET', false)
    RequestScriptAudioBank('DLC_XS_VEHICLE_MODS', false)
end)

function EP.eachExhaustBone(veh, fn)
    if not veh or veh == 0 then return end
    for _, name in ipairs(EXHAUST_BONES) do
        local bone = GetEntityBoneIndexByName(veh, name)
        if bone ~= -1 then
            local pos = GetWorldPositionOfEntityBone(veh, bone)
            local off = GetOffsetFromEntityGivenWorldCoords(veh, pos.x, pos.y, pos.z)
            fn(bone, off, pos)
        end
    end
end

local function ptfxColor(color)
    local c = EP.normalizeColor(color)
    SetParticleFxNonLoopedColour(c.r / 255.0, c.g / 255.0, c.b / 255.0)
end

--- Spawn PTFX on exhaust bone, pushed slightly out of the pipe (local -Y).
local function onExhaustBone(veh, bone, off, scale, asset, effect, color, yPush)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end

    -- Normalize arguments to support both (veh, bone, off, ...) and (veh, bone, scale, ...)
    if type(off) == 'number' then
        yPush = color
        color = effect
        effect = asset
        asset = scale
        scale = off
        off = nil
    end

    if not off and bone and bone ~= -1 then
        local pos = GetWorldPositionOfEntityBone(veh, bone)
        off = GetOffsetFromEntityGivenWorldCoords(veh, pos.x, pos.y, pos.z)
    end

    UseParticleFxAssetNextCall(asset)
    if color then ptfxColor(color) end

    local push = tonumber(yPush) or -0.12
    scale = tonumber(scale) or 1.0

    if off then
        StartParticleFxNonLoopedOnEntity(
            effect, veh,
            off.x, off.y + push, off.z,
            0.0, 0.0, 0.0,
            scale, false, false, false
        )
    else
        StartParticleFxNonLoopedOnEntity(
            effect, veh,
            0.0, -2.0 + push, 0.0,
            0.0, 0.0, 0.0,
            scale, false, false, false
        )
    end
end

-- GTA's stock backfire texture retains a baked orange core. This very short
-- tintable pulse makes the selected flame colour visible without looking like
-- a continuous nitrous jet.
local function tintedFlamePulse(veh, bone, scale, color, durationMs)
    if not HasNamedPtfxAssetLoaded('veh_xs_vehicle_mods') then return end
    local c = EP.normalizeColor(color)
    UseParticleFxAssetNextCall('veh_xs_vehicle_mods')
    local handle = StartParticleFxLoopedOnEntityBone(
        'veh_nitrous', veh,
        0.0, -0.18, 0.0,
        0.0, 0.0, 0.0,
        bone, scale, false, false, false
    )
    if not handle or handle == 0 then return end
    SetParticleFxLoopedColour(handle, c.r / 255.0, c.g / 255.0, c.b / 255.0, false)
    SetParticleFxLoopedAlpha(handle, 0.92)
    SetTimeout(durationMs or 75, function()
        StopParticleFxLooped(handle, false)
    end)
end

function EP.sparks(veh, scale, color)
    if not EP.ensureAssets() then return end
    scale = scale or 0.45
    EP.eachExhaustBone(veh, function(bone, off, pos)
        onExhaustBone(veh, bone, off, scale, 'core', 'ent_sht_metal', color, -0.16)
        EP.flashAtCoord(pos, color or DEFAULT_FLAME, scale * 0.35, 45)
    end)
end

function EP.flashAtCoord(pos, color, intensity, durationMs)
    if not pos then return end
    local c = EP.normalizeColor(color)
    intensity = intensity or 0.8
    durationMs = durationMs or 100
    CreateThread(function()
        local endAt = GetGameTimer() + durationMs
        while GetGameTimer() < endAt do
            DrawLightWithRange(pos.x, pos.y, pos.z, c.r, c.g, c.b, 2.5, 8.0 * intensity)
            Wait(0)
        end
    end)
end

function EP.backfire(veh, scale, color)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    EP.eachExhaustBone(veh, function(bone, off, pos)
        onExhaustBone(veh, bone, off, scale * 0.82, 'core', 'veh_sm_car_small_backfire', color, -0.12)
        onExhaustBone(veh, bone, off, scale, 'core', 'veh_backfire', color, -0.1)
        tintedFlamePulse(veh, bone, scale * 0.34, color or DEFAULT_FLAME, 55)
        EP.flashAtCoord(pos, color or DEFAULT_FLAME, scale * 0.65, 65)
    end)
end

function EP.flames(veh, scale, color)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    color = color or DEFAULT_FLAME
    EP.eachExhaustBone(veh, function(bone, off, pos)
        onExhaustBone(veh, bone, off, scale * 1.18, 'core', 'veh_backfire', color, -0.16)
        tintedFlamePulse(veh, bone, scale * 0.58, color, 85)
        EP.flashAtCoord(pos, color, scale * 0.8, 90)
    end)
end

function EP.smoke(veh, scale)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    EP.eachExhaustBone(veh, function(bone, off)
        onExhaustBone(veh, bone, off, scale, 'core', 'exp_grd_bzgas_smoke', nil, -0.14)
    end)
end

-- Stable vehicle sound families mapped by entity model hash.
-- Avoids random vehicle model switching every 80ms and ensures coherent 3D audio.
local SOUND_FAMILIES = {
    zr350 = { crackle = 'zr350_exhaust_pops', bang = 'zr350_exhaust_pops_upgraded', limiter = 'zr350_exhaust_pops_upgraded' },
    calico = { crackle = 'calico_exhaust_pops', bang = 'calico_exhaust_pops_upgrade', limiter = 'calico_exhaust_pops_upgrade' },
    comet6 = { crackle = 'comet6_exhaust_pops', bang = 'comet6_exhaust_pops_upgrade', limiter = 'comet6_exhaust_pops_upgrade' },
    cypher = { crackle = 'cypher_exhaust_pops', bang = 'cypher_exhaust_pops_upgraded', limiter = 'cypher_limiter_pops' },
    futo2 = { crackle = 'futo2_exhaust_pops', bang = 'calico_exhaust_pops_upgrade', limiter = 'tuner_hatch02_limiter_pops' },
    jester4 = { crackle = 'jester4_exhaust_pops', bang = 'jester4_exhaust_pops_upgrade', limiter = 'jester4_exhaust_pops_upgrade' },
    remus = { crackle = 'remus_exhaust_pops', bang = 'remus_exhaust_pops_upgraded', limiter = 'remus_limiter_pops' },
    rt3000 = { crackle = 'rt3000_exhaust_pops', bang = 'rt3000_exhaust_pops_upgrade', limiter = 'rt3000_upgraded_limiter_pops' },
    tailgater2 = { crackle = 'tailgater2_exhaust_pops', bang = 'tailgater2_exhaust_pops_upgraded', limiter = 'tailgater2_limiter_pops' },
    vectre = { crackle = 'vectre_exhaust_pops', bang = 'vectre_exhaust_pops_upgrade', limiter = 'vectre_limiter_pops' },
    tuner_muscle = { crackle = 'tuner_muscle01_exhaust_pops', bang = 'dominator7_exhaust_pops_upgrade', limiter = 'tuner_muscle01_limiter_pops' },
    tuner_hatch = { crackle = 'tuner_hatch02_exhaust_pops', bang = 'tuner_hatch03_exhaust_pops_upgrade', limiter = 'tuner_hatch02_limiter_pops' },
}

local FAMILY_KEYS = { 'zr350', 'calico', 'comet6', 'cypher', 'futo2', 'jester4', 'remus', 'rt3000', 'tailgater2', 'vectre', 'tuner_muscle', 'tuner_hatch' }

local function getVehicleSoundFamily(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return SOUND_FAMILIES.calico end
    local model = GetEntityModel(veh)
    local idx = (math.abs(model) % #FAMILY_KEYS) + 1
    local key = FAMILY_KEYS[idx] or 'calico'
    return SOUND_FAMILIES[key] or SOUND_FAMILIES.calico
end

local function playSoundLayer(veh, soundName)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    pcall(function()
        local sid = GetSoundId()
        PlaySoundFromEntity(sid, soundName, veh, 'DLC_TUNER_CAR_MEET_SOUNDS', false, 0)
        SetTimeout(800, function() ReleaseSoundId(sid) end)
    end)
end

function EP.playBackfireSound(veh, kind, intensity)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local fam = getVehicleSoundFamily(veh)
    local sName = (kind == 'bang' or kind == 'gearshift') and fam.bang
        or (kind == 'limiter' or kind == 'twostep' or kind == 'antilag') and fam.limiter
        or fam.crackle
    playSoundLayer(veh, sName)
end

--- Unified burst dispatcher.
-- Pure exhaust backfire and flame: DOES NOT trigger SetVehicleNitroEnabled (nitrous is managed independently).
function EP.burst(veh, kind, intensity, flameColor, withFlames)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    intensity = math.max(0.25, math.min(1.5, tonumber(intensity) or 0.75))
    kind = kind or 'crackle'
    local color = flameColor or DEFAULT_FLAME

    if kind == 'crackle' then
        EP.backfire(veh, 0.65 + intensity * 0.40, color)
        if withFlames and intensity > 0.6 then
            tintedFlamePulse(veh, nil, 0.30 + intensity * 0.20, color, 40)
        end
        EP.playBackfireSound(veh, 'crackle', intensity)
    elseif kind == 'bang' or kind == 'pop' then
        EP.backfire(veh, 0.95 + intensity * 0.65, color)
        if intensity > 0.75 then EP.sparks(veh, 0.25 + intensity * 0.20, color) end
        if withFlames then
            tintedFlamePulse(veh, nil, 0.45 + intensity * 0.25, color, 65)
        end
        EP.playBackfireSound(veh, 'bang', intensity)
    elseif kind == 'gearshift' then
        EP.backfire(veh, 0.90 + intensity * 0.50, color)
        if withFlames then
            tintedFlamePulse(veh, nil, 0.40 + intensity * 0.20, color, 50)
        end
        EP.playBackfireSound(veh, 'gearshift', intensity)
    elseif kind == 'twostep' then
        EP.backfire(veh, 1.0 + intensity * 0.60, color)
        EP.sparks(veh, 0.35 + intensity * 0.25, color)
        if withFlames then
            tintedFlamePulse(veh, nil, 0.50 + intensity * 0.25, color, 55)
        end
        EP.playBackfireSound(veh, 'twostep', intensity)
    elseif kind == 'antilag' then
        EP.backfire(veh, 0.85 + intensity * 0.45, color)
        if intensity > 0.65 then EP.sparks(veh, 0.25 + intensity * 0.20, color) end
        EP.playBackfireSound(veh, 'antilag', intensity)
    elseif kind == 'flame' or kind == 'extra' then
        EP.flames(veh, 0.75 + intensity * 0.55, color)
        EP.playBackfireSound(veh, 'crackle', intensity)
    elseif kind == 'diesel' or kind == 'smoke' then
        EP.smoke(veh, 0.80 + intensity * 0.40)
    elseif kind == 'flash' then
        EP.backfire(veh, 1.45, color)
        EP.flames(veh, 1.25, color)
        EP.sparks(veh, 0.5, color)
        EP.playBackfireSound(veh, 'bang', 1.0)
    end
end
