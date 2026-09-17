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

-- Returns TRUE only when the tooltip was actually handed to the sync layer.
-- Callers must not mark their prompt "visible" on a silent early-return.
function SunsetWorld.Npc.showTooltip(id, ped, meta)
    if GetResourceState('sunset_world') ~= 'started' or not SunsetWorld.Tooltips then
        return false, 'sunset_world or Tooltips unavailable'
    end
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false, 'ped missing or invalid'
    end
    -- Keep the entity handle in the shared tooltip layer. The layer resolves the
    -- head position on the render tick, so slow/irregular callers can never leave
    -- an NPC tooltip visually trailing an old world coordinate.
    SunsetWorld.Tooltips.set(id, {
        entity = ped,
        offsetZ = meta.offsetZ or 0.42,
        badge = meta.badge or '',
        badgeClass = meta.badgeClass or 'npc',
        bodyClass = meta.bodyClass or meta.badgeClass or 'npc',
        icon = meta.icon or 'ph-user',
        title = meta.title or 'NPC',
        desc = meta.desc or 'Interaction',
        key = meta.key or 'E',
    })
    return true
end

function SunsetWorld.Npc.hideTooltip(id)
    if SunsetWorld.Tooltips then
        SunsetWorld.Tooltips.clear(id)
    end
end

-- [CROSS-RESOURCE FIX] FiveM gives every resource its own Lua environment, so
-- other resources could never read the `SunsetWorld` global — their
-- `not SunsetWorld` guards always short-circuited and their NPC tooltips were
-- silently never rendered (Billy Ray, trucker NPC). Expose real exports.
exports('NpcShowTooltip', function(id, ped, meta)
    return SunsetWorld.Npc.showTooltip(id, ped, type(meta) == 'table' and meta or {})
end)

exports('NpcHideTooltip', function(id)
    SunsetWorld.Npc.hideTooltip(id)
    return true
end)

exports('TooltipCoordsFromEntity', function(entity, offsetZ)
    if not SunsetWorld.Tooltips then return nil end
    return SunsetWorld.Tooltips.coordsFromEntity(entity, offsetZ)
end)

-- Generic tooltip set/clear for non-NPC callers (fuel pumps etc.) that live in
-- other resources and therefore cannot reach SunsetWorld.Tooltips directly.
exports('TooltipSet', function(id, data)
    if not SunsetWorld.Tooltips then return false end
    SunsetWorld.Tooltips.set(id, data)
    return true
end)

exports('TooltipClear', function(id)
    if not SunsetWorld.Tooltips then return false end
    SunsetWorld.Tooltips.clear(id)
    return true
end)
