local equippedPropEntity = nil
local equippedPropItem = nil
local equippedPropModel = nil

local function getEquipDef(itemName)
    local def = Sunset.Items[itemName]
    if not def or not def.equipProp then return nil end
    local ep = def.equipProp
    if type(ep) == 'string' then
        return { model = ep }
    end
    return ep
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function playEquipAnim(ped, anim)
    if not anim or not anim.dict then return end
    RequestAnimDict(anim.dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    if not HasAnimDictLoaded(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.name or 'idle_a', 2.0, -2.0, -1, anim.flag or 49, 0, false, false, false)
end

local function clearEquipAnim(ped)
    local def = equippedPropItem and getEquipDef(equippedPropItem)
    if def and def.anim and def.anim.dict then
        StopAnimTask(ped, def.anim.dict, def.anim.name or 'idle_a', 1.0)
        return
    end
    ClearPedSecondaryTask(ped)
end

local function destroyPropEntity()
    if equippedPropEntity and DoesEntityExist(equippedPropEntity) then
        DeleteEntity(equippedPropEntity)
    end
    equippedPropEntity = nil
    equippedPropModel = nil
end

local function holsterHotbarProp()
    local ped = PlayerPedId()
    destroyPropEntity()
    clearEquipAnim(ped)
    equippedPropItem = nil
    return true
end

local function equipHotbarProp(itemName)
    local ep = getEquipDef(itemName)
    if not ep or not ep.model then return false end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return false end

    holsterHotbarProp()
    exports.sunset_inventory:HolsterHotbarWeapon()

    local hash = loadModel(ep.model)
    if not hash then return false end

    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    if not obj or obj == 0 then return false end

    local bone = ep.bone or 57005
    local pos = ep.pos or vector3(0.12, 0.02, -0.02)
    local rot = ep.rot or vector3(80.0, 120.0, 160.0)

    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, bone),
        pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)

    equippedPropEntity = obj
    equippedPropModel = ep.model
    equippedPropItem = itemName

    if ep.anim then
        playEquipAnim(ped, ep.anim)
    end

    return true
end

local function getHotbarPropEntity(model)
    if not equippedPropEntity or not DoesEntityExist(equippedPropEntity) then
        return nil
    end
    if not model then return equippedPropEntity end
    local wanted = type(model) == 'string' and model or nil
    if wanted and equippedPropModel ~= wanted and equippedPropModel ~= joaat(wanted) then
        return nil
    end
    return equippedPropEntity
end

local function isHotbarPropEntity(entity)
    return entity and equippedPropEntity == entity
end

exports('EquipHotbarProp', equipHotbarProp)
exports('HolsterHotbarProp', holsterHotbarProp)
exports('GetHotbarEquippedPropItem', function() return equippedPropItem end)
exports('GetHotbarPropEntity', getHotbarPropEntity)
exports('IsHotbarPropEntity', isHotbarPropEntity)

CreateThread(function()
    while true do
        if equippedPropItem then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) or IsEntityDead(ped) then
                holsterHotbarProp()
                Wait(500)
            else
                local def = getEquipDef(equippedPropItem)
                if def and def.anim and not IsEntityPlayingAnim(ped, def.anim.dict, def.anim.name or 'idle_a', 3) then
                    playEquipAnim(ped, def.anim)
                end
                Wait(1200)
            end
        else
            Wait(1000)
        end
    end
end)
