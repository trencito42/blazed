local LAYOUT_FILE = 'hud_layout_default.json'

local PANELS = {
    tl = true,
    logo = true,
    tr = true,
    bl = true,
    bc = true,
    speedo = true,
}

local function validateLayout(layout)
    if type(layout) ~= 'table' then return false, nil end

    local sanitized = {}
    local count = 0

    for id, pos in pairs(layout) do
        if PANELS[id] then
            if type(pos) ~= 'table' then return false, nil end
            local x = tonumber(pos.x)
            local y = tonumber(pos.y)
            if x == nil or y == nil then return false, nil end
            sanitized[id] = { x = x, y = y }
            count = count + 1
        end
    end

    if count == 0 then return false, nil end
    return true, sanitized
end

local function notify(source, msg, ntype)
    TriggerClientEvent('sunset:client:notify', source, msg, ntype or 'info')
end

RegisterNetEvent('sunset:server:hudExport', function(layout, applyAll)
    local src = source
    if not exports.sunset_admin:IsAdmin(src, 3) then
        notify(src, 'No permission to export HUD layout', 'error')
        return
    end
    local ok, sanitized = validateLayout(layout)
    if not ok then
        notify(src, 'Invalid HUD layout data', 'error')
        return
    end

    local encoded = json.encode(sanitized)
    SaveResourceFile(GetCurrentResourceName(), LAYOUT_FILE, encoded, -1)

    if applyAll then
        TriggerClientEvent('sunset:client:hudDefaultUpdated', -1, sanitized, true)
        notify(src, 'HUD layout exported and applied to all players', 'success')
    else
        TriggerClientEvent('sunset:client:hudDefaultUpdated', -1, sanitized, false)
        notify(src, 'HUD layout exported as server default (new players + /hudreset)', 'success')
    end
end)
