-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield (server/discord.lua)
--  Discord alerting (spec §9 + ANTICHEAT_SPEC rollout):
--    • suspect/critical heat crossings → embed (channel 'anticheat')
--    • economy injection flag → embed + owner ping
--    • daily summary (detector stats + FP dismiss rates)
--  All sends go through sunset_core:SendDiscordLog (webhook convar
--  discord_webhook_anticheat, fallback discord_webhook_all).
-- ═══════════════════════════════════════════════════════════════

Anticheat = Anticheat or {}

local Discord = {}
Anticheat.Discord = Discord

local Cfg = SunsetAnticheat.Config
local Strikes = Anticheat.Strikes

local function coreReady()
    return GetResourceState('sunset_core') == 'started'
end

local function send(title, description, color, fields)
    if not coreReady() then return end
    if (Cfg.Discord or {}).enabled == false then return end
    pcall(function()
        exports.sunset_core:SendDiscordLog(
            (Cfg.Discord or {}).channel or 'anticheat',
            title, description, color or 'cyan', fields or {})
    end)
end
Discord.Send = send

-- ── Heat-band crossing alert (called from strikes.announceThreshold) ──
function Discord.HeatBand(src, playerName, band, heat, tick)
    if band ~= 'suspect' and band ~= 'critical' then return end
    local color = band == 'critical' and 'red' or 'orange'
    local ctx = tick and tick.context or {}
    send(
        band == 'critical' and '🔴 SHIELD — CRITICAL HEAT' or '🟠 SHIELD — SUSPECT HEAT',
        ('**%s (#%d)** reached **%s** heat.'):format(tostring(playerName), src, band:upper()),
        color,
        {
            { name = 'Heat', value = ('%.1f'):format(heat), inline = true },
            { name = 'Detector', value = tostring(tick and tick.detector or '?'), inline = true },
            { name = 'Severity', value = tostring(tick and tick.severity or '?'), inline = true },
            { name = 'Evidence', value = tostring(tick and tick.measured or '-'):sub(1, 200), inline = false },
            { name = 'Context', value = ('war=%s bucket=%s session=%s duty=%s downed=%s admin=%s ping=%s'):format(
                tostring(ctx.in_war), tostring(ctx.bucket), tostring(ctx.session or '-'),
                tostring(ctx.on_duty), tostring(ctx.downed), tostring(ctx.admin_action or '-'), tostring(ctx.ping)), inline = false },
            { name = 'Review', value = ('`/spectate %d` · `/acheat %d` · NO auto-ban — staff decides'):format(src, src), inline = false },
        })
end

-- ── Economy injection (the ONLY auto-action detector; spec §4.9) ──
function Discord.EconomyInjection(src, playerName, detail, autoKicked)
    send('💸 SHIELD — ECONOMY INJECTION',
        ('**%s (#%d)** — %s%s'):format(
            tostring(playerName), src, tostring(detail),
            autoKicked and '\n*Player was auto-kicked (config). Staff review required.*' or '\n*Auto-kick disabled; staff review required.*'),
        'red',
        {
            { name = 'Action', value = autoKicked and 'AUTO-KICK' or 'FLAG ONLY', inline = true },
            { name = 'Review', value = ('`/acheat %d` · money_transactions ledger'):format(src), inline = true },
        })
end

-- ── Daily summary (every 24 h from server start; spec §9) ──
local LastSummaryAt = os.time()

function Discord.MaybeDailySummary()
    if (Cfg.Discord or {}).dailySummary == false then return end
    if os.time() - LastSummaryAt < 86400 then return end
    LastSummaryAt = os.time()

    local stats = Strikes.GetDetectorStats()
    local totalFired, totalDismissed = 0, 0
    local lines = {}
    for _, s in ipairs(stats) do
        totalFired = totalFired + s.fired
        totalDismissed = totalDismissed + s.dismissed
        lines[#lines + 1] = ('• **%s** — %d fired, %d dismissed (%d%%)'):format(
            s.detector, s.fired, s.dismissed,
            s.fired > 0 and math.floor(100 * s.dismissed / s.fired) or 0)
    end
    local rate = totalFired > 0 and math.floor(100 * totalDismissed / totalFired) or 0
    send('📊 SHIELD — DAILY SUMMARY',
        ('Mode: **%s** · ticks fired: **%d** · dismissed: **%d** (%d%%)\n%s'):format(
            tostring(Cfg.Mode), totalFired, totalDismissed, rate,
            #lines > 0 and table.concat(lines, '\n') or '_No detector activity._'),
        rate > 40 and 'orange' or 'cyan',
        {
            { name = 'Rollout rule', value = rate < 10
                and 'Dismiss rate <10% — eligible for enforce mode after 3 clean days.'
                or 'Dismiss rate >=10% — keep tuning thresholds (log_only).', inline = false },
        })
end

CreateThread(function()
    Wait(60000)
    while true do
        pcall(Discord.MaybeDailySummary)
        Wait(3600000) -- hourly check; sends at most once/24h
    end
end)

print('^5[sunset_anticheat]^7 discord alerting online (suspect+ embeds, economy ping, daily summary)')
