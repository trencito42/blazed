--- Low-level exhaust particle + sound layer.
--- References (GTA V built-in assets, no external resource required):
---   core / veh_backfire          — standard backfire pop (ak4y-hud, Advanced Nitro, most FiveM scripts)
---   veh_xs_vehicle_mods / veh_nitrous — nitro / flame burst at exhaust
---   core / ent_sht_flame         — short flame flash
---   core / exp_grd_bzgas_smoke   — diesel smoke puff
---   core / ent_amb_exhaust_thick — rolling coal style smoke
--- Sounds:
---   dlc_xs_vehicle_mods_sounds / backfire
---   DLC_Tuner_Car_Meet_Sounds / Backfire

local STC = SunsetTuningClient

STC.ExhaustPtfx = STC.ExhaustPtfx or {}

local EP = STC.ExhaustPtfx
EP.loaded = {}

local ASSETS = { 'core', 'veh_xs_vehicle_mods', 'scr_recartheft' }

local EXHAUST_BONES = { 'exhaust' }
for i = 2, 16 do EXHAUST_BONES[#EXHAUST_BONES + 1] = 'exhaust_' .. i end

function EP.ensureAssets()
    for _, asset in ipairs(ASSETS) do
        if not EP.loaded[asset] then
            RequestNamedPtfxAsset(asset)
        end
    end
    local deadline = GetGameTimer() + 10000
    while GetGameTimer() < deadline do
        local ready = true
        for _, asset in ipairs(ASSETS) do
            if not HasNamedPtfxAssetLoaded(asset) then
                ready = false
                break
            end
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

function EP.hasExhaustBones(veh)
    local found = false
    EP.eachExhaustBone(veh, function() found = true end)
    return found
end

--- Standard backfire pop — networked so other players see it.
function EP.backfire(veh, scale)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    EP.eachExhaustBone(veh, function(_, off)
        UseParticleFxAssetNextCall('core')
        StartNetworkedParticleFxNonLoopedOnEntity(
            'veh_backfire', veh, off.x, off.y, off.z,
            0.0, 0.0, 0.0, scale, false, false, false
        )
    end)
end

--- Nitro-style flame from XS vehicle mods DLC.
function EP.flames(veh, scale)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    EP.eachExhaustBone(veh, function(_, off, pos)
        if HasNamedPtfxAssetLoaded('veh_xs_vehicle_mods') then
            UseParticleFxAssetNextCall('veh_xs_vehicle_mods')
            StartNetworkedParticleFxNonLoopedOnEntity(
                'veh_nitrous', veh, off.x, off.y, off.z - 0.04,
                0.0, 0.0, 0.0, scale * 0.9, false, false, false
            )
        end
        UseParticleFxAssetNextCall('core')
        StartNetworkedParticleFxNonLoopedAtCoord(
            'ent_sht_flame', pos.x, pos.y, pos.z,
            0.0, 0.0, 0.0, scale * 0.75, false, false, false
        )
        if HasNamedPtfxAssetLoaded('scr_recartheft') then
            UseParticleFxAssetNextCall('scr_recartheft')
            StartNetworkedParticleFxNonLoopedAtCoord(
                'scr_wheel_burnout', pos.x, pos.y, pos.z - 0.1,
                0.0, 0.0, 0.0, scale * 0.45, false, false, false
            )
        end
    end)
end

function EP.smoke(veh, scale)
    if not EP.ensureAssets() then return end
    scale = scale or 1.0
    EP.eachExhaustBone(veh, function(_, off, pos)
        UseParticleFxAssetNextCall('core')
        StartNetworkedParticleFxNonLoopedOnEntity(
            'exp_grd_bzgas_smoke', veh, off.x, off.y - 0.08, off.z,
            0.0, 0.0, 0.0, scale, false, false, false
        )
        UseParticleFxAssetNextCall('core')
        StartNetworkedParticleFxNonLoopedAtCoord(
            'ent_amb_exhaust_thick', pos.x, pos.y, pos.z,
            0.0, 0.0, 0.0, scale * 0.65, false, false, false
        )
    end)
end

function EP.flashLight(veh, intensity, durationMs)
    intensity = intensity or 0.8
    durationMs = durationMs or 120
    CreateThread(function()
        local endAt = GetGameTimer() + durationMs
        while GetGameTimer() < endAt and DoesEntityExist(veh) do
            local c = GetEntityCoords(veh)
            DrawLightWithRange(c.x, c.y, c.z - 0.5, 255, 140, 40, 5.0, 12.0 * intensity)
            Wait(0)
        end
    end)
end

function EP.playBackfireSound(veh, loud)
    if not veh or veh == 0 then return end
    local sid = GetSoundId()
    PlaySoundFromEntity(sid, 'backfire', veh, 'dlc_xs_vehicle_mods_sounds', false, 0)
    ReleaseSoundId(sid)
    if loud then
        local sid2 = GetSoundId()
        PlaySoundFromEntity(sid2, 'Backfire', veh, 'DLC_Tuner_Car_Meet_Sounds', false, 0)
        ReleaseSoundId(sid2)
    end
end

function EP.burst(veh, kind, intensity)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    intensity = math.max(0.35, math.min(1.4, tonumber(intensity) or 0.85))
    kind = kind or 'pop'

    if kind == 'pop' or kind == 'antilag' or kind == 'twostep' then
        EP.backfire(veh, 0.9 + intensity * 0.5)
        EP.playBackfireSound(veh, intensity > 0.7)
    end
    if kind == 'flame' or kind == 'extra' or kind == 'antilag' then
        EP.flames(veh, 0.75 + intensity * 0.55)
        EP.flashLight(veh, intensity, 100)
    end
    if kind == 'diesel' or kind == 'smoke' then
        EP.smoke(veh, 0.85 + intensity * 0.4)
        EP.playBackfireSound(veh, false)
    end
    if kind == 'flash' then
        EP.backfire(veh, 1.2)
        EP.flames(veh, 1.0)
        EP.flashLight(veh, 1.0, 180)
        EP.playBackfireSound(veh, true)
    end
end
