-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield (server/main.lua)
--  Wiring: boot banner, staff commands (/acheat /achud), core
--  callbacks for the future NUI panel. Phase-1 GUI is chat-based:
--  TriggerClientEvent('chat:addMessage') lines rendered by the
--  sunset_chat shim (same pattern as sunset_admintools/turfs).
--  In Mode='log_only' everything here is passive — detectors only
--  DB-record; no staff broadcasts below suspect heat (strikes.lua).
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetAnticheat.Config
local Strikes = Anticheat.Strikes
local Context = Anticheat.Context

local TAG = 'SHIELD'
local COLOR = { 0, 255, 204 }

local function shieldLine(src, text)
    TriggerClientEvent('chat:addMessage', src, { color = COLOR, args = { TAG, text } })
end

local function isStaff(src)
    if GetResourceState('sunset_admin') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.sunset_admin:IsAdmin(src, 1) end)
    return ok and res == true
end

local function bandLabel(band, heat)
    if band == 'critical' then return ('^1CRITICAL (%.1f)^7'):format(heat) end
    if band == 'suspect' then return ('^3SUSPECT (%.1f)^7'):format(heat) end
    if band == 'watch' then return ('^2WATCH (%.1f)^7'):format(heat) end
    return ('CLEAN (%.1f)'):format(heat)
end

