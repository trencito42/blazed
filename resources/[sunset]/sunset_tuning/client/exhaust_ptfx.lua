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

CreateThread(function() EP.ensureAssets() end)

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
    StartNetworkedParticleFxNonLoopedOnEntityBone(
        effect, veh,
        0.0, yPush or -0.12, 0.0,
        0.0, 0.0, 0.0,
        bone, scale, false, false, false
    )
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
        onExhaustBone(veh, bone, scale, 'core', 'veh_backfire', color, -0.1)
        EP.flashAtCoord(pos, color or DEFAULT_FLAME, scale * 0.5, 60)
    end)
end

function EP.flames(veh, scale, color)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    color = color or DEFAULT_FLAME
    EP.eachExhaustBone(veh, function(bone, _, pos)
        onExhaustBone(veh, bone, scale * 0.95, 'core', 'veh_backfire', color, -0.14)
        if HasNamedPtfxAssetLoaded('veh_xs_vehicle_mods') then
            onExhaustBone(veh, bone, scale * 0.75, 'veh_xs_vehicle_mods', 'veh_nitrous', color, -0.16)
        end
        EP.flashAtCoord(pos, color, scale * 0.55, 70)
    end)
end

function EP.smoke(veh, scale)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    EP.eachExhaustBone(veh, function(bone)
        onExhaustBone(veh, bone, scale, 'core', 'exp_grd_bzgas_smoke', nil, -0.14)
    end)
end

function EP.playBackfireSound(veh, loud)
    if not veh or veh == 0 then return end
    local sid = GetSoundId()
    PlaySoundFromEntity(sid, 'Backfire', veh, 'DLC_Tuner_Car_Meet_Sounds', false, 0)
    ReleaseSoundId(sid)
    local sid2 = GetSoundId()
    PlaySoundFromEntity(sid2, 'backfire', veh, 'dlc_xs_vehicle_mods_sounds', false, 0)
    ReleaseSoundId(sid2)
    if loud then
        local sid3 = GetSoundId()
        PlaySoundFromEntity(sid3, 'Crackle', veh, 'DLC_Tuner_Car_Meet_Sounds', false, 0)
        ReleaseSoundId(sid3)
    end
end

function EP.burst(veh, kind, intensity, flameColor)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    intensity = math.max(0.35, math.min(1.4, tonumber(intensity) or 0.85))
    kind = kind or 'pop'
    local color = flameColor or DEFAULT_FLAME

    if kind == 'pop' or kind == 'twostep' then
        EP.backfire(veh, 0.9 + intensity * 0.5, color)
        EP.playBackfireSound(veh, intensity > 0.65 or kind == 'twostep')
    end
    if kind == 'antilag' then
        EP.backfire(veh, 0.65 + intensity * 0.35, color)
        EP.playBackfireSound(veh, false)
    end
    if kind == 'flame' or kind == 'extra' then
        EP.flames(veh, 0.75 + intensity * 0.55, color)
    end
    if kind == 'diesel' or kind == 'smoke' then
        EP.smoke(veh, 0.85 + intensity * 0.4)
    end
    if kind == 'flash' then
        EP.backfire(veh, 1.2, color)
        EP.flames(veh, 1.0, color)
        EP.playBackfireSound(veh, true)
    end
end
