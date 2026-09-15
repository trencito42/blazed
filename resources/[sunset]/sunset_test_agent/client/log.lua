-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (client/log.lua)
--  Structured client-side ring buffer: test actions, RPC calls,
--  runtime errors, NUI bridge debug lines.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

ClientLog = {}

local buffer = {}
local head = 0
local total = 0

local function wrapIndex(i)
    return ((i - 1) % Cfg.clientLogCapacity) + 1
end

function ClientLog.push(kind, message, details)
    total = total + 1
    head = wrapIndex(head + 1)
    buffer[head] = {
        seq = total,
        kind = tostring(kind or 'log'),
        message = tostring(message or ''),
        details = type(details) == 'table' and details or nil,
        at = os.date('%H:%M:%S'),
        gameTimer = GetGameTimer(),
    }
end

function ClientLog.action(message, details)
    ClientLog.push('action', message, details)
end

function ClientLog.error(message, details)
    ClientLog.push('error', message, details)
    print(('^1[TESTAGENT CLIENT]^7 %s'):format(message))
end

function ClientLog.debug(fmt, ...)
    if GetConvar('sv_sunset_testagent_debug', '0') ~= '1' then return end
    local msg = fmt:format(...)
    ClientLog.push('debug', msg)
    print(('^6[TESTAGENT CLIENT]^7 ' .. msg))
end

function ClientLog.tail(limit)
    limit = math.max(1, math.min(tonumber(limit) or 200, Cfg.clientLogCapacity))
    local out = {}
    local count = math.min(limit, total)
    local start = head - count + 1
    for k = 0, count - 1 do
        local entry = buffer[wrapIndex(start + k)]
        if entry then out[#out + 1] = entry end
    end
    return out
end

function ClientLog.clear()
    buffer = {}
    head = 0
    total = 0
end

-- Capture unhandled Lua errors on the client into the buffer.
AddEventHandler('onClientResourceStop', function(res)
    ClientLog.push('resource', 'resource stopped: ' .. tostring(res))
end)
