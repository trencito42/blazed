-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield (server/strikes.lua)
--  Tick registry, decay + lazy heat scoring (spec §5).
--  heat = Σ severity × recency_factor
--    <5min ×1.0 | <15min ×0.7 | <30min ×0.4 | expired (dropped)
--  Thresholds: watch=3 suspect=6 critical=10 — staff broadcast on
--  crossing (never auto-sanction; AutoBanAnything stays false).
-- ═══════════════════════════════════════════════════════════════

local Strikes = {}
Anticheat.Strikes = Strikes

local Cfg = SunsetAnticheat.Config

local Ticks = {}          -- [src] = { { detector, severity, measured, context, at, dbId }, ... }
local LastThreshold = {}  -- [src] = highest threshold band already announced
local FpDismiss = {}      -- [detector] = { fired = n, dismissed = n }

-- ── Heat bands ──
local function bandFor(heat)
    if heat >= (Cfg.Heat.critical or 10) then return 'critical' end
    if heat >= (Cfg.Heat.suspect or 6) then return 'suspect' end
    if heat >= (Cfg.Heat.watch or 3) then return 'watch' end
    return 'clean'
end
local BAND_ORDER = { clean = 1, watch = 2, suspect = 3, critical = 4 }

local function recencyFactor(ageSec)
    if ageSec < 300 then return 1.0 end
    if ageSec < 900 then return 0.7 end
    if ageSec < (Cfg.TickLifetimeSec or 1800) then return 0.4 end
    return 0.0
end

-- Lazy heat computation: prunes expired ticks, then sums severity×recency.
function Strikes.GetHeat(src)
    local list = Ticks[tonumber(src or 0)]
    if not list then return 0.0, 0 end
    local now = os.time()
    local heat, count = 0.0, 0
    for i = #list, 1, -1 do
        local age = now - list[i].at
        local factor = recencyFactor(age)
        if factor <= 0.0 then
            table.remove(list, i)
        else
            heat = heat + list[i].severity * factor
            count = count + 1
        end
    end
    if #list == 0 then Ticks[tonumber(src or 0)] = nil end
    return heat, count
end

function Strikes.GetBand(src)
    local heat = Strikes.GetHeat(src)
    return bandFor(heat), heat
end

-- ── Staff broadcast (replicates sunset_admin broadcastStaff pattern,
--    commands.lua ~920: loop GetPlayers + IsAdmin(src,1) + CommandReply) ──
local function broadcastStaff(msg, msgType)
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if s then
            local isStaff = false
            if GetResourceState('sunset_admin') == 'started' then
                local ok, res = pcall(function()
                    return exports.sunset_admin:IsAdmin(s, 1)
                end)
                isStaff = ok and res == true
            end
            if isStaff then
                pcall(function() exports.sunset_core:CommandReply(s, msg, msgType or 'info') end)
            end
        end
    end
end
Strikes.BroadcastStaff = broadcastStaff

local function playerName(src)
    local name = nil
    if GetResourceState('sunset_core') == 'started' then
        pcall(function() name = exports.sunset_core:GetPlayerDisplayName(src) end)
    end
    return name or GetPlayerName(src) or ('#%d'):format(src)
end

local BAND_ICON = { watch = '[WATCH]', suspect = '[SUSPECT]', critical = '[CRITICAL]' }

local function announceThreshold(src, band, heat, tick)
    -- In log_only mode: no staff noise below suspect (still broadcast suspect+
    -- so the rollout week produces tunable signal without spamming helpers).
    if Cfg.Mode == 'log_only' and band == 'watch' then return end
    local msg = ('%s^7 %s %s — heat %.1f — %s: %s'):format(
        band == 'critical' and '^1' or band == 'suspect' and '^3' or '^2',
        BAND_ICON[band] or band:upper(), playerName(src), heat, tick.detector, tick.measured)
    broadcastStaff(msg, 'warning')
    if band == 'critical' then
        broadcastStaff(('^1[SHIELD]^7 %s reached CRITICAL heat. /spectate %d and review with /acheat %d — NO auto-ban, staff decides.'):format(
            playerName(src), src, src), 'warning')
    end
    -- [DISCORD] suspect+ crossings get an embed (rate-limited by the band
    -- crossing logic itself — one embed per player per band climb).
    if Anticheat.Discord then
        pcall(Anticheat.Discord.HeatBand, src, playerName(src), band, heat, tick)
    end
end

-- ── Identity resolution for persistence ──
local function identity(src)
    local charId, accountId, license = nil, nil, nil
    if GetResourceState('sunset_core') == 'started' then
        pcall(function()
            local char = exports.sunset_core:GetCharacter(src)
            if char and char.id then charId = char.id end
            local player = exports.sunset_core:GetPlayer(src)
            if player then
                accountId = player.account_id
                license = player.license
            end
        end)
    end
    return charId, accountId, license
end

-- ── Persist a tick (own domain: anticheat_strikes only) ──
local function persistTick(src, tick, contextSnapshot)
    local charId, accountId, license = identity(src)
    local ctxJson = nil
    local ok, encoded = pcall(json.encode, contextSnapshot or {})
    if ok and encoded then ctxJson = encoded end
    local insertOk, insertId = pcall(MySQL.insert.await,
        'INSERT INTO anticheat_strikes (character_id, account_id, player_name, license, detector, severity, measured, context, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))',
        { charId, accountId, (playerName(src)):sub(1, 64), license, tick.detector, tick.severity,
          (tick.measured or ''):sub(1, 255), ctxJson, os.time() + (Cfg.TickLifetimeSec or 1800) })
    if insertOk then
        tick.dbId = insertId
    else
        print(('[sunset_anticheat] strike persist failed for %s/%s: %s'):format(tostring(src), tick.detector, tostring(insertId)))
    end
