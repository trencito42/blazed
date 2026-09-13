-- ═══════════════════════════════════════════════════════════════
--  ADMIN HELPDESK — advanced staff panel (level 1+: helpers & admins)
--  Aggregates everything a staffer needs in ONE screen:
--    • player roster: id/name/level/ping/health/vehicle/downed/jailed
--    • Blaze Shield heat per player (pull, read-only export)
--    • live report/helpme tickets (claim/close)
--    • quick actions: tp/bring/heal/revive/freeze/slap/spectate/warn/kick
--  Panel refresh: client polls via callback every 2 s while open.
-- ═══════════════════════════════════════════════════════════════

local OpenPanels = {} -- [src] = true

local function adminLevel(src)
    if GetResourceState('sunset_admin') ~= 'started' then return 0 end
    local ok, lvl = pcall(function() return exports.sunset_admin:GetAdminLevel(src) end)
    return ok and tonumber(lvl) or 0
end

local function heatInfo(src)
    if GetResourceState('sunset_anticheat') ~= 'started' then return nil end
    local ok, res = pcall(function()
        local heat, count = exports.sunset_anticheat:GetHeat(src)
        return { heat = heat, ticks = count }
    end)
    if not ok or type(res) ~= 'table' then return nil end
    local band = 'clean'
    local h = tonumber(res.heat) or 0
    local cfg = SunsetAnticheat and SunsetAnticheat.Config and SunsetAnticheat.Config.Heat or { watch = 3, suspect = 6, critical = 10 }
    if h >= (cfg.critical or 10) then band = 'critical'
    elseif h >= (cfg.suspect or 6) then band = 'suspect'
    elseif h >= (cfg.watch or 3) then band = 'watch' end
    res.band = band
    return res
end

local function buildRoster()
    local rows = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            local ped = GetPlayerPed(src)
            local health = 0
            local inVehicle = false
            local coords = nil
            if ped and ped ~= 0 then
                health = GetEntityHealth(ped) or 0
                local veh = GetVehiclePedIsIn(ped, false)
                inVehicle = veh ~= nil and veh ~= 0
                local c = GetEntityCoords(ped)
                coords = { x = c.x, y = c.y, z = c.z }
            end
            local char = exports.sunset_core:GetCharacter(src)
            local money = nil
            if char then
                money = { cash = tonumber(char.cash) or 0, bank = tonumber(char.bank) or 0 }
            end
            local downed = false
            pcall(function() downed = exports.sunset_death:IsPlayerDowned(src) == true end)
            local jailed = false
            pcall(function() jailed = exports.sunset_factions:IsJailed(src) == true end)
            local frozen = false
            pcall(function() frozen = exports.sunset_admin:IsFrozen(src) == true end)
            local heat = heatInfo(src)

            rows[#rows + 1] = {
                src = src,
                name = exports.sunset_core:GetPlayerDisplayName(src) or GetPlayerName(src) or '?',
                adminLevel = adminLevel(src),
                ping = GetPlayerPing(src) or 0,
                health = health,
                inVehicle = inVehicle,
                coords = coords,
                money = money,
                downed = downed,
                jailed = jailed,
                frozen = frozen,
                heat = heat,
                charId = char and tonumber(char.id) or nil,
            }
        end
    end
    table.sort(rows, function(a, b)
        local ha = a.heat and a.heat.heat or 0
        local hb = b.heat and b.heat.heat or 0
        if ha ~= hb then return ha > hb end -- heat first
        return a.src < b.src
    end)
    return rows
end

exports.sunset_core:RegisterCallback('sunset:helpdesk:panel', function(source)
    if adminLevel(source) < 1 then return nil, 'Staff only.' end
    OpenPanels[source] = true

    local reports = {}
    pcall(function() reports = exports.sunset_admin:GetActiveReports() or {} end)

    local shield = nil
    if GetResourceState('sunset_anticheat') == 'started' then
        local ok, res = pcall(function() return exports.sunset_anticheat:GetPanelSummary() end)
        if ok and type(res) == 'table' then shield = res end
    end

    return {
        myLevel = adminLevel(source),
        myName = GetPlayerName(source),
        playerCount = #GetPlayers(),
        maxPlayers = GetConvarInt('sv_maxclients', 64),
        roster = buildRoster(),
        reports = reports,
        shield = shield,
        time = os.date('%H:%M:%S'),
    }
end)

