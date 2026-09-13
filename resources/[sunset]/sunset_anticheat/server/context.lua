-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield (server/context.lua)
--  Context whitelist engine (spec §3) — the false-positive killer.
--  Every detector calls Anticheat.Context.IsLegit(src, checkType)
--  BEFORE recording a tick, and Snapshot(src) is stored with every
--  tick so staff can see WHY a check would have fired.
-- ═══════════════════════════════════════════════════════════════

Anticheat = Anticheat or {}

local Context = {}
Anticheat.Context = Context

local Cfg = SunsetAnticheat.Config

-- ── MarkLegit registry ──
-- Other resources (or our own detectors/commands) declare "this player is
-- about to do something cheat-looking, legitimately":
--   exports.sunset_anticheat:MarkLegit(src, 'vehicle_spawn', 10)
-- checkType 'all' or nil exempts every check for the window.
local Legit = {}     -- [src] = { [checkType] = expiresAt, ... }

function Context.MarkLegit(src, checkType, seconds)
    src = tonumber(src)
    if not src then return end
    seconds = tonumber(seconds) or 10
    checkType = tostring(checkType or 'all')
    Legit[src] = Legit[src] or {}
    local now = os.time()
    local cur = Legit[src][checkType]
    Legit[src][checkType] = math.max(now + seconds, cur or 0)
end

function Context.ClearLegit(src)
    Legit[tonumber(src or 0)] = nil
end

local function isMarked(src, checkType)
    local entry = Legit[src]
    if not entry then return false end
    local now = os.time()
    for key, expires in pairs(entry) do
        if expires <= now then
            entry[key] = nil
        elseif key == 'all' or key == checkType then
            return true
        end
    end
    return false
end

-- ── Recent admin-action window (spec §3 row 8) ──
-- We cannot edit sunset_admin (parallel work), so this is a PULL registry:
-- sunset_admin can later call exports.sunset_anticheat:MarkAdminAction(src, cmd)
-- whenever it runs /tp /bring /car /givegun /arespawn /slap /spectate.
local AdminActions = {}   -- [src] = { cmd = name, at = os.time() }
local ADMIN_WINDOW_SEC = 10

function Context.MarkAdminAction(src, cmd)
    src = tonumber(src)
    if not src then return end
    AdminActions[src] = { cmd = tostring(cmd or 'admin'), at = os.time() }
end

local function recentAdminAction(src)
    local act = AdminActions[src]
    if not act then return nil end
    if os.time() - act.at > ADMIN_WINDOW_SEC then
        AdminActions[src] = nil
        return nil
    end
    return ('%s %ds ago'):format(act.cmd, os.time() - act.at)
end

-- ── Guarded cross-resource export reads ──
-- Domain rule: READ only, via exports, GetResourceState guard + pcall.
local function callExport(resource, method, ...)
    if GetResourceState(resource) ~= 'started' then return nil end
    local args = table.pack(...)
    local ok, res = pcall(function()
        return exports[resource][method](exports[resource], table.unpack(args, 1, args.n))
    end)
    if not ok then return nil end
    return res
end

local function isAdminToolsActive(src)
    -- sunset_admin keeps noclip/god/speed state CLIENT-side only today
    -- (client/main.lua toggles local flags). There is no server-side export
    -- to query. Until sunset_admin exposes one (or feeds MarkLegit), the
    -- best server-side approximation: admin level >= 2 players running the
    -- admin commands are self-whitelisted through MarkAdminAction hooks that
    -- sunset_admin can add later. Flag admins >= 2 here as a coarse gate:
    -- helpers (level 1) do NOT get a blanket exemption.
    local level = callExport('sunset_admin', 'GetAdminLevel', src)
    return (tonumber(level) or 0) >= 2
end

local function inPropertyBucket(src)
    local bucket = GetPlayerRoutingBucket(src)
    return (tonumber(bucket) or 0) ~= 0
end

local function inWar(src)
    return callExport('sunset_turfs', 'IsInWar', src) == true
end

local function activeSession(src)
    local sess = callExport('sunset_sessions', 'GetSessionBySource', src)
    if type(sess) == 'table' and sess.activity then
        return tostring(sess.activity)
    end
    return nil
end

local function onDuty(src)
    return callExport('sunset_factions', 'IsOnDuty', src) == true
