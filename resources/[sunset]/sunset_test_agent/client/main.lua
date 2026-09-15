-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (client/main.lua)
--  Boot + kill switch mirroring the server. The client does nothing
--  unless the agent is enabled; handlers are registered but inert
--  without a server-side RPC (which requires auth + registration).
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

CreateThread(function()
    Wait(1500)
    if GetConvar(Cfg.enabledConvar, 'false') ~= 'true' then
        ClientLog.debug('test agent client disabled (kill switch off)')
        return
    end
    ClientLog.action('test agent client ready', { resource = GetCurrentResourceName() })
end)

-- Safety: if the resource stops mid-action, make sure focus is not stuck
-- ONLY if we own it (we never take focus, so this is a no-op guard).
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClientLog.push('lifecycle', 'test agent client stopped')
end)

exports('IsTestAgentClient', function()
    return GetConvar(Cfg.enabledConvar, 'false') == 'true'
end)
