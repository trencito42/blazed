-- ============================================================
--  sunset_admintools server — admin gate + telemetry collector
--  All commands require sunset_admin level 3+. Console (src 0)
--  always allowed. Tools run CLIENT-side; this server only
--  validates the caller and aggregates per-player resmon data.
-- ============================================================

local function isAdmin(source, level)
    if source == 0 then return true end
    if GetResourceState('sunset_admin') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.sunset_admin:IsAdmin(source, level or 3) end)
    return ok and res == true
end

exports('IsAdminAllowed', isAdmin)

-- Client-side admin gate for tool commands (/inspect, /cinematic).
exports.sunset_core:RegisterCallback('sunset:admintools:check', function(source)
    return isAdmin(source, 3)
end)

-- Collected client profiler reports: [src] = latest sample
local Reports = {}

RegisterNetEvent('sunset:admintools:report', function(payload)
    local src = source
    if not isAdmin(src, 3) then return end
    if type(payload) ~= 'table' then return end
    Reports[src] = {
        at = os.time(),
        resmon = tonumber(payload.resmon) or 0,
        entities = tonumber(payload.entities) or 0,
        vehicles = tonumber(payload.vehicles) or 0,
        peds = tonumber(payload.peds) or 0,
        objects = tonumber(payload.objects) or 0,
        fps = tonumber(payload.fps) or 0,
    }
end)

AddEventHandler('playerDropped', function()
    Reports[source] = nil
end)

-- /blzresmon [seconds] - ask all online clients for a sample, print table.
-- [RENAME 2] Both "profiler" AND "resmon" are BUILT-IN FiveM console commands
-- disabled in production mode, so they shadowed ours. The blz prefix avoids
-- every current and future CFX builtin collision.
RegisterCommand('blzresmon', function(source, args)
    if not isAdmin(source, 3) then
        if source ~= 0 then TriggerClientEvent('sunset:client:notify', source, 'Admin level 3+ required.', 'error') end
        return
    end
    Reports = {}
    TriggerClientEvent('sunset:admintools:sampler', -1, math.min(30, math.max(3, tonumber(args[1]) or 5)))
    SetTimeout((math.min(30, math.max(3, tonumber(args[1]) or 5)) + 2) * 1000, function()
        local lines = {}
        lines[#lines + 1] = ('%-6s %-20s %8s %6s %6s %6s %6s %6s'):format(
            'SRC', 'NAME', 'RESMON', 'FPS', 'ENTS', 'VEHS', 'PEDS', 'OBJS')
        local total = 0
        for src, r in pairs(Reports) do
            total = total + 1
            lines[#lines + 1] = ('%-6d %-20s %8.2f %6d %6d %6d %6d %6d'):format(
                src, (GetPlayerName(src) or '?'):sub(1, 20), r.resmon, r.fps,
                r.entities, r.vehicles, r.peds, r.objects)
        end
        if total == 0 then
            lines[#lines + 1] = 'No client reports received (no players online or clients outdated).'
        end
        table.sort(lines)
        for _, line in ipairs(lines) do
            if source == 0 then print(line) else TriggerClientEvent('chat:addMessage', source, { color = { 0, 255, 204 }, args = { 'BLZRESMON', line } }) end
        end
    end)
end, false)

-- /sweeporphans — ask every client to delete orphaned mission entities
-- that belong to no player session (see client/inspector.lua for criteria).
RegisterCommand('sweeporphans', function(source, args)
    if not isAdmin(source, 3) then
        if source ~= 0 then TriggerClientEvent('sunset:client:notify', source, 'Admin level 3+ required.', 'error') end
        return
    end
    local dryRun = args[1] ~= 'force'
    TriggerClientEvent('sunset:admintools:sweep', -1, dryRun)
    if source ~= 0 then
        TriggerClientEvent('sunset:client:notify', source,
            dryRun and 'Orphan sweep: DRY RUN (report only). Use /sweeporphans force to delete.' or 'Orphan sweep: FORCE delete running on all clients.',
            'info', 8000)
    end
end, false)

print('^2[sunset_admintools]^7 admin diagnostics online (blzresmon / inspector / sweeporphans / cinematic)')
