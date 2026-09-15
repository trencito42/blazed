-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (shared/config.lua)
--  DEV-ONLY runtime testing bridge. Everything here is a safety
--  default; production keeps the kill switch off.
-- ═══════════════════════════════════════════════════════════════

SunsetTestAgent = SunsetTestAgent or {}

SunsetTestAgent.Config = {
    -- Kill switch. Must be explicitly true via convar to do anything.
    -- setr sunset_test_agent_enabled true
    enabledConvar = 'sunset_test_agent_enabled',

    -- Shared bearer token for the HTTP bridge. NEVER hardcoded here —
    -- read from convar (set in server.cfg / .env on the dev box only).
    -- set sunset_test_agent_token <random>
    tokenConvar = 'sunset_test_agent_token',

    -- Minimum sunset_admin level allowed to register as the test player.
    -- 5 = owner. Lower only on a private dev box.
    minAdminLevel = 5,

    -- HTTP route prefix served by SetHttpHandler on the game port.
    httpPrefix = '/testagent/',

    -- Server→client RPC timeout (ms). Long enough for a screenshot encode
    -- on a slow client, short enough that MCP never hangs.
    rpcTimeoutMs = 12000,

    -- Screenshot encode/transfer budget (ms).
    screenshotTimeoutMs = 10000,

    -- Client-side ring buffer sizes.
    clientLogCapacity = 400,
    serverLogCapacity = 600,
    nuiHistoryCapacity = 60,

    -- Resource lifecycle guardrails: these may never be stopped/restarted
    -- by the bridge even when explicitly asked.
    protectedResources = {
        ['sunset_test_agent'] = true,   -- never kill the bridge under itself
        ['sunset_sessions'] = true,     -- session manager (canonical lifecycle)
        ['oxmysql'] = true,             -- database
        ['sunset_core'] = true,         -- framework bus
        ['webadmin'] = true,
        ['monitor'] = true,
    },

    -- Only resources matching this prefix may be restarted/stopped.
    allowedResourcePrefix = 'sunset_',

    -- Max entities returned by nearby-* scans (keeps payloads bounded).
    maxNearbyEntities = 200,
    maxNearbyRadius = 150.0,

    -- Test-spawned entities are tagged with this state bag key so deletion
    -- can refuse to touch production entities.
    testEntityStateKey = 'sunsetTestAgentSpawned',
}

-- Error taxonomy — shared by server, MCP and docs. Never invent new codes
-- on the fly; add here first.
SunsetTestAgent.Errors = {
    TEST_PLAYER_NOT_CONNECTED = {
        code = 'TEST_PLAYER_NOT_CONNECTED',
        message = 'No authorized FiveM test client is currently registered.',
        retryable = true,
    },
    RESOURCE_NOT_STARTED = {
        code = 'RESOURCE_NOT_STARTED',
        message = 'A required resource is not started.',
        retryable = true,
    },
    TIMEOUT = {
        code = 'TIMEOUT',
        message = 'The operation timed out waiting for the client or server.',
        retryable = true,
    },
    ENTITY_NOT_FOUND = {
        code = 'ENTITY_NOT_FOUND',
        message = 'The entity could not be resolved or no longer exists.',
        retryable = false,
    },
    UNAUTHORIZED = {
        code = 'UNAUTHORIZED',
        message = 'Authentication failed for the test bridge.',
        retryable = false,
    },
    SCREENSHOT_FAILED = {
        code = 'SCREENSHOT_FAILED',
        message = 'The client could not capture or encode a screenshot.',
        retryable = true,
    },
    NUI_UNAVAILABLE = {
        code = 'NUI_UNAVAILABLE',
        message = 'sunset_ui is not available to inspect NUI state.',
        retryable = true,
    },
    INVALID_ARGUMENT = {
        code = 'INVALID_ARGUMENT',
        message = 'A tool argument was missing, malformed or out of range.',
        retryable = false,
    },
    OPERATION_NOT_ALLOWED = {
        code = 'OPERATION_NOT_ALLOWED',
        message = 'This operation is blocked by test-agent policy.',
        retryable = false,
    },
    ASSERTION_FAILED = {
        code = 'ASSERTION_FAILED',
        message = 'A runtime assertion did not hold.',
        retryable = false,
    },
    DISABLED = {
        code = 'OPERATION_NOT_ALLOWED',
        message = 'The test agent is disabled (kill switch off).',
        retryable = false,
    },
    UNKNOWN_TOOL = {
        code = 'INVALID_ARGUMENT',
        message = 'Unknown test-agent tool.',
        retryable = false,
    },
    INTERNAL = {
        code = 'INTERNAL',
        message = 'Unexpected internal error in the test bridge.',
        retryable = false,
    },
}
