-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (server/http.lua)
--  HTTP bridge on the FXServer game port (SetHttpHandler).
--  POST /testagent/invoke  { requestId, tool, target?, args? }
--  POST /testagent/<tool>  (tool name may also be the route)
--  GET  /testagent/screenshot/<requestId>  (image bytes)
--  Header: Authorization: Bearer <token>
--
--  Response: { requestId, ok, result } or { ok=false, error={code,message,retryable} }
--  NOTE: FiveM HTTP requires req.setDataHandler to receive POST bodies —
--  everything body-dependent lives inside that handler.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetTestAgent.Config

local function sendJson(res, code, payload)
    res.writeHead(code, { ['Content-Type'] = 'application/json' })
    res.send(json.encode(payload))
end

local function sendError(res, requestId, err, httpCode)
    sendJson(res, httpCode or 200, {
        requestId = requestId,
        ok = false,
        error = {
            code = err.code or 'INTERNAL',
            message = err.message or 'Unexpected error',
            retryable = err.retryable == true,
        },
    })
end

-- Latest screenshot bytes per requestId (client uploads, MCP fetches).
local ScreenshotStore = {}   -- [requestId] = { data, mime, at }
local SCREENSHOT_TTL_MS = 120000

local function gcScreenshots()
    local now = GetGameTimer()
    for id, entry in pairs(ScreenshotStore) do
        if now - entry.at > SCREENSHOT_TTL_MS then ScreenshotStore[id] = nil end
    end
end

CreateThread(function()
    while true do
        Wait(30000)
        gcScreenshots()
    end
end)

-- ── Minimal base64 decoder (no stdlib in FXServer Lua) ──
local B64CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local B64MAP = {}
for i = 1, 64 do B64MAP[B64CHARS:sub(i, i)] = i - 1 end

