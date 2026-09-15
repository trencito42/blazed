-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (client/nui_debug.lua)
--  Local mirror of NUI debug state. The authoritative instrumentation
--  lives in sunset_ui (gated by sv_sunset_nuidebug); this file provides
--  a fallback view (focus polling + message interception) when the
--  instrumentation exports are unavailable, and normalizes the shape.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

NuiDebug = NuiDebug or {}

local lastFocus = { keyboard = false, mouse = false }
local focusChanges = {}
local head = 0

CreateThread(function()
    while true do
        local kb = IsNuiFocused()
        local mouse = IsNuiFocusKeepingInput()
        if kb ~= lastFocus.keyboard or mouse ~= lastFocus.mouse then
            head = head + 1
            focusChanges[((head - 1) % 20) + 1] = {
                at = os.date('%H:%M:%S'),
                keyboard = kb,
                keepInput = mouse,
            }
            lastFocus.keyboard = kb
            lastFocus.mouse = mouse
            ClientLog.debug('nui focus changed kb=%s keep=%s', tostring(kb), tostring(mouse))
        end
        Wait(200)
    end
end)

-- Normalized NUI state: prefers sunset_ui instrumentation, falls back to
-- the local focus mirror.
function NuiDebug.state()
    if GetResourceState('sunset_ui') == 'started' then
        local ok, state = pcall(function() return exports.sunset_ui:GetNuiDebugState() end)
        if ok and type(state) == 'table' and state.instrumented then
            return state
        end
    end
    -- Fallback view (not instrumented): focus only, no panel/message detail.
    local uiOpen = nil
    local screen = nil
    local owner = nil
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() uiOpen = exports.sunset_ui:IsOpen() end)
        pcall(function() owner = exports.sunset_ui:GetFocusOwner() end)
    end
    return {
        instrumented = false,
        focus = { keyboard = lastFocus.keyboard, keepInput = lastFocus.mouse },
        uiOpen = uiOpen,
        focusOwner = owner,
        currentScreen = screen,
        openPanels = {},
        lastMessage = nil,
        recentFocusChanges = focusChanges,
        note = 'Enable sv_sunset_nuidebug 1 for full NUI instrumentation (panels, messages, callbacks).',
    }
end

function NuiDebug.history(limit)
    if GetResourceState('sunset_ui') ~= 'started' then return {} end
    local ok, hist = pcall(function()
        return exports.sunset_ui:GetNuiDebugHistory(tonumber(limit) or 40)
    end)
    if ok and type(hist) == 'table' then return hist end
    return {}
end

function NuiDebug.errors(limit)
    if GetResourceState('sunset_ui') ~= 'started' then return {} end
    local ok, errs = pcall(function()
        return exports.sunset_ui:GetNuiDebugErrors(tonumber(limit) or 40)
    end)
    if ok and type(errs) == 'table' then return errs end
    return {}
end
