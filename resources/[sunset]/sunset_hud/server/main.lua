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
    if type(layout) ~= 'table' then return false end
    for id, pos in pairs(layout) do
        if not PANELS[id] then return false end
        if type(pos) ~= 'table' or type(pos.x) ~= 'number' or type(pos.y) ~= 'number' then
            return false
        end
    end
    return true
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
    if not validateLayout(layout) then
        notify(src, 'Invalid HUD layout data', 'error')
        return
    end

    local encoded = json.encode(layout)
    SaveResourceFile(GetCurrentResourceName(), LAYOUT_FILE, encoded, -1)

    if applyAll then
        TriggerClientEvent('sunset:client:hudDefaultUpdated', -1, layout, true)
        notify(src, 'HUD layout exported and applied to all players', 'success')
    else
        TriggerClientEvent('sunset:client:hudDefaultUpdated', -1, layout, false)
        notify(src, 'HUD layout exported as server default (new players + /hudreset)', 'success')
    end
end)
