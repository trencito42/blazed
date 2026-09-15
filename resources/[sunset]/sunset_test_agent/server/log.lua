-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (server/log.lua)
--  Structured server-side ring buffer + observability log.
--  Every tool invocation is recorded with requestId/tool/target/
--  duration/outcome so the MCP client can correlate.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

TestAgentLog = TestAgentLog or {}

local buffer = {}       -- ring of structured entries
local head = 0          -- next write index
local total = 0         -- total written (monotonic)
local debugOn = false   -- gated console noise

local function nowMs() return GetGameTimer() end

local function wrapIndex(i)
    return ((i - 1) % Cfg.serverLogCapacity) + 1
end

function TestAgentLog.push(entry)
    total = total + 1
    head = wrapIndex(head + 1)
    entry.at = entry.at or os.date('%Y-%m-%dT%H:%M:%S')
    entry.seq = total
    buffer[head] = entry
end

-- Record a completed tool invocation (the observability contract).
function TestAgentLog.invocation(requestId, tool, targetPlayer, ok, errCode, durationMs)
    TestAgentLog.push({
        kind = 'invocation',
        requestId = tostring(requestId or ''),
        tool = tostring(tool or ''),
        target = tonumber(targetPlayer) or nil,
        ok = ok and true or false,
        error = errCode or nil,
        durationMs = tonumber(durationMs) or 0,
    })
end

function TestAgentLog.event(kind, message, details)
    TestAgentLog.push({
        kind = tostring(kind or 'event'),
        message = tostring(message or ''),
        details = type(details) == 'table' and details or nil,
    })
end

-- Oldest→newest slice for consumers.
function TestAgentLog.tail(limit)
    limit = math.max(1, math.min(tonumber(limit) or 200, Cfg.serverLogCapacity))
    local out = {}
    local count = math.min(limit, total)
    local start = head - count + 1
    for k = 0, count - 1 do
        local idx = wrapIndex(start + k)
        local entry = buffer[idx]
        if entry then out[#out + 1] = entry end
    end
    return out
end

function TestAgentLog.errorsOnly(limit)
    local out = {}
    for _, entry in ipairs(TestAgentLog.tail(Cfg.serverLogCapacity)) do
        if entry.kind == 'error' or (entry.kind == 'invocation' and entry.ok == false) then
            out[#out + 1] = entry
        end
    end
    local n = #out
    local startIdx = math.max(1, n - (tonumber(limit) or 100) + 1)
    local sliced = {}
    for i = startIdx, n do sliced[#sliced + 1] = out[i] end
    return sliced
end

function TestAgentLog.clear()
    buffer = {}
    head = 0
    total = 0
end

function TestAgentLog.setDebug(on)
    debugOn = on == true
end

function TestAgentLog.debug(fmt, ...)
    if not debugOn then return end
    print(('^6[TESTAGENT]^7 ' .. fmt):format(...))
end

-- Console-visible warnings/errors always print (not gated) — these are the
-- "identify the real problem" lines operators need without debug mode.
function TestAgentLog.warn(fmt, ...)
    print(('^3[TESTAGENT]^7 ' .. fmt):format(...))
end

function TestAgentLog.error(fmt, ...)
    print(('^1[TESTAGENT]^7 ' .. fmt):format(...))
    TestAgentLog.push({ kind = 'error', message = (fmt):format(...) })
end

function TestAgentLog.nowMs() return nowMs() end
