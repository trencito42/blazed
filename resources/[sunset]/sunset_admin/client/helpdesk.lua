-- ═══════════════════════════════════════════════════════════════
--  ADMIN HELPDESK (client) — /helpdesk panel + Blaze Shield widget.
--  Separate file so sunset_admin/client/main.lua stays untouched by
--  parallel work. All data comes from server callbacks (no client
--  authority); every action re-checks permissions server-side.
-- ═══════════════════════════════════════════════════════════════

local helpdeskOpen = false
local shieldHudEnabled = false

-- ── /helpdesk — advanced staff panel (level 1+) ──
local function openHelpdesk()
    if helpdeskOpen then return end
    local data, err = Sunset.AwaitCallback('sunset:helpdesk:panel')
    if not data then
        exports.sunset_ui:Notify(err or 'Helpdesk could not be opened.', 'error')
        return
    end
    helpdeskOpen = true
    exports.sunset_ui:Send('helpdeskShow', data)
    exports.sunset_ui:SetFocus(true, true, false, 'helpdesk')
end

local function closeHelpdesk()
    if not helpdeskOpen then return end
    helpdeskOpen = false
    exports.sunset_ui:Send('helpdeskHide', {})
    exports.sunset_ui:SetFocus(false, false, false, 'helpdesk')
end

RegisterCommand('helpdesk', function()
    if helpdeskOpen then closeHelpdesk() else openHelpdesk() end
end, false)

CreateThread(function()
    Wait(1500)
    TriggerEvent('chat:addSuggestion', '/helpdesk', 'Open the staff console (roster, heat, reports, quick actions)')
end)

-- Live refresh while the panel is open (2 s poll).
CreateThread(function()
    while true do
        Wait(2000)
        if helpdeskOpen then
            local data = Sunset.AwaitCallback('sunset:helpdesk:panel')
            if data then
                exports.sunset_ui:Send('helpdeskRefresh', data)
            else
                closeHelpdesk()
            end
        end
    end
end)

AddEventHandler('sunset:nui:helpdeskClose', function()
    closeHelpdesk()
end)

-- Panel action button → server router (permission-checked there).
AddEventHandler('sunset:nui:helpdeskAction', function(data)
    data = data or {}
    if data.action == 'evidence' then
        local res = Sunset.AwaitCallback('sunset:helpdesk:action', 'evidence', tonumber(data.targetId))
        exports.sunset_ui:Send('helpdeskTicks', (type(res) == 'table' and res.ticks) and { ticks = res.ticks } or { ticks = {} })
        return
    end
    local res, err = Sunset.AwaitCallback('sunset:helpdesk:action', data.action, data.targetId, data)
    if err then
        exports.sunset_ui:Notify(tostring(err), 'error')
        return
    end
    if data.action == 'history' and type(res) == 'table' then
        exports.sunset_ui:Send('helpdeskHistory', { rows = res, targetId = data.targetId })
        return
    end
    if data.action == 'spectate' then closeHelpdesk() end
    -- refresh immediately after a successful action
    local fresh = Sunset.AwaitCallback('sunset:helpdesk:panel')
    if fresh and helpdeskOpen then exports.sunset_ui:Send('helpdeskRefresh', fresh) end
end)

-- ── Blaze Shield corner widget (bZone-style) ──
RegisterNetEvent('sunset:anticheat:shieldHud', function(payload)
    exports.sunset_ui:Send('shieldHud', payload or {})
end)

RegisterNetEvent('sunset:anticheat:shieldHudHide', function()
    shieldHudEnabled = false
    exports.sunset_ui:Send('shieldHudHide', {})
end)

RegisterNetEvent('sunset:anticheat:shieldHudToggle', function(enabled)
    shieldHudEnabled = enabled == true
    exports.sunset_ui:Notify(shieldHudEnabled and 'Shield HUD enabled.' or 'Shield HUD disabled.', 'info')
    if not shieldHudEnabled then
        exports.sunset_ui:Send('shieldHudHide', {})
    end
end)

AddEventHandler('sunset:client:playerSpawned', function()
    -- keep the widget state across respawn
    if shieldHudEnabled then
        exports.sunset_ui:Send('shieldHud', {})
    end
end)

exports('IsHelpdeskOpen', function() return helpdeskOpen end)

-- Universal ESC (app.js posts helpdeskClose; this is the safety net).
CreateThread(function()
    while true do
        Wait(200)
        if helpdeskOpen and IsPauseMenuActive and IsPauseMenuActive() then
            closeHelpdesk()
        end
    end
end)