-- ── /acheat [id] — Phase-1 staff GUI over chat lines ──
RegisterCommand('acheat', function(source, args)
    if source ~= 0 and not isStaff(source) then
        pcall(function() exports.sunset_core:CommandDenyAdmin(source, 'acheat') end)
        return
    end

    local targetId = tonumber(args[1])
    if targetId then
        -- Player detail: ticks + evidence + context + quick stats.
        if not GetPlayerName(targetId) then
            if source == 0 then print('[SHIELD] No such player.') else shieldLine(source, ('No player #%d online.'):format(targetId)) end
            return
        end
        local heat, count = Strikes.GetHeat(targetId)
        local band = Strikes.GetBand(targetId)
        local name = GetPlayerName(targetId)
        local lines = {
            ('=== %s (#%d) — %s ==='):format(name, targetId, bandLabel(band, heat)),
            ('Ping %d ms | Ticks active %d'):format(GetPlayerPing(targetId) or 0, count),
        }
        local tel = Anticheat.Detectors.GetTelemetry(targetId)
        if tel then
            lines[#lines + 1] = ('Client sampler: %s | FPS ~%d'):format(
                tel.at and (os.time() - tel.at <= 5) and 'ONLINE' or 'STALE', tel.fps or 0)
        else
            lines[#lines + 1] = 'Client sampler: NO DATA (module not responding?)'
        end
        for _, t in ipairs(Strikes.GetTicks(targetId)) do
            lines[#lines + 1] = ('- [%ds ago] %s sev%d: %s'):format(os.time() - t.at, t.detector, t.severity, t.measured)
            if type(t.context) == 'table' then
                local ctx = t.context
                lines[#lines + 1] = ('    ctx: war=%s bucket=%s session=%s duty=%s downed=%s admin=%s ping=%s'):format(
                    tostring(ctx.in_war), tostring(ctx.bucket), tostring(ctx.session or '-'),
                    tostring(ctx.on_duty), tostring(ctx.downed), tostring(ctx.admin_action or '-'), tostring(ctx.ping))
            end
        end
        if count == 0 then lines[#lines + 1] = 'No active ticks.' end
        for _, line in ipairs(lines) do
            if source == 0 then print(line) else shieldLine(source, line) end
        end
        return
    end

    -- No arg: top-heat player list.
    local rows = Strikes.GetAllHeats()
    if source == 0 then
        print(('[SHIELD] mode=%s watching=%d'):format(Cfg.Mode, #rows))
        for _, r in ipairs(rows) do
            print(('  %s (#%d) heat %.1f %s ticks=%d top=%s'):format(r.name, r.src, r.heat, r.band, r.ticks, tostring(r.topDetector)))
        end
        return
    end
    shieldLine(source, ('Blaze Shield — mode: %s | players with ticks: %d'):format(Cfg.Mode, #rows))
    local shown = 0
    for _, r in ipairs(rows) do
        if shown >= 10 then
            shieldLine(source, ('... and %d more.'):format(#rows - shown))
            break
        end
        shieldLine(source, ('%s (#%d) — %s — %d ticks, top: %s — /acheat %d'):format(
            r.name, r.src, bandLabel(r.band, r.heat), r.ticks, tostring(r.topDetector or '-'), r.src))
        shown = shown + 1
    end
    if shown == 0 then shieldLine(source, 'Nobody has active ticks. All clean.') end
end, false)

-- ── /achud — on-screen Blaze Shield widget (bZone-style corner HUD).
--    Toggles a per-admin push feed: suspect+ players update every 3 s. ──
local HudEnabled = {} -- [src] = true

local function pushHud(src)
    local rows = Strikes.GetAllHeats()
    local feed = {}
    for _, r in ipairs(rows) do
        if r.band == 'suspect' or r.band == 'critical' then
            feed[#feed + 1] = {
                src = r.src, name = r.name, heat = math.floor(r.heat * 10) / 10,
                band = r.band, ticks = r.ticks, top = r.topDetector or '?',
            }
        end
    end
    TriggerClientEvent('sunset:anticheat:shieldHud', src, {
        enabled = true,
        mode = Cfg.Mode,
        watching = #rows,
        feed = feed,
    })
end

RegisterCommand('achud', function(source)
    if source ~= 0 and not isStaff(source) then
        pcall(function() exports.sunset_core:CommandDenyAdmin(source, 'achud') end)
        return
    end
    if source == 0 then
        -- console: print the feed once (no HUD possible)
        local rows = Strikes.GetAllHeats()
        print(('[SHIELD HUD] watching: %d'):format(#rows))
        for _, r in ipairs(rows) do
            if r.band == 'suspect' or r.band == 'critical' then
                print(('  [%s] %s (#%d) heat %.1f x%d top=%s'):format(
                    r.band:upper(), r.name, r.src, r.heat, r.ticks, tostring(r.topDetector or '?')))
            end
        end
        return
    end
    HudEnabled[source] = not HudEnabled[source] or nil
    if HudEnabled[source] then
        pushHud(source)
        TriggerClientEvent('sunset:anticheat:shieldHudToggle', source, true)
    else
        TriggerClientEvent('sunset:anticheat:shieldHudHide', source)
        TriggerClientEvent('sunset:anticheat:shieldHudToggle', source, false)
    end
end, false)

AddEventHandler('playerDropped', function()
    HudEnabled[tonumber(source)] = nil
end)

-- Live feed pusher (3 s) — only while at least one admin has the HUD on.
CreateThread(function()
    while true do
        Wait(3000)
        local any = false
        for src in pairs(HudEnabled) do
            if GetPlayerName(src) then
                any = true
                pcall(pushHud, src)
            else
                HudEnabled[src] = nil
            end
        end
        if not any then Wait(2000) end
    end
end)

-- ── Callbacks for the future NUI panel (level 1+) ──
exports.sunset_core:RegisterCallback('sunset:anticheat:panel', function(source, targetId)
    if not isStaff(source) then return nil, 'Staff only.' end
    local result = {
        mode = Cfg.Mode,
        players = Strikes.GetAllHeats(),
        detectorStats = Strikes.GetDetectorStats(),
    }
    targetId = tonumber(targetId)
    if targetId and GetPlayerName(targetId) then
        local heat, count = Strikes.GetHeat(targetId)
        local band = Strikes.GetBand(targetId)
        result.selected = {
            src = targetId,
            name = GetPlayerName(targetId),
            heat = heat, ticks = count, band = band,
            ping = GetPlayerPing(targetId) or 0,
            list = Strikes.GetTicks(targetId),
            telemetry = Anticheat.Detectors.GetTelemetry(targetId),
        }
    end
    return result
end)

exports.sunset_core:RegisterCallback('sunset:anticheat:dismiss', function(source, targetId)
    if not isStaff(source) then return nil, 'Staff only.' end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not online.' end
    local n = Strikes.DismissAll(targetId, source)
    if n > 0 then
        Strikes.BroadcastStaff(('^2[SHIELD]^7 %s dismissed %d tick(s) for %s (#%d) as false positive.'):format(
            GetPlayerName(source) or '?', n, GetPlayerName(targetId), targetId), 'info')
    end
    return { dismissed = n }
end)

-- ── Summary export for the admin helpdesk panel (read-only) ──
exports('GetPanelSummary', function()
    local heats = Strikes.GetAllHeats()
    local suspect, critical = 0, 0
    for _, r in ipairs(heats) do
        if r.band == 'critical' then critical = critical + 1
        elseif r.band == 'suspect' then suspect = suspect + 1 end
    end
    return {
        mode = Cfg.Mode,
        watching = #heats,
        suspect = suspect,
        critical = critical,
        autoBan = Cfg.AutoBanAnything == true,
    }
end)

-- ── Tick evidence for the helpdesk panel detail column ──
exports('GetTicksForPanel', function(targetId)
    targetId = tonumber(targetId)
    local out = {}
    if not targetId then return { ticks = out } end
    local now = os.time()
    for _, t in ipairs(Strikes.GetTicks(targetId)) do
        out[#out + 1] = {
            detector = t.detector,
            severity = t.severity,
            measured = t.measured,
            context = t.context,
            ageSec = now - t.at,
        }
    end
    return { ticks = out }
end)

-- ── Boot banner ──
CreateThread(function()
    Wait(500)
    print('^5[sunset_anticheat]^7 Blaze Shield online — mode: ^3' .. tostring(Cfg.Mode) .. '^7 | auto-ban: ' ..
        tostring(Cfg.AutoBanAnything) .. ' (must stay false) | detectors: speed, teleport, fly, damage, health, spam, heartbeat, weapon ledger, ammo, vehspawn, economy')
    if Cfg.AutoBanAnything then
        print('^1[sunset_anticheat]^7 FATAL: AutoBanAnything must NEVER be true (spec §1). Disabling resource.')
        Cfg.Enabled = false
    end
end)
