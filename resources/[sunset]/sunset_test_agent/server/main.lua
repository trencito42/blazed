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

-- [LEAK CLEANUP] Test-spawned entities are normally cleaned by the network
-- when the owning client drops (client-created entities are despawned), but
-- we still attempt explicit deletion for anything still server-visible and
-- drop the tracking records so memory never grows.
local function deleteTrackedEntities(src)
    for _, entry in ipairs(TestAgentTrackedEntities(src)) do
        local ent = NetworkGetEntityFromNetworkId(entry.netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            pcall(function()
                -- Clear the tag BEFORE DeleteEntity (state bag access on a
                -- deleted entity can error); tag removal is not a safety
                -- gate here — deletion itself is server-driven cleanup.
                Entity(ent).state:set(SunsetTestAgent.Config.testEntityStateKey, nil, true)
            end)
            pcall(function() DeleteEntity(ent) end)
            TestAgentLog.event('cleanup', 'deleted leaked test entity', { netId = entry.netId, model = entry.model })
        end
    end
    TestAgentClearTracked(src)
end

AddEventHandler('playerDropped', function()
    deleteTrackedEntities(source)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Best-effort cleanup of every tracked test entity before we die.
    for _, src in ipairs(TestAgentAllTrackedSources()) do
        deleteTrackedEntities(src)
    end
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