end

-- ── Add a tick (the only write path detectors use) ──
function Strikes.AddTick(src, detector, severity, measured, contextSnapshot)
    src = tonumber(src)
    if not src or not Cfg.Enabled then return nil end
    detector = tostring(detector or 'unknown')
    severity = math.max(1, math.min(3, math.floor(tonumber(severity) or 1)))

    local now = os.time()
    local tick = {
        detector = detector,
        severity = severity,
        measured = tostring(measured or ''),
        context = contextSnapshot,
        at = now,
    }
    Ticks[src] = Ticks[src] or {}
    table.insert(Ticks[src], tick)

    FpDismiss[detector] = FpDismiss[detector] or { fired = 0, dismissed = 0 }
    FpDismiss[detector].fired = FpDismiss[detector].fired + 1

    persistTick(src, tick, contextSnapshot)

    local band, heat = Strikes.GetBand(src)
    local prevBand = LastThreshold[src] or 'clean'
    if (BAND_ORDER[band] or 1) > (BAND_ORDER[prevBand] or 1) then
        LastThreshold[src] = band
        announceThreshold(src, band, heat, tick)
    end

    print(('[sunset_anticheat] TICK %s #%d %s sev%d "%s" heat=%.1f band=%s mode=%s'):format(
        detector, src, playerName(src), severity, tick.measured, heat, band, Cfg.Mode))
    return tick
end

-- ── Read APIs (panel / commands) ──
function Strikes.GetTicks(src)
    -- prune first so callers never see expired rows
    Strikes.GetHeat(src)
    return Ticks[tonumber(src or 0)] or {}
end

function Strikes.GetTopDetector(src)
    local counts = {}
    for _, t in ipairs(Strikes.GetTicks(src)) do
        counts[t.detector] = (counts[t.detector] or 0) + 1
    end
    local top, topN = nil, 0
    for name, n in pairs(counts) do
        if n > topN then top, topN = name, n end
    end
    return top, topN
end

function Strikes.GetAllHeats()
    local rows = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            local heat, count = Strikes.GetHeat(src)
            if count > 0 then
                local top = Strikes.GetTopDetector(src)
                rows[#rows + 1] = {
                    src = src, name = playerName(src), heat = heat,
                    ticks = count, band = bandFor(heat), topDetector = top,
                }
            end
        end
    end
    table.sort(rows, function(a, b) return a.heat > b.heat end)
    return rows
end

-- ── DISMISS resolution (GUI export, spec §5) ──
-- Marks every pending tick of a player as a false positive and feeds the
-- per-detector FP counter. A detector whose dismiss rate exceeds 40% gets a
-- tuning warning logged for owners.
function Strikes.DismissAll(src, staffSrc)
    src = tonumber(src)
    if not src then return 0 end
    local list = Ticks[src]
    if not list or #list == 0 then return 0 end
    local n = 0
    local touched = {}
    for _, t in ipairs(list) do
        t.resolved = 'dismissed'
        n = n + 1
        touched[t.detector] = true
        FpDismiss[t.detector] = FpDismiss[t.detector] or { fired = 0, dismissed = 0 }
        FpDismiss[t.detector].dismissed = FpDismiss[t.detector].dismissed + 1
        if t.dbId then
            pcall(MySQL.update.await,
                'UPDATE anticheat_strikes SET resolved = ?, resolved_by = ? WHERE id = ?',
                { 'dismissed', tonumber(staffSrc) or nil, t.dbId })
        end
    end
    Ticks[src] = nil
    LastThreshold[src] = nil
    for detector in pairs(touched) do
        local stats = FpDismiss[detector]
        if stats.fired >= 5 and (stats.dismissed / stats.fired) > 0.40 then
            print(('^3[sunset_anticheat]^7 TUNING WARNING: detector "%s" dismiss rate %d%% (%d/%d) — threshold too sensitive.'):format(
                detector, math.floor(100 * stats.dismissed / stats.fired), stats.dismissed, stats.fired))
            broadcastStaff(('^3[SHIELD TUNING]^7 detector "%s" has a %d%% dismiss rate — needs threshold tuning.'):format(
                detector, math.floor(100 * stats.dismissed / stats.fired)), 'warning')
        end
    end
    return n
end

function Strikes.GetDetectorStats()
    local rows = {}
    for detector, stats in pairs(FpDismiss) do
        rows[#rows + 1] = {
            detector = detector, fired = stats.fired, dismissed = stats.dismissed,
            dismissRate = stats.fired > 0 and (stats.dismissed / stats.fired) or 0.0,
        }
    end
    table.sort(rows, function(a, b) return a.fired > b.fired end)
    return rows
end

AddEventHandler('playerDropped', function()
    local src = source
    Ticks[src] = nil
    LastThreshold[src] = nil
end)

-- ── Exports ──
exports('AddStrike', function(src, detector, severity, measured, contextSnapshot)
    return Strikes.AddTick(src, detector, severity, measured, contextSnapshot)
end)

exports('GetHeat', Strikes.GetHeat)
exports('GetAllHeats', Strikes.GetAllHeats)

exports('DismissStrikes', function(src, staffSrc)
    return Strikes.DismissAll(src, staffSrc)
end)