end

local function isDowned(src)
    return callExport('sunset_death', 'IsPlayerDowned', src) == true
end

local function isDeadOrHurt(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return true end
    return (GetEntityHealth(ped) or 0) <= 160
end

local function isPingExempt(src)
    local ping = GetPlayerPing(src) or 0
    return ping > (Cfg.PingExemptMs or 250)
end

-- ── Per-check exemption matrix (spec §3) ──
-- Returns true when the player should be EXEMPT from checkType right now.
function Context.IsLegit(src, checkType)
    src = tonumber(src)
    if not src then return true end
    checkType = tostring(checkType or 'all')

    if not Cfg.Enabled then return true end

    -- Explicit MarkLegit window beats everything.
    if isMarked(src, checkType) then return true end

    -- Admin tools / recent admin action: exempts physics + weapon checks.
    if isAdminToolsActive(src) then
        if checkType == 'speed' or checkType == 'fly' or checkType == 'teleport'
            or checkType == 'damage' or checkType == 'health' then
            return true
        end
    end
    if recentAdminAction(src) then
        if checkType == 'speed' or checkType == 'fly' or checkType == 'teleport'
            or checkType == 'damage' or checkType == 'health' or checkType == 'vehicle_spawn'
            or checkType == 'weapons' or checkType == 'ammo' then
            return true
        end
    end

    -- Lag is not cheating: ALL timing-based checks exempt (spec §3 last row).
    if isPingExempt(src) then return true end

    -- Property routing bucket: teleport/speed/fly jumps are bucket swaps.
    if inPropertyBucket(src) then
        if checkType == 'teleport' or checkType == 'speed' or checkType == 'fly' then
            return true
        end
    end

    -- Turf war participant: war respawn + issued loadouts.
    if inWar(src) then
        if checkType == 'teleport' or checkType == 'weapons' or checkType == 'death_rate' then
            return true
        end
    end

    -- Active framework session (job/robbery/exam/taxi): legit spawns + movement.
    local session = activeSession(src)
    if session then
        if checkType == 'teleport' or checkType == 'vehicle_spawn' or checkType == 'speed'
            or checkType == 'weapons' or checkType == 'ammo' then
            return true
        end
    end

    -- On-duty faction: loadout weapons + patrol driving.
    if onDuty(src) then
        if checkType == 'weapons' or checkType == 'ammo' then return true end
    end

    -- Dead/downed: death system moves bodies; health checks meaningless.
    if isDowned(src) or isDeadOrHurt(src) then
        if checkType == 'health' or checkType == 'speed' or checkType == 'teleport'
            or checkType == 'fly' or checkType == 'damage' then
            return true
        end
    end

    return false
end

-- ── Evidence snapshot stored with every tick (spec §3 closing note) ──
function Context.Snapshot(src)
    src = tonumber(src) or 0
    local snap = {
        bucket = GetPlayerRoutingBucket(src) or 0,
        ping = GetPlayerPing(src) or 0,
        in_war = inWar(src),
        session = activeSession(src),
        on_duty = onDuty(src),
        downed = isDowned(src),
        admin_action = recentAdminAction(src),
        admin_level = tonumber(callExport('sunset_admin', 'GetAdminLevel', src) or 0),
        marked = Legit[src] ~= nil,
    }
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        snap.health = GetEntityHealth(ped)
        snap.armour = GetPedArmour(ped)
        local c = GetEntityCoords(ped)
        snap.coords = { x = c.x, y = c.y, z = c.z }
        snap.weapon = GetSelectedPedWeapon(ped)
    end
    return snap
end

-- ── Player disconnect cleanup ──
AddEventHandler('playerDropped', function()
    local src = source
    Legit[src] = nil
    AdminActions[src] = nil
end)

-- ── Public exports (spec §3: one-line integration per system) ──
exports('MarkLegit', function(src, checkType, seconds)
    Context.MarkLegit(src, checkType, seconds)
end)

exports('MarkAdminAction', function(src, cmd)
    Context.MarkAdminAction(src, cmd)
end)

exports('IsWhitelisted', function(src, checkType)
    return Context.IsLegit(src, checkType)
end)

exports('GetContextSnapshot', function(src)
    return Context.Snapshot(src)
end)
