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
local function onExhaustBone(veh, bone, scale, asset, effect, color, yPush)
    UseParticleFxAssetNextCall(asset)
    if color then ptfxColor(color) end
    -- The resource performs its own server-validated nearby sync. Keeping the
    -- particle local prevents the origin player from seeing the same burst twice.
    StartParticleFxNonLoopedOnEntityBone(
        effect, veh,
        0.0, yPush or -0.12, 0.0,
        0.0, 0.0, 0.0,
        bone, scale, false, false, false
    )
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
    EP.eachExhaustBone(veh, function(bone, _, pos)
        onExhaustBone(veh, bone, scale, 'core', 'ent_sht_metal', color, -0.16)
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
    EP.eachExhaustBone(veh, function(bone, _, pos)
        onExhaustBone(veh, bone, scale * 0.82, 'core', 'veh_sm_car_small_backfire', color, -0.12)
        onExhaustBone(veh, bone, scale, 'core', 'veh_backfire', color, -0.1)
        tintedFlamePulse(veh, bone, scale * 0.34, color or DEFAULT_FLAME, 55)
        EP.flashAtCoord(pos, color or DEFAULT_FLAME, scale * 0.65, 65)
    end)
end

function EP.flames(veh, scale, color)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    color = color or DEFAULT_FLAME
    EP.eachExhaustBone(veh, function(bone, _, pos)
        onExhaustBone(veh, bone, scale * 1.18, 'core', 'veh_backfire', color, -0.16)
        tintedFlamePulse(veh, bone, scale * 0.58, color, 85)
        EP.flashAtCoord(pos, color, scale * 0.8, 90)
    end)
end

function EP.smoke(veh, scale)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    EP.eachExhaustBone(veh, function(bone)
        onExhaustBone(veh, bone, scale, 'core', 'exp_grd_bzgas_smoke', nil, -0.14)
    end)
end

-- Actual Los Santos Tuners tailpipe events. The former generic names were
-- mostly air/FX samples, which is why the result sounded like a hiss.
local CRACKLE_SOUNDS = {
    'zr350_exhaust_pops', 'calico_exhaust_pops', 'comet6_exhaust_pops',
    'cypher_exhaust_pops', 'futo2_exhaust_pops', 'jester4_exhaust_pops',
    'remus_exhaust_pops', 'rt3000_exhaust_pops', 'tailgater2_exhaust_pops',
    'tuner_hatch02_exhaust_pops', 'tuner_hatch04_exhaust_pops',
    'tuner_muscle01_exhaust_pops', 'vectre_exhaust_pops',
}

local BANG_SOUNDS = {
    'calico_exhaust_pops_upgrade', 'comet6_exhaust_pops_upgrade',
    'cypher_exhaust_pops_upgraded', 'dominator7_exhaust_pops_upgrade',
    'jester4_exhaust_pops_upgrade', 'remus_exhaust_pops_upgraded',
    'rt3000_exhaust_pops_upgrade', 'tailgater2_exhaust_pops_upgraded',
    'tuner_hatch03_exhaust_pops_upgrade', 'vectre_exhaust_pops_upgrade',
    'zr350_exhaust_pops_upgraded',
}

local LIMITER_SOUNDS = {
    'cypher_limiter_pops', 'remus_limiter_pops', 'tailgater2_limiter_pops',
    'tuner_hatch02_limiter_pops', 'tuner_hatch04_limiter_pops',
    'tuner_muscle01_limiter_pops', 'vectre_limiter_pops',
    'warrener2_limiter_pops', 'rt3000_upgraded_limiter_pops',
}

local function playSoundLayer(veh, soundName)
    if not veh or veh == 0 then return end
    local sid = GetSoundId()
    PlaySoundFromEntity(sid, soundName, veh, 0, false, 0)
    SetTimeout(900, function() ReleaseSoundId(sid) end)
end

function EP.playBackfireSound(veh, profile)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local pool = profile == 'limiter' and LIMITER_SOUNDS or profile == 'bang' and BANG_SOUNDS or CRACKLE_SOUNDS
    playSoundLayer(veh, pool[math.random(1, #pool)])
end

function EP.burst(veh, kind, intensity, flameColor)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    intensity = math.max(0.35, math.min(1.4, tonumber(intensity) or 0.85))
    kind = kind or 'pop'
    local color = flameColor or DEFAULT_FLAME

    if kind == 'pop' or kind == 'twostep' then
        EP.backfire(veh, 1.1 + intensity * 0.72, color)
        if kind == 'twostep' or intensity > 0.9 then EP.sparks(veh, 0.3 + intensity * 0.2, color) end
        EP.playBackfireSound(veh, kind == 'twostep' and 'limiter' or (intensity > 0.82 and 'bang' or 'crackle'))
    end
    if kind == 'antilag' then
        EP.backfire(veh, 0.95 + intensity * 0.58, color)
        if intensity > 0.75 then EP.sparks(veh, 0.28 + intensity * 0.18, color) end
        EP.playBackfireSound(veh, 'limiter')
    end
    if kind == 'flame' or kind == 'extra' then
        EP.flames(veh, 0.75 + intensity * 0.55, color)
    end
    if kind == 'diesel' or kind == 'smoke' then
        EP.smoke(veh, 0.85 + intensity * 0.4)
    end
    if kind == 'flash' then
        EP.backfire(veh, 1.65, color)
        EP.flames(veh, 1.45, color)
        EP.playBackfireSound(veh, 'bang')
    end
end
