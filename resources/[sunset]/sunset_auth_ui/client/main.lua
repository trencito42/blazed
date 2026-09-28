-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Auth UI (client/main.lua)
--  Minimal NUI host for the login screen. Holds NO auth logic:
--  every NUI callback is forwarded to sunset_auth as an event, and
--  sunset_auth pushes state back through the Send/Show exports.
--  This keeps one source of truth for authentication.
-- ═══════════════════════════════════════════════════════════════

local authOpen = false
local authRendered = false
local authBootEpoch = 0

local function send(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

exports('Send', send)

exports('Show', function(screen, data)
    authOpen = true
    SetNuiFocus(true, true)
    send('authShow', data)
end)

exports('Hide', function()
    authOpen = false
    SetNuiFocus(false, false)
    send('authHide', {})
end)

exports('SetFocus', function(hasFocus, hasCursor)
    SetNuiFocus(hasFocus == true, hasCursor == true)
    if not hasFocus then authOpen = false end
end)

exports('IsAuthOpen', function() return authOpen end)
exports('IsRendered', function() return authRendered end)
exports('GetBootEpoch', function() return authBootEpoch end)

-- ── Forward NUI callbacks to sunset_auth ──
local FORWARDED = {
    'authReady',
    'authLogin',
    'authRegister',
    'authPickAccount',
    'authRemoveAccount',
    'authSetEmail',
    'authSetQuickLogin',
}

for _, name in ipairs(FORWARDED) do
    RegisterNUICallback(name, function(data, cb)
        TriggerEvent('sunset:nui:' .. name, type(data) == 'table' and data or {})
        cb('ok')
    end)
end

RegisterNUICallback('authRendered', function(data, cb)
    authRendered = true
    authBootEpoch = GetGameTimer()
    TriggerEvent('sunset:auth:rendered', data)
    cb('ok')
end)

