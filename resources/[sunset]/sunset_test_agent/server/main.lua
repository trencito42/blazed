-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (server/main.lua)
--  Boot / kill-switch enforcement / screenshot-basic lifecycle.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

CreateThread(function()
    Wait(1000)
    local enabled = GetConvar(Cfg.enabledConvar, 'false') == 'true'
    if not enabled then
        print('^3[sunset_test_agent]^7 disabled (kill switch off). Set "setr sunset_test_agent_enabled true" on a DEV server to enable.')
        return
    end
    TestAgentAuth.loadToken()
    if not TestAgentAuth.tokenConfigured() then
        TestAgentLog.error('enabled but no token configured — bridge stays locked. Set "%s".', Cfg.tokenConvar)
    end

    -- Start the minimal screenshot resource only while the agent is enabled.
    -- screenshot-basic is an EXTERNAL resource (not vendored in this repo):
    -- install it into resources/ (see docs/testing/FIVEM_MCP.md). When
    -- missing, screenshots fail with SCREENSHOT_FAILED — everything else works.
    local ssState = GetResourceState('screenshot_basic')
    if ssState == 'stopped' then
        StartResource('screenshot_basic')
        TestAgentLog.event('boot', 'started screenshot_basic')
    elseif ssState == 'missing' then
        TestAgentLog.warn('screenshot_basic is NOT installed — take_screenshot will fail until it is added (docs/testing/FIVEM_MCP.md)')
    end

    TestAgentLog.setDebug(GetConvar('sv_sunset_testagent_debug', '0') == '1')
    TestAgentLog.event('boot', 'test agent ENABLED', {
        minAdminLevel = Cfg.minAdminLevel,
        tokenConfigured = TestAgentAuth.tokenConfigured(),
    })
    print('^2[sunset_test_agent]^7 ENABLED (dev bridge). Register in-game with /testagent register (admin level ' ..
        tostring(Cfg.minAdminLevel) .. '+).')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Leave screenshot_basic running only while the agent is enabled.
    if GetConvar(Cfg.enabledConvar, 'false') ~= 'true' then
        if GetResourceState('screenshot_basic') == 'started' then
            StopResource('screenshot_basic')
        end
    end
    TestAgentAuth.clear()
    TestAgentLog.event('stop', 'test agent stopped')
end)

-- Exports for other dev tooling (never for production gameplay resources).
exports('IsEnabled', function()
    return GetConvar(Cfg.enabledConvar, 'false') == 'true'
end)
exports('GetTestPlayer', function()
    return TestAgentAuth.testPlayer()
end)
