SunsetWorld = SunsetWorld or {}
SunsetWorld.Tooltips = SunsetWorld.Tooltips or {}

local active = {}
local TOOLTIP_TTL_MS = 750
local TOOLTIP_MAX_DISTANCE = 15.0

local function sendSync(list)
    exports.sunset_ui:Send('worldTooltipsSync', list or {})
end

local function rowPayload(id, row, sx, sy)
    return {
        id = id,
        visible = true,
        x = sx * 100.0,
        y = sy * 100.0,
        badge = row.badge or '',
        badgeClass = row.badgeClass or '',
        bodyClass = row.bodyClass or row.badgeClass or '',
        icon = row.icon or 'ph-circle',
        title = row.title or '',
        desc = row.desc or '',
        meta = row.meta or '',
        key = row.key or 'E',
    }
end

function SunsetWorld.Tooltips.set(id, data)
    if not id then return end
    if not data or data.visible == false then
        SunsetWorld.Tooltips.clear(id)
        return
    end

    local coords = data.coords
    if not coords then
        SunsetWorld.Tooltips.clear(id)
        return
    end

    active[id] = {
        coords = coords,
        touchedAt = GetGameTimer(),
        maxDistance = tonumber(data.maxDistance) or TOOLTIP_MAX_DISTANCE,
        badge = data.badge or '',
        badgeClass = data.badgeClass or '',
        bodyClass = data.bodyClass or data.badgeClass or '',
        icon = data.icon or 'ph-circle',
        title = data.title or '',
        desc = data.desc or '',
        meta = data.meta or '',
        key = data.key or 'E',
    }
end

function SunsetWorld.Tooltips.clear(id)
    if id then
        if active[id] then
            active[id] = nil
        end
        return
    end
    active = {}
    sendSync({})
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

CreateThread(function()
    while true do
        local hasActive = next(active) ~= nil
        if hasActive then
            local list = {}
            local now = GetGameTimer()
            local playerCoords = GetEntityCoords(PlayerPedId())
            for id, row in pairs(active) do
                local coords = row.coords
                local stale = now - (row.touchedAt or 0) > TOOLTIP_TTL_MS
                local tooFar = coords and #(playerCoords - coords) > (row.maxDistance or TOOLTIP_MAX_DISTANCE)
                if stale or tooFar then
                    active[id] = nil
                elseif coords then
                    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
                    if onScreen then
                        list[#list + 1] = rowPayload(id, row, sx, sy)
                    end
                end
            end
            sendSync(list)
            -- Screen-space labels must follow camera motion smoothly. 30Hz keeps
            -- them responsive without returning to the old per-frame NUI flood.
            Wait(33)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('sunset:world:clearTooltips', function()
    SunsetWorld.Tooltips.clear()
end)
