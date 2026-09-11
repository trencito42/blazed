SunsetWorld = SunsetWorld or {}
SunsetWorld.Tooltips = SunsetWorld.Tooltips or {}

local active = {}

local function sendSync()
    local list = {}
    for id, row in pairs(active) do
        list[#list + 1] = row
        if not row.visible then
            active[id] = nil
        end
    end
    exports.sunset_ui:Send('worldTooltipsSync', list)
end

function SunsetWorld.Tooltips.set(id, data)
    if not id then return end
    if not data or data.visible == false then
        if active[id] then
            active[id] = { id = id, visible = false }
            sendSync()
        end
        return
    end

    local coords = data.coords
    if not coords then
        SunsetWorld.Tooltips.clear(id)
        return
    end

    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then
        if active[id] then
            active[id] = { id = id, visible = false }
            sendSync()
        end
        return
    end

    active[id] = {
        id = id,
        visible = true,
        x = sx * 100.0,
        y = sy * 100.0,
        badge = data.badge or '',
        badgeClass = data.badgeClass or '',
        bodyClass = data.bodyClass or data.badgeClass or '',
        icon = data.icon or 'ph-circle',
        title = data.title or '',
        desc = data.desc or '',
        meta = data.meta or '',
        key = data.key or 'E',
    }
    sendSync()
end

function SunsetWorld.Tooltips.clear(id)
    if id then
        if active[id] then
            active[id] = { id = id, visible = false }
            sendSync()
        end
        return
    end
    active = {}
    exports.sunset_ui:Send('worldTooltipsSync', {})
end

function SunsetWorld.Tooltips.coordsFromEntity(entity, offsetZ)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local head = GetPedBoneCoords(entity, 31086, 0.0, 0.0, 0.0)
    if head.x == 0.0 and head.y == 0.0 and head.z == 0.0 then
        head = GetEntityCoords(entity)
    end
    return vector3(head.x, head.y, head.z + (offsetZ or 0.45))
end

function SunsetWorld.Tooltips.coordsFromVector3(vec, offsetZ)
    if not vec then return nil end
    return vector3(vec.x, vec.y, vec.z + (offsetZ or 1.05))
end