-- Panel actions — thin router over the existing, permission-checked commands.
-- NEVER bypasses requirePerm: every action re-checks the level via the same
-- config table, so a helper cannot escalate through the panel.
exports.sunset_core:RegisterCallback('sunset:helpdesk:action', function(source, action, targetId, extra)
    if adminLevel(source) < 1 then return nil, 'Staff only.' end
    targetId = tonumber(targetId)
    action = tostring(action or '')

    local Actions = SunsetAdmin and SunsetAdmin.Actions
    local Handlers = SunsetAdmin and SunsetAdmin.ServerHandlers
    local function runCmd(name, args)
        local h = Handlers and Handlers[name]
        if not h then return nil, ('Command %s unavailable.'):format(name) end
        h(source, args or {})
        return true
    end

    if action == 'tp' then return runCmd('tp', { tostring(targetId) }) end
    if action == 'bring' then return runCmd('bring', { tostring(targetId) }) end
    if action == 'tpcar' then return runCmd('tpcar', { tostring(targetId) }) end
    if action == 'heal' then return runCmd('heal', { tostring(targetId) }) end
    if action == 'revive' then return runCmd('revive', { tostring(targetId) }) end
    if action == 'arespawn' then return runCmd('arespawn', { tostring(targetId) }) end
    if action == 'freeze' then return runCmd('freeze', { tostring(targetId) }) end
    if action == 'unfreeze' then return runCmd('unfreeze', { tostring(targetId) }) end
    if action == 'slap' then return runCmd('slap', { tostring(targetId) }) end
    if action == 'pullout' then return runCmd('pullout', { tostring(targetId) }) end
    if action == 'spectate' then return runCmd('spectate', { tostring(targetId) }) end
    if action == 'spectateOff' then return runCmd('spectate', { 'off' }) end
    if action == 'warn' then
        return runCmd('warn', { tostring(targetId), tostring(extra and extra.reason or 'No reason given') })
    end
    if action == 'kick' then
        return runCmd('kick', { tostring(targetId), tostring(extra and extra.reason or 'Kicked by staff') })
    end
    if action == 'history' then
        -- panel-shaped history (Sanctions.history prints to chat instead)
        if not targetId or not GetPlayerName(targetId) then return nil, 'Player not online.' end
        local ident = GetPlayerIdentifierByType(targetId, 'license')
        local rows = {}
        if ident then
            rows = MySQL.query.await([[
                SELECT action, admin_name, reason, duration_min, created_at
                FROM admin_sanctions
                WHERE target_license = ?
                ORDER BY created_at DESC LIMIT 10
            ]], { ident }) or {}
        end
        return rows
    end
    if action == 'dismissHeat' then
        if GetResourceState('sunset_anticheat') ~= 'started' then return nil, 'Anticheat offline.' end
        local ok, res = pcall(function()
            return exports.sunset_anticheat:DismissStrikes(targetId, source)
        end)
        if not ok then return nil, 'Could not dismiss.' end
        return { dismissed = res }
    end
    if action == 'evidence' then
        -- live tick evidence for the panel's detail column
        if GetResourceState('sunset_anticheat') ~= 'started' then return { ticks = {} } end
        local ok, res = pcall(function()
            return exports.sunset_anticheat:GetTicksForPanel(targetId)
        end)
        return ok and res or { ticks = {} }
    end
    if action == 'claimReport' or action == 'closeReport' then
        return runCmd(action == 'claimReport' and 'ar' or 'cr', { tostring(targetId) })
    end

    return nil, ('Unknown helpdesk action "%s".'):format(action)
end)

AddEventHandler('playerDropped', function()
    OpenPanels[tonumber(source)] = nil
end)

print('^2[sunset_admin]^7 helpdesk panel online (roster + heat + reports + quick actions)')
