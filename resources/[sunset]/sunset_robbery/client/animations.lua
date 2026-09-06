RobberyAnims = {}

local bagObj = nil

local function loadDict(dict)
    if not dict or HasAnimDictLoaded(dict) then return dict and HasAnimDictLoaded(dict) end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

function RobberyAnims.play(name, duration)
    local spec = SunsetRobbery.Animations[name]
    if not spec then return end
    local ped = PlayerPedId()
    if loadDict(spec.dict) then
        TaskPlayAnim(ped, spec.dict, spec.clip, 4.0, 4.0, duration or 1800, spec.flag or 0, 0.0, false, false, false)
    end
end

function RobberyAnims.stop()
    ClearPedTasks(PlayerPedId())
end

function RobberyAnims.sound(key)
    local snd = SunsetRobbery.Sounds[key]
    if snd then
        PlaySoundFrontend(-1, snd.name, snd.set, true)
    end
end

function RobberyAnims.attachBag()
    RobberyAnims.detachBag()
    local spec = SunsetRobbery.BagProp
    local model = spec.model
    RequestModel(model)
    local deadline = GetGameTimer() + 4000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(model) then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    bagObj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(bagObj, ped, GetPedBoneIndex(ped, spec.bone), spec.pos.x, spec.pos.y, spec.pos.z, spec.rot.x, spec.rot.y, spec.rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

function RobberyAnims.detachBag()
    if bagObj and DoesEntityExist(bagObj) then
        DeleteEntity(bagObj)
    end
    bagObj = nil
end

function RobberyAnims.shake(intensity)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', intensity or 0.08)
end

function RobberyAnims.glassFx(coords)
    RequestNamedPtfxAsset('core')
    local deadline = GetGameTimer() + 1500
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < deadline do Wait(0) end
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_dst_glass', coords.x, coords.y, coords.z + 0.35, 0.0, 0.0, 0.0, 0.7, false, false, false)
end
