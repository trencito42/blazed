-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (server/commands.lua)
--  Dev helper commands. All require the kill switch AND admin level
--  (except /testagent status which is deliberately informative).
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

local function requireAdmin(source)
    if GetConvar(Cfg.enabledConvar, 'false') ~= 'true' then
        return false, 'The test agent is disabled (kill switch off).'
    end
    local level = TestAgentAuth.adminLevel(source)
    if level < (Cfg.minAdminLevel or 5) then
        return false, ('Admin level %d < %d required.'):format(level, Cfg.minAdminLevel or 5)
    end
    return true
end

local function notify(source, msg, kind)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', 5000)
end

RegisterCommand('testagent', function(source, args)
    if source == 0 then
        -- Console usage: status only.
        print(('[TESTAGENT] enabled=%s testPlayer=%s token=%s'):format(
            tostring(GetConvar(Cfg.enabledConvar, 'false')),
            tostring(select(1, TestAgentAuth.testPlayer())),
            TestAgentAuth.tokenConfigured() and 'set' or 'MISSING'))
        return
    end
    local ok, err = requireAdmin(source)
    if not ok then return notify(source, err, 'error') end

    local action = tostring(args[1] or 'status'):lower()

    if action == 'status' then
        local testSrc, charId = TestAgentAuth.testPlayer()
        notify(source, ('Test agent: enabled, testPlayer=%s (char %s), token=%s'):format(
            tostring(testSrc or 'none'), tostring(charId or '-'),
            TestAgentAuth.tokenConfigured() and 'configured' or 'MISSING'), 'info', 8000)
    elseif action == 'register' then
        local okReg, res = TestAgentAuth.register(source)
        if okReg then
            notify(source, ('Registered as test player (serverId=%d).'):format(source), 'success')
        else
            notify(source, res.message or 'Registration failed.', 'error')
        end
    elseif action == 'reset' then
        TestAgentAuth.clear()
        TestAgentLog.clear()
        notify(source, 'Test agent state reset (player unregistered, logs cleared).', 'success')
    elseif action == 'allow' then
        local license = tostring(args[2] or '')
        if license == '' then return notify(source, 'Usage: /testagent allow <license>', 'error') end
        TestAgentAuth.allow(license)
        notify(source, 'License added to the test-agent allowlist.', 'success')
    elseif action == 'deny' then
        local license = tostring(args[2] or '')
        if license == '' then return notify(source, 'Usage: /testagent deny <license>', 'error') end
        TestAgentAuth.disallow(license)
        notify(source, 'License removed from the allowlist.', 'success')
    elseif action == 'debug' then
        local on = tostring(args[2] or ''):lower() ~= 'off'
        TestAgentLog.setDebug(on)
        notify(source, ('Test agent debug logging %s.'):format(on and 'ON' or 'OFF'), 'success')
    elseif action == 'logs' then
        local limit = tonumber(args[2]) or 50
        local logs = TestAgentLog.tail(limit)
        print(('^3[TESTAGENT LOGS last %d]^7'):format(#logs))
        for _, entry in ipairs(logs) do
            print(json.encode(entry))
        end
    else
        notify(source, 'Usage: /testagent status|register|reset|allow|deny|debug|logs', 'info')
    end
end, false)

-- Quick screenshot from chat (uploads like the MCP flow, prints the id).
RegisterCommand('testshot', function(source)
    if source == 0 then return end
    local ok, err = requireAdmin(source)
    if not ok then return notify(source, err, 'error') end
    if TestAgentAuth.testPlayer() ~= source then
        return notify(source, 'Register as the test player first (/testagent register).', 'error')
    end
    CreateThread(function()
        local result, toolErr = TestAgentTools.take_screenshot.fn(source, {})
        if result then
            notify(source, ('Screenshot stored: %s'):format(result.requestId), 'success')
            print(('^3[TESTAGENT]^7 screenshot id=%s bytes=%s path=%s'):format(
                result.requestId, tostring(result.bytes), result.downloadPath))
        else
            notify(source, (toolErr and toolErr.message) or 'Screenshot failed.', 'error')
        end
    end)
end, false)
