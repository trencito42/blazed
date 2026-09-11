SunsetWorld = SunsetWorld or {}
SunsetWorld.Npc = SunsetWorld.Npc or {}

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(0)
    end
    return hash
end

function SunsetWorld.Npc.spawn(config)
    config = config or {}
    local pos = config.coords
    if not pos then return nil end

    local hash = loadModel(config.model or 'mp_m_shopkeep_01')
    if not hash then return nil end

    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z - 1.0, pos.w or 0.0, false, true)
    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    TaskStartScenarioInPlace(ped, config.scenario or 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    if config.components then
        for _, row in ipairs(config.components) do
            SetPedComponentVariation(ped, row[1], row[2], row[3] or 0, 0)
        end
    end
    if config.props then
        for _, row in ipairs(config.props) do
            if row[2] and row[2] >= 0 then
                SetPedPropIndex(ped, row[1], row[2], row[3] or 0, true)
            else
                ClearPedProp(ped, row[1])
            end
        end
    end

    SetModelAsNoLongerNeeded(hash)
    return ped
end

function SunsetWorld.Npc.showTooltip(id, ped, meta)
    if GetResourceState('sunset_world') ~= 'started' or not SunsetWorld.Tooltips then return end
    local coords = SunsetWorld.Tooltips.coordsFromEntity(ped, meta.offsetZ or 0.42)
    if not coords then return end
    SunsetWorld.Tooltips.set(id, {
        coords = coords,
        badge = meta.badge or '',
        badgeClass = meta.badgeClass or 'npc',
        bodyClass = meta.bodyClass or meta.badgeClass or 'npc',
        icon = meta.icon or 'ph-user',
        title = meta.title or 'NPC',
        desc = meta.desc or 'Interacțiune',
        key = meta.key or 'E',
    })
end

function SunsetWorld.Npc.hideTooltip(id)
    if SunsetWorld.Tooltips then
        SunsetWorld.Tooltips.clear(id)
    end
end
