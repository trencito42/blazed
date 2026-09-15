-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (server/auth.lua)
--  Two independent gates, both required for every HTTP request:
--    1. Bearer token match (constant-time compare) from convar.
--    2. Kill switch convar must be explicitly true.
--  Test-player registration additionally requires a real in-game
--  admin level (sunset_admin) and an explicit allowlist entry.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

TestAgentAuth = TestAgentAuth or {}

local expectedToken = nil
local testPlayerSource = nil
local testPlayerCharId = nil
local allowlist = {}   -- [license] = true  (set via /testagent allow <license>)

local function killSwitchOn()
    return GetConvar(Cfg.enabledConvar, 'false') == 'true'
end

function TestAgentAuth.enabled()
    return killSwitchOn()
end

-- Constant-time string compare to avoid leaking the token via timing.
local function constTimeEquals(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' then return false end
    if #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do
        diff = bit32.bor(diff, bit32.bxor(a:byte(i), b:byte(i)))
    end
    return diff == 0
end

function TestAgentAuth.loadToken()
    local raw = GetConvar(Cfg.tokenConvar, '')
    if raw == '' then
        expectedToken = nil
        TestAgentLog.warn('no %s configured — HTTP bridge will reject everything (set a dev token)',
            Cfg.tokenConvar)
        return nil
    end
    expectedToken = raw
    return true
end

function TestAgentAuth.tokenConfigured()
    return expectedToken ~= nil
end

-- Validate the Authorization header value ("Bearer <token>").
function TestAgentAuth.checkBearer(authorizationHeader)
    if not killSwitchOn() then
        return false, SunsetTestAgent.Errors.DISABLED
    end
    if not expectedToken then
        return false, SunsetTestAgent.Errors.UNAUTHORIZED
    end
    if type(authorizationHeader) ~= 'string' then
        return false, SunsetTestAgent.Errors.UNAUTHORIZED
    end
    local supplied = authorizationHeader:match('^Bearer%s+(.+)$')
    if not supplied then
        return false, SunsetTestAgent.Errors.UNAUTHORIZED
    end
    if not constTimeEquals(supplied, expectedToken) then
        return false, SunsetTestAgent.Errors.UNAUTHORIZED
    end
    return true
end

-- ── Test player registration ──

function TestAgentAuth.adminLevel(source)
    if GetResourceState('sunset_admin') ~= 'started' then return 0 end
    local ok, level = pcall(function() return exports.sunset_admin:GetAdminLevel(source) end)
    return ok and (tonumber(level) or 0) or 0
end

function TestAgentAuth.licenseOf(source)
    local ids = GetPlayerIdentifiers(source) or {}
    for _, id in ipairs(ids) do
        local lic = id:match('^license:(.+)$')
        if lic then return lic end
    end
    return nil
end

function TestAgentAuth.allow(license)
    if type(license) ~= 'string' or license == '' then return false end
    allowlist[license] = true
    TestAgentLog.event('allowlist', 'license added', { license = license:sub(1, 12) .. '…' })
    return true
end

function TestAgentAuth.disallow(license)
    if type(license) ~= 'string' then return false end
    allowlist[license] = nil
    if testPlayerSource then
        local current = TestAgentAuth.licenseOf(testPlayerSource)
        if current == license then TestAgentAuth.clear() end
    end
    return true
end

-- Register the calling player as THE test player. Requires admin level and
-- (if an allowlist is non-empty) membership in it.
function TestAgentAuth.register(source)
    if not killSwitchOn() then
        return false, SunsetTestAgent.Errors.DISABLED
    end
    local level = TestAgentAuth.adminLevel(source)
    if level < (Cfg.minAdminLevel or 5) then
        return false, {
            code = 'UNAUTHORIZED',
            message = ('Admin level %d is below the required %d for test-player registration.')
                :format(level, Cfg.minAdminLevel or 5),
            retryable = false,
        }
    end
    local license = TestAgentAuth.licenseOf(source)
    local hasAllowlist = next(allowlist) ~= nil
    if hasAllowlist and not (license and allowlist[license]) then
        return false, {
            code = 'UNAUTHORIZED',
            message = 'Your license is not in the test-agent allowlist.',
            retryable = false,
        }
    end
    testPlayerSource = source
    local char = exports.sunset_core:GetCharacter(source)
    testPlayerCharId = char and tonumber(char.id) or nil
    TestAgentLog.event('register', 'test player registered', {
        source = source, charId = testPlayerCharId, adminLevel = level,
    })
    return true, { source = source, charId = testPlayerCharId, adminLevel = level }
end

function TestAgentAuth.clear()
    if testPlayerSource then
        TestAgentLog.event('register', 'test player cleared', { source = testPlayerSource })
    end
    testPlayerSource = nil
    testPlayerCharId = nil
end

function TestAgentAuth.testPlayer()
    if not testPlayerSource then return nil end
    -- Verify the source is still a live connection.
    if not GetPlayerName(testPlayerSource) then
        TestAgentAuth.clear()
        return nil
    end
    return testPlayerSource, testPlayerCharId
end

function TestAgentAuth.hasTestPlayer()
    return (TestAgentAuth.testPlayer() ~= nil)
end

-- Bearer value handed to the TEST CLIENT for its screenshot upload POST.
-- The client is a trusted dev machine already authenticated by admin level;
-- the token never reaches the MCP client through this path (MCP authenticates
-- with its own copy from env). Only valid while the kill switch is on.
function TestAgentAuth.bearerForClient()
    if not killSwitchOn() then return nil end
    return expectedToken
end

-- Resolve a requested target: nil/'test' → the registered test player;
-- an explicit numeric id → that player (still must be connected).
function TestAgentAuth.resolveTarget(requested)
    if requested == nil or requested == 'test' or requested == 0 then
        local src = TestAgentAuth.testPlayer()
        if not src then return nil, SunsetTestAgent.Errors.TEST_PLAYER_NOT_CONNECTED end
        return src
    end
    local src = tonumber(requested)
    if not src then return nil, SunsetTestAgent.Errors.INVALID_ARGUMENT end
    if not GetPlayerName(src) then
        return nil, SunsetTestAgent.Errors.TEST_PLAYER_NOT_CONNECTED
    end
    return src
end

AddEventHandler('playerDropped', function()
    if source == testPlayerSource then
        TestAgentLog.event('register', 'test player disconnected', { source = source })
        TestAgentAuth.clear()
    end
end)
