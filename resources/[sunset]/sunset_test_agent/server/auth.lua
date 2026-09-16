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
-- NOTE: Lua 5.4 (lua54 'yes' in fxmanifest) has NO bit32 library — use the
-- native bitwise operators instead.
local function constTimeEquals(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' then return false end
    if #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do
        diff = diff | (a:byte(i) ~ b:byte(i))
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
    -- [DELIBERATE POLICY] one test player at a time. Re-registering from a
    -- DIFFERENT player while the current one is still connected is refused:
    -- silently stealing the slot could redirect mutation tools at another
    -- player's session mid-test. The current holder must /testagent reset
    -- (or disconnect, which clears registration) first.
    if testPlayerSource and testPlayerSource ~= source and GetPlayerName(testPlayerSource) then
        return false, {
            code = 'OPERATION_NOT_ALLOWED',
            message = ('ServerId %d is already the registered test player. Ask them to run /testagent reset first.')
                :format(testPlayerSource),
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

-- [TOKEN HYGIENE] The master bearer token is NEVER handed to the game client.
-- Screenshot uploads authenticate with the server-issued one-shot requestId
-- (capability model) instead — see http.lua /screenshot route and
-- TestAgentIssueScreenshotId in tools.lua. There is deliberately no
-- bearerForClient() accessor.

-- Resolve a requested target: nil/'test' → the registered test player;
-- an explicit numeric id → that player (still must be connected).
-- READ tools only. Mutating tools must use resolveMutationTarget below.
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

-- [MUTATION SAFETY] Mutating tools (teleport, vitals, heading, spawn,
-- delete, control actions, semantic interactions) may ONLY affect the
-- registered test player. Bearer-token holders cannot use the bridge to
-- grief other connected players. Reads stay permissive (explicit serverId).
function TestAgentAuth.resolveMutationTarget(requested)
    local testSrc = TestAgentAuth.testPlayer()
    if not testSrc then return nil, SunsetTestAgent.Errors.TEST_PLAYER_NOT_CONNECTED end
    if requested == nil or requested == 'test' or requested == 0 then
        return testSrc
    end
    local src = tonumber(requested)
    if not src then return nil, SunsetTestAgent.Errors.INVALID_ARGUMENT end
    if src ~= testSrc then
        return nil, {
            code = 'OPERATION_NOT_ALLOWED',
            message = ('Mutation tools may only target the registered test player (serverId %d); got %d.'):format(testSrc, src),
            retryable = false,
        }
    end
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

-- [SELFTEST] Console-only verification of the constant-time compare
-- (run: docker exec ... or rcon `testagent_selftest`). Proves the Lua 5.4
-- native-operator implementation behaves correctly without exposing the
-- real token: uses fixed literals.
RegisterCommand('testagent_selftest', function(source)
    if source ~= 0 then
        print('[TESTAGENT] selftest is console-only')
        return
    end
    local cases = {
        { a = 'abc123', b = 'abc123', want = true,  name = 'same token' },
        { a = 'abc123', b = 'abc124', want = false, name = 'same length, different' },
        { a = 'abc123', b = 'abc12',  want = false, name = 'different length' },
        { a = '',       b = '',       want = true,  name = 'empty equal' },
        { a = 'x',      b = '',       want = false, name = 'empty vs non-empty' },
    }
    local pass = true
    for _, c in ipairs(cases) do
        local got = constTimeEquals(c.a, c.b)
        local ok = got == c.want
        pass = pass and ok
        print(('[TESTAGENT SELFTEST] %s: %s (want=%s got=%s)'):format(
            ok and 'PASS' or 'FAIL', c.name, tostring(c.want), tostring(got)))
    end
    print(('^%d[TESTAGENT SELFTEST]^7 %s'):format(pass and 2 or 1, pass and 'ALL PASS' or 'FAILURES PRESENT'))
end, true) -- restricted=true: console/rcon only, players cannot call it