local function base64Decode(data)
    if type(data) ~= 'string' then return nil, 'not a string' end
    local out = {}
    local buf, bits = 0, 0
    for i = 1, #data do
        local c = data:sub(i, i)
        if c == '=' then
            break
        elseif c ~= '\n' and c ~= '\r' and c ~= ' ' then
            local v = B64MAP[c]
            if not v then return nil, ('invalid character %q at %d'):format(c, i) end
            buf = (buf << 6) | v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                out[#out + 1] = string.char((buf >> bits) & 0xFF)
            end
        end
    end
    return table.concat(out)
end

local function runTool(toolName, requestId, body)
    local spec = TestAgentTools[toolName]
    if not spec or type(spec.fn) ~= 'function' then
        return nil, { code = 'INVALID_ARGUMENT', message = 'Unknown tool: ' .. tostring(toolName), retryable = false }
    end
    local target = body.target
    local args = type(body.args) == 'table' and body.args or {}
    local started = TestAgentLog.nowMs()
    local results = { pcall(spec.fn, target, args) }
    local duration = TestAgentLog.nowMs() - started
    local okCall = table.remove(results, 1)
    if not okCall then
        local errMsg = tostring(results[1] or 'internal error')
        TestAgentLog.error('tool %s threw: %s', toolName, errMsg)
        TestAgentLog.invocation(requestId, toolName, tonumber(target), false, 'INTERNAL', duration)
        return nil, { code = 'INTERNAL', message = errMsg, retryable = false }
    end
    local result, toolErr = results[1], results[2]
    if result == nil and type(toolErr) == 'table' and toolErr.code then
        TestAgentLog.invocation(requestId, toolName, tonumber(target), false, toolErr.code, duration)
        return nil, toolErr
    end
    TestAgentLog.invocation(requestId, toolName, tonumber(target), true, nil, duration)
    return result
end

local function header(req, name)
    local h = req.headers or {}
    return h[name] or h[name:lower()] or h[name:gsub('^%a', string.upper)]
end

local function httpHandler(req, res)
    local path = req.path or ''
    TestAgentLog.debug('HTTP request method=%s path=%s', tostring(req.method), path)

    -- Only handle our prefix; everything else 404s.
    if path:sub(1, #Cfg.httpPrefix) ~= Cfg.httpPrefix then
        sendJson(res, 404, { ok = false, error = { code = 'NOT_FOUND', message = 'unknown path', retryable = false } })
        return
    end

    if not TestAgentAuth.enabled() then
        sendJson(res, 403, {
            ok = false,
            error = { code = 'OPERATION_NOT_ALLOWED', message = 'test agent disabled (kill switch)', retryable = false },
        })
        return
    end

    -- ── Ownership probe (NO AUTH — reveals only that sunset_test_agent owns
    -- the game-port handler; used by the self-check loop to detect txAdmin
    -- re-claiming SetHttpHandler). Must come BEFORE the bearer check. ──
    if req.method == 'GET' and path == (Cfg.httpPrefix .. 'ping') then
        sendJson(res, 200, { ok = true, owner = 'sunset_test_agent', at = os.date('%H:%M:%S') })
        return
    end

    local authOk, authErr = TestAgentAuth.checkBearer(header(req, 'Authorization'))
    if not authOk then
        sendError(res, nil, authErr, 401)
        return
    end

    local route = path:sub(#Cfg.httpPrefix + 1)

    -- ── Screenshot download for the MCP client (GET, no body) ──
    if req.method == 'GET' and route:sub(1, 11) == 'screenshot/' then
        local rid = route:sub(12)
        local entry = ScreenshotStore[rid]
        if not entry then
            sendJson(res, 404, { ok = false, error = { code = 'SCREENSHOT_FAILED', message = 'screenshot not found or expired', retryable = true } })
            return
        end
        res.writeHead(200, { ['Content-Type'] = entry.mime })
        res.send(entry.data)
        return
    end

    if req.method == 'GET' and route == 'health' then
        local result, err = runTool('health', 'http_get_health', {})
        if result == nil and err then sendError(res, 'http_get_health', err) return end
        sendJson(res, 200, { requestId = 'http_get_health', ok = true, result = result })
        return
    end

    if req.method ~= 'POST' then
        sendJson(res, 405, { ok = false, error = { code = 'INVALID_ARGUMENT', message = 'use POST', retryable = false } })
        return
    end

    -- ── POST routes: body arrives via setDataHandler ──
    req.setDataHandler(function(body)
        -- Screenshot upload: JSON { requestId, base64, mime }
        if route == 'screenshot' then
            local okJson, decoded = pcall(json.decode, body or '{}')
            if not okJson or type(decoded) ~= 'table' then
                sendError(res, nil, { code = 'INVALID_ARGUMENT', message = 'screenshot body must be JSON', retryable = false })
                return
            end
            local rid = tostring(decoded.requestId or '')
            local mime = tostring(decoded.mime or 'image/jpeg')
            local b64 = tostring(decoded.base64 or '')
            if not TestAgentAuth.hasTestPlayer() then
                sendError(res, rid, { code = 'TEST_PLAYER_NOT_CONNECTED', message = 'no registered test player may upload', retryable = true }, 401)
                return
            end
            if rid == '' or #b64 < 64 or #b64 > 16 * 1024 * 1024 then
                sendError(res, rid, { code = 'SCREENSHOT_FAILED', message = 'screenshot payload invalid', retryable = false })
                return
            end
            local raw, derr = base64Decode(b64)
            if not raw then
                sendError(res, rid, { code = 'SCREENSHOT_FAILED', message = 'base64 decode failed: ' .. tostring(derr), retryable = false })
                return
            end
            gcScreenshots()
            ScreenshotStore[rid] = { data = raw, mime = mime, at = TestAgentLog.nowMs() }
            TestAgentLog.event('screenshot', 'stored', { requestId = rid, bytes = #raw })
            sendJson(res, 200, { ok = true, requestId = rid, bytes = #raw })
            return
        end

        -- Tool invocation
        local okJson, decoded = pcall(json.decode, body or '{}')
        if not okJson or type(decoded) ~= 'table' then
            sendError(res, nil, { code = 'INVALID_ARGUMENT', message = 'body must be JSON', retryable = false })
            return
        end
        local requestId = tostring(decoded.requestId or ('req_' .. GetGameTimer() .. '_' .. math.random(10000, 99999)))
        local toolName = (route == '' or route == 'invoke') and tostring(decoded.tool or '') or route
        if toolName == '' then
            sendError(res, requestId, { code = 'INVALID_ARGUMENT', message = 'tool name required', retryable = false })
            return
        end

        TestAgentLog.debug('HTTP tool=%s requestId=%s', toolName, requestId)
        -- Tools may Yield (RPC awaits) — setDataHandler runs on the HTTP
        -- thread which supports Citizen.Await inside CreateThread only, so
        -- run the tool in a thread and respond from there.
        CreateThread(function()
            local result, err = runTool(toolName, requestId, decoded)
            if result == nil and err then
                sendError(res, requestId, err, err.code == 'UNAUTHORIZED' and 401 or 200)
                return
            end
            sendJson(res, 200, { requestId = requestId, ok = true, result = result })
        end)
    end)
end

-- [HTTP OWNER CONFLICT + BOOT ORDER] Two lessons learned live:
--  1. SetHttpHandler called at script top-level runs DURING environment
--     creation (before "Started resource") and the registration is DROPPED —
--     FXServer keeps answering its default "Route ... not found." The claim
--     must happen from a thread AFTER the resource is fully started.
--  2. txAdmin (monitor) also claims the single handler when enabled; the
--     self-check loop below re-claims when the unauthenticated /ping probe
--     stops answering with our owner marker.
CreateThread(function()
    Wait(2000)
    SetHttpHandler(httpHandler)
    print('^2[TESTAGENT HTTP]^7 SetHttpHandler claimed (post-start)')
    TestAgentLog.event('http', 'SetHttpHandler registered for ' .. Cfg.httpPrefix)
end)

local lastReclaimWarn = 0
CreateThread(function()
    Wait(8000)
    local port = GetConvarInt('sv_port', 30120)
    -- FXServer routes HTTP per-resource: /<resourceName><req.path>. The probe
    -- must include our resource prefix or it never reaches this handler.
    local probeUrl = ('http://127.0.0.1:%d/%s%sping'):format(port, GetCurrentResourceName(), Cfg.httpPrefix)
    while true do
        Wait(20000)
        if TestAgentAuth.enabled() then
            -- Self-probe: do WE still own the game-port HTTP handler?
            local settled = false
            local ownsHandler = false
            local p = promise.new()
            pcall(function()
                PerformHttpRequest(probeUrl,
                    function(status, body)
                        if settled then return end
                        settled = true
                        ownsHandler = status == 200 and type(body) == 'string'
                            and body:find('sunset_test_agent', 1, true) ~= nil
                        p:resolve()
                    end, 'GET')
            end)
            -- Bound the wait so a dropped callback can never wedge the loop.
            SetTimeout(4000, function()
                if settled then return end
                settled = true
                p:resolve()
            end)
            Citizen.Await(p)
            if not ownsHandler then
                SetHttpHandler(httpHandler)
                local now = GetGameTimer()
                if now - lastReclaimWarn > 120000 then
                    lastReclaimWarn = now
                    TestAgentLog.warn('HTTP handler was NOT ours (txAdmin re-claimed?) — re-claimed SetHttpHandler')
                else
                    TestAgentLog.debug('re-claimed HTTP handler (silent)')
                end
            end
        end
    end
end)
