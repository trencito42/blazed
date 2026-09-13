-- ═══════════════════════════════════════════════════════════════
--  ADMIN PRESENCE TOOLS — freeze/slap/spectate/pullout/tpcar/
--  bringcar/ajail/aunjail/aclear/mass tools/gotoid/setclan.
--  (ADMIN_SYSTEM_SPEC.md §4). Server-authoritative; client does the
--  physical work via TriggerClientEvent.
-- ═══════════════════════════════════════════════════════════════

local hasPerm, notify, requirePerm, getTarget, guardSelfTarget, resolveTarget, registerServerCommand

-- injected by commands.lua via SunsetAdmin.ActionsInit (see bottom of commands.lua)
local A = {}

local Frozen = {} -- [target] = { by = adminSrc, at = os.time() }

local function adminLevelOf(src)
    if src == 0 then return 99 end
    local ok, lvl = pcall(function() return exports.sunset_admin:GetAdminLevel(src) end)
    return ok and tonumber(lvl) or 0
end

local function markAnticheat(src, cmd)
    if GetResourceState('sunset_anticheat') == 'started' then
        pcall(function() exports.sunset_anticheat:MarkAdminAction(src, cmd) end)
    end
end

local function targetInProperty(target)
    local bucket = GetPlayerRoutingBucket(target)
    return bucket and bucket ~= 0
end

-- ── /freeze · /unfreeze (level 1) ──────────────────────────────
function A.freeze(source, args)
    if source ~= 0 and not requirePerm(source, 'freeze') then return end
    local target = getTarget(source, args[1], 'Usage: /freeze [player id]')
    if not target or not guardSelfTarget(source, target, args[1], 'freeze') then return end
    if adminLevelOf(target) >= adminLevelOf(source) and source ~= 0 then
        notify(source, 'You cannot freeze a staff member of your level or higher.', 'error')
        return
    end
    if Frozen[target] then
        notify(source, ('#%d is already frozen (by #%s).'):format(target, tostring(Frozen[target].by)), 'info')
        return
    end
    Frozen[target] = { by = source, at = os.time() }
    TriggerClientEvent('sunset:admin:freeze', target, true)
    TriggerClientEvent('sunset:client:notify', target, 'You have been frozen by staff. Stay where you are.', 'error', 10000)
    notify(source, ('Froze #%d (%s). /unfreeze %d to release.'):format(
        target, GetPlayerName(target) or '?', target), 'success')
    pcall(function() exports.sunset_admin:BroadcastStaff(('[ADMIN] %s froze #%d (%s)')
        :format(GetPlayerName(source) or 'console', target, GetPlayerName(target) or '?')) end)
    markAnticheat(target, 'freeze')
end

function A.unfreeze(source, args)
    if source ~= 0 and not requirePerm(source, 'unfreeze') then return end
    local target = getTarget(source, args[1], 'Usage: /unfreeze [player id]')
    if not target then return end
    if not Frozen[target] then
        notify(source, ('#%d is not frozen.'):format(target), 'info')
        return
    end
    Frozen[target] = nil
    TriggerClientEvent('sunset:admin:freeze', target, false)
    TriggerClientEvent('sunset:client:notify', target, 'You have been unfrozen by staff.', 'success', 6000)
    notify(source, ('Unfroze #%d.'):format(target), 'success')
end

-- failsafes: never leave a player frozen forever
AddEventHandler('playerDropped', function()
    local src = source
    if Frozen[src] then Frozen[src] = nil end
end)

CreateThread(function()
    local maxSec = tonumber(SunsetAdmin.FreezeMaxSec) or 600
    while true do
        Wait(30000)
        local now = os.time()
        for target, row in pairs(Frozen) do
            if not GetPlayerName(target) then
                Frozen[target] = nil
            elseif now - (row.at or 0) > maxSec then
                Frozen[target] = nil
                TriggerClientEvent('sunset:admin:freeze', target, false)
                TriggerClientEvent('sunset:client:notify', target, 'Auto-unfrozen (staff timeout).', 'info', 6000)
                pcall(function() exports.sunset_admin:BroadcastStaff(('[ADMIN] auto-unfroze #%d after %ds')
                    :format(target, maxSec)) end)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for target in pairs(Frozen) do
        TriggerClientEvent('sunset:admin:freeze', target, false)
    end
    Frozen = {}
end)

exports('IsFrozen', function(src) return Frozen[tonumber(src or -1)] ~= nil end)

-- ── /slap (level 2) ────────────────────────────────────────────
function A.slap(source, args)
    if source == 0 then return end
    if not requirePerm(source, 'slap') then return end
    local target = getTarget(source, args[1], 'Usage: /slap [player id]')
    if not target or not guardSelfTarget(source, target, args[1], 'slap') then return end
    if GetResourceState('sunset_death') == 'started' then
        local ok, downed = pcall(function() return exports.sunset_death:IsPlayerDowned(target) end)
        if ok and downed then
            notify(source, 'Cannot slap a downed player.', 'error')
            return
        end
    end
    TriggerClientEvent('sunset:admin:slap', target, source)
    TriggerClientEvent('sunset:client:notify', target,
        ('You were slapped by %s. Behave.'):format(GetPlayerName(source) or 'staff'), 'warning', 8000)
    notify(source, ('Slapped #%d.'):format(target), 'success')
    markAnticheat(target, 'slap')
end

-- ── /pullout (level 1) ─────────────────────────────────────────
function A.pullout(source, args)
    if source ~= 0 and not requirePerm(source, 'pullout') then return end
    local target = getTarget(source, args[1], 'Usage: /pullout [player id]')
    if not target then return end
    TriggerClientEvent('sunset:admin:pullout', target)
    notify(source, ('Pulled #%d out of their vehicle.'):format(target), 'success')
end

-- ── /spectate (level 2) ────────────────────────────────────────
local Spectating = {} -- [adminSrc] = target
local SavedBucket = {} -- [adminSrc] = bucket before we moved them (spectate/tpcar/bringcar)

-- [G7 FIX] Leaving a borrowed routing bucket must also release the property
-- registry, otherwise sunset_properties.Inside desyncs from the real bucket.
local function restoreBucket(src, bucket)
    if not GetPlayerName(src) then return end
    if GetResourceState('sunset_properties') == 'started' then
        pcall(function() exports.sunset_properties:LeaveProperty(src) end)
    end
    SetPlayerRoutingBucket(src, tonumber(bucket) or 0)
end

function A.spectate(source, args)
    if source == 0 then return end
    if not requirePerm(source, 'spectate') then return end
    local arg = args[1] and string.lower(tostring(args[1]))

    -- exit mode
    if not arg or arg == 'off' or arg == 'stop' then
        if Spectating[source] then
            Spectating[source] = nil
            -- [G7 FIX] return the admin to their original bucket (usually 0)
            restoreBucket(source, SavedBucket[source])
            SavedBucket[source] = nil
            TriggerClientEvent('sunset:admin:spectateEnd', source)
            notify(source, 'Spectate ended.', 'info')
        else
            notify(source, 'You are not spectating anyone.', 'info')
        end
        return
    end

    local target = getTarget(source, arg, 'Usage: /spectate [player id|off]')
    if not target then return end
    if target == source then
        notify(source, 'You cannot spectate yourself.', 'error')
        return
    end
    Spectating[source] = target
    SavedBucket[source] = GetPlayerRoutingBucket(source) or 0
    -- [G7 FIX] join the target's routing bucket so properties are visible.
    local bucket = GetPlayerRoutingBucket(target) or 0
    SetPlayerRoutingBucket(source, bucket)
    TriggerClientEvent('sunset:admin:spectateStart', source, target)
    notify(source, ('Now spectating #%d (%s). /spectate off to exit.'):format(
        target, GetPlayerName(target) or '?'), 'success', 8000)
    pcall(function() exports.sunset_admin:BroadcastStaff(('[ADMIN] %s started spectating #%d (%s)')
        :format(GetPlayerName(source) or '?', target, GetPlayerName(target) or '?')) end)
    markAnticheat(source, 'spectate')
end

-- watchdog: end spectate when target drops
AddEventHandler('playerDropped', function()
    local src = source
    for admin, target in pairs(Spectating) do
        if target == src and GetPlayerName(admin) then
            Spectating[admin] = nil
            restoreBucket(admin, SavedBucket[admin])
            SavedBucket[admin] = nil
            TriggerClientEvent('sunset:admin:spectateEnd', admin)
            TriggerClientEvent('sunset:client:notify', admin, 'Spectate ended (target disconnected).', 'info')
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for admin in pairs(Spectating) do
        restoreBucket(admin, SavedBucket[admin])
        TriggerClientEvent('sunset:admin:spectateEnd', admin)
    end
    Spectating = {}
    SavedBucket = {}
end)

-- 1Hz coords sync while spectating (client cam follows target).
CreateThread(function()
    while true do
        Wait(1000)
        for admin, target in pairs(Spectating) do
            if GetPlayerName(admin) and GetPlayerName(target) then
                local ped = GetPlayerPed(target)
                if ped and ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    TriggerClientEvent('sunset:admin:spectateSync', admin, target,
                        { x = coords.x, y = coords.y, z = coords.z })
                end
            else
                Spectating[admin] = nil
            end
        end
    end
end)

exports('IsSpectating', function(src) return Spectating[tonumber(src or -1)] ~= nil end)

-- ── /tpcar · /bringcar (level 2) ───────────────────────────────
-- G6: move the WHOLE vehicle, not just the ped. G7: bucket normalization.
local function safeTpCoordsFor(target)
    local ped = GetPlayerPed(target)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    -- [G7] If the target is inside a property bucket, warn and use their
    -- coords anyway but normalize OUR bucket to theirs; the client-side move
    -- keeps the admin visible. (Property-entrance redirect = phase 2.)
    return coords
end

function A.tpcar(source, args)
    if source == 0 then return end
    if not requirePerm(source, 'tpcar') then return end
    local target = getTarget(source, args[1], 'Usage: /tpcar [player id]')
    if not target then return end
    local coords = safeTpCoordsFor(target)
    if not coords then
        notify(source, 'Could not resolve the target position.', 'error')
        return
    end
    if targetInProperty(target) then
        notify(source, 'Target is inside a property — joining their routing bucket. /tpback to return.', 'warning')
        if SavedBucket[source] == nil then SavedBucket[source] = GetPlayerRoutingBucket(source) or 0 end
    end
    SetPlayerRoutingBucket(source, GetPlayerRoutingBucket(target) or 0)
    TriggerClientEvent('sunset:admin:teleportVehicle', source, coords.x, coords.y, coords.z)
    markAnticheat(source, 'tpcar')
end

function A.bringcar(source, args)
    if source == 0 then return end
    if not requirePerm(source, 'bringcar') then return end
    local target = getTarget(source, args[1], 'Usage: /bringcar [player id]')
    if not target or not guardSelfTarget(source, target, args[1], 'bringcar') then return end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    if targetInProperty(source) then
        notify(source, 'You are inside a property — target joins your routing bucket.', 'warning')
    end
    -- [G7 FIX] If the target is inside a property, release their registry entry
    -- first, otherwise sunset_properties.Inside keeps a ghost record and their
    -- bucket silently desyncs from where they actually are.
    if targetInProperty(target) then
        if GetResourceState('sunset_properties') == 'started' then
            pcall(function() exports.sunset_properties:LeaveProperty(target) end)
        end
        TriggerClientEvent('sunset:client:notify', target, 'You were pulled out of a property by staff.', 'warning')
    end
    SetPlayerRoutingBucket(target, GetPlayerRoutingBucket(source) or 0)
    TriggerClientEvent('sunset:admin:teleportVehicle', target, coords.x + 2.0, coords.y + 2.0, coords.z)
    notify(source, ('Brought #%d (with their vehicle) to you.'):format(target), 'success')
    TriggerClientEvent('sunset:client:notify', target, 'You were brought to an admin.', 'warning')
    markAnticheat(target, 'bringcar')
end

-- ── /tpback — restore the bucket you had before spectate/tpcar/bringcar (level 2) ──
function A.tpback(source, args)
    if source == 0 then return end
    if not requirePerm(source, 'tpback') then return end
    local saved = SavedBucket[source]
    if saved == nil then
        -- Nothing saved: still useful as an escape hatch if stuck in a weird bucket.
        if (GetPlayerRoutingBucket(source) or 0) ~= 0 then
            restoreBucket(source, 0)
            notify(source, 'No saved position, but your routing bucket was reset to the open world.', 'success')
            return
        end
        notify(source, 'Nothing to return to — your bucket is already the open world.', 'info')
        return
    end
    SavedBucket[source] = nil
    restoreBucket(source, saved)
    notify(source, ('Routing bucket restored (was %s).'):format(tostring(saved)), 'success')
end

-- ── /ajail · /aunjail · /aclear (level 2, via faction exports) ─
function A.ajail(source, args)
    if source ~= 0 and not requirePerm(source, 'ajail') then return end
    local target = getTarget(source, args[1], 'Usage: /ajail [player id] [minutes] [reason]')
    if not target or not guardSelfTarget(source, target, args[1], 'ajail') then return end
    local minutes = tonumber(args[2])
    if not minutes or minutes < 1 or minutes > 1440 then
        notify(source, 'Duration must be 1-1440 minutes: /ajail [id] [minutes] [reason]', 'error')
        return
    end
    local reason = table.concat(args, ' ', 3)
    if reason == '' then reason = 'Admin jail' end
    if GetResourceState('sunset_factions') ~= 'started' then
        notify(source, 'The jail system is unavailable right now.', 'error')
        return
    end
    local ok, err = pcall(function() return exports.sunset_factions:AdminJail(target, minutes, reason, source) end)
    if not ok then
        notify(source, err or 'Jail failed.', 'error')
        return
    end
    SunsetAdmin.Sanctions.jail(source, target, minutes, reason)
    notify(source, ('Jailed #%d for %d minutes.'):format(target, minutes), 'success')
    markAnticheat(target, 'ajail')
end

function A.aunjail(source, args)
    if source ~= 0 and not requirePerm(source, 'aunjail') then return end
    local target = getTarget(source, args[1], 'Usage: /aunjail [player id]')
    if not target then return end
    if GetResourceState('sunset_factions') ~= 'started' then
        notify(source, 'The jail system is unavailable right now.', 'error')
        return
    end
    local ok, err = pcall(function() return exports.sunset_factions:AdminUnjail(target) end)
    if not ok then
        notify(source, err or 'Unjail failed.', 'error')
        return
    end
    SunsetAdmin.Sanctions.unjail(source, target)
    notify(source, ('Released #%d from jail.'):format(target), 'success')
    TriggerClientEvent('sunset:client:notify', target, 'You were released from jail by staff.', 'success')
end

function A.aclear(source, args)
    if source ~= 0 and not requirePerm(source, 'aclear') then return end
    local target = getTarget(source, args[1], 'Usage: /aclear [player id]')
    if not target then return end
    if GetResourceState('sunset_factions') ~= 'started' then
        notify(source, 'The wanted system is unavailable right now.', 'error')
        return
    end
    local ok, err = pcall(function() return exports.sunset_factions:AdminClearWanted(target) end)
    if not ok then
        notify(source, err or 'Could not clear wanted level.', 'error')
        return
    end
    notify(source, ('Cleared wanted stars for #%d.'):format(target), 'success')
    TriggerClientEvent('sunset:client:notify', target, 'Your wanted stars were cleared by staff.', 'info')
end

-- ── mass tools (level 3) ───────────────────────────────────────
local PendingMass = {} -- [src] = { cmd, at }

local function requireConfirm(source, cmd)
    local pending = PendingMass[source]
    if pending and pending.cmd == cmd and (os.time() - pending.at) < 30 then
        PendingMass[source] = nil
        return true
    end
    PendingMass[source] = { cmd = cmd, at = os.time() }
    return false
end

function A.ahealall(source)
    if source ~= 0 and not requirePerm(source, 'ahealall') then return end
    if source ~= 0 and not requireConfirm(source, 'ahealall') then
        notify(source, 'MASS ACTION: type /ahealall again within 30s to heal EVERYONE.', 'warning')
        return
    end
    local count = 0
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        TriggerClientEvent('sunset:admin:heal', src)
        count = count + 1
    end
    notify(source, ('Healed %d players.'):format(count), 'success')
    pcall(function() exports.sunset_admin:BroadcastStaff(('[ADMIN] %s healed ALL players')
        :format(source == 0 and 'console' or (GetPlayerName(source) or '?'))) end)
end

function A.fixall(source)
    if source ~= 0 and not requirePerm(source, 'fixall') then return end
    if source ~= 0 and not requireConfirm(source, 'fixall') then
        notify(source, 'MASS ACTION: type /fixall again within 30s to repair every vehicle.', 'warning')
        return
    end
    local count = 0
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        TriggerClientEvent('sunset:admin:repairVehicle', src)
        count = count + 1
    end
    notify(source, ('Sent repair to %d players.'):format(count), 'success')
end

function A.dvall(source, args)
    if source == 0 then return end
    if not requirePerm(source, 'dvall') then return end
    if not requireConfirm(source, 'dvall') then
        notify(source, 'DESTRUCTIVE MASS ACTION: type /dvall again within 30s to delete unowned vehicles around you.', 'warning')
        return
    end
    -- Server-side sweep: find unoccupied vehicles near the admin that are NOT
    -- registered in the vehicles table (owned cars are never touched).
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local center = GetEntityCoords(ped)
    local ownedPlates = {}
    local rows = MySQL.query.await('SELECT plate FROM vehicles') or {}
    for _, row in ipairs(rows) do
        ownedPlates[tostring(row.plate or ''):gsub('%s+', ''):upper()] = true
    end
    local deleted = 0
    for _, veh in ipairs(GetAllVehicles()) do
        if veh ~= 0 and DoesEntityExist(veh) then
            local vc = GetEntityCoords(veh)
            if #(vc - center) <= 60.0 then
                local occupied = GetPedInVehicleSeat(veh, -1) ~= 0 or GetVehicleNumberOfPassengers(veh) > 0
                local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', ''):upper()
                if not occupied and not ownedPlates[plate] then
                    DeleteEntity(veh)
                    deleted = deleted + 1
                end
            end
        end
    end
    notify(source, ('Deleted %d unowned vehicle(s) within 60m.'):format(deleted), 'success')
    pcall(function() exports.sunset_admin:BroadcastStaff(('[ADMIN] %s dvall: deleted %d vehicle(s)')
        :format(GetPlayerName(source) or '?', deleted)) end)
end

-- ── /gotoid alias (G15/4.10) ───────────────────────────────────
function A.gotoid(source, args)
    -- alias of /tp [id] (muscle memory from other frameworks)
    if source == 0 then return end
    if not requirePerm(source, 'tp') then return end
    local target = getTarget(source, args[1], 'Usage: /gotoid [player id]')
    if not target then return end
    local ped = GetPlayerPed(target)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    if targetInProperty(target) and SavedBucket[source] == nil then
        SavedBucket[source] = GetPlayerRoutingBucket(source) or 0
    end
    SetPlayerRoutingBucket(source, GetPlayerRoutingBucket(target) or 0)
    TriggerClientEvent('sunset:admin:teleport', source, coords.x, coords.y, coords.z)
    markAnticheat(source, 'gotoid')
end

-- ── /setclan (level 3, G18) ────────────────────────────────────
-- Domain rule: sunset_clans owns clan_members — go through its Admin*
-- exports (server/admin_ops.lua) instead of writing the table here.
function A.setclan(source, args)
    if source ~= 0 and not requirePerm(source, 'setclan') then return end
    local target = getTarget(source, args[1], 'Usage: /setclan [player id] [clanId|none] [rank]')
    if not target then return end
    if GetResourceState('sunset_clans') ~= 'started' then
        notify(source, 'The clan system is unavailable right now.', 'error')
        return
    end
    local clanArg = tostring(args[2] or ''):lower()
    local rank = math.max(1, math.min(10, math.floor(tonumber(args[3]) or 1)))
    local char = exports.sunset_core:GetCharacter(target)
    if not char then
        notify(source, ('Player #%d has no character loaded.'):format(target), 'error')
        return
    end

    if clanArg == '' or clanArg == 'none' then
        local ok, removedOrErr = pcall(function() return exports.sunset_clans:AdminRemoveFromClan(char.id) end)
        if not ok then
            notify(source, tostring(removedOrErr), 'error')
            return
        end
        pcall(function() exports.sunset_clans:SyncPlayerClan(target) end)
        notify(source, ('Removed #%d from their clan (%s row(s)).'):format(target, tostring(removedOrErr)), 'success')
        TriggerClientEvent('sunset:client:notify', target, 'Staff removed you from your clan.', 'warning')
        return
    end

    local ok, resultOrErr = pcall(function() return exports.sunset_clans:AdminSetClan(char.id, tonumber(clanArg), rank) end)
    if not ok or not resultOrErr then
        notify(source, tostring(resultOrErr or 'Could not set the clan.'), 'error')
        return
    end
    pcall(function() exports.sunset_clans:SyncPlayerClan(target) end)
    notify(source, ('Set #%d to clan [%s] %s (rank %d).'):format(
        target, resultOrErr.tag or '--', resultOrErr.name or '?', resultOrErr.rank or rank), 'success')
    TriggerClientEvent('sunset:client:notify', target,
        ('Staff moved you to clan [%s] %s.'):format(resultOrErr.tag or '--', resultOrErr.name or '?'), 'info')
end

-- ── registration (commands are registered here; requirePerm etc.
--    are injected from commands.lua via SunsetAdmin.ActionsInit) ──
function A.init(env)
    hasPerm = env.hasPerm
    notify = env.notify
    requirePerm = env.requirePerm
    getTarget = env.getTarget
    guardSelfTarget = env.guardSelfTarget
    resolveTarget = env.resolveTarget
    registerServerCommand = env.registerServerCommand

    registerServerCommand('freeze', function(source, args) A.freeze(source, args) end, false)
    registerServerCommand('unfreeze', function(source, args) A.unfreeze(source, args) end, false)
    registerServerCommand('slap', function(source, args) A.slap(source, args) end, false)
    registerServerCommand('pullout', function(source, args) A.pullout(source, args) end, false)
    registerServerCommand('spectate', function(source, args) A.spectate(source, args) end, false)
    registerServerCommand('tpcar', function(source, args) A.tpcar(source, args) end, false)
    registerServerCommand('bringcar', function(source, args) A.bringcar(source, args) end, false)
    registerServerCommand('tpback', function(source, args) A.tpback(source, args) end, false)
    registerServerCommand('ajail', function(source, args) A.ajail(source, args) end, false)
    registerServerCommand('aunjail', function(source, args) A.aunjail(source, args) end, false)
    registerServerCommand('aclear', function(source, args) A.aclear(source, args) end, false)
    registerServerCommand('ahealall', function(source) A.ahealall(source) end, false)
    registerServerCommand('fixall', function(source) A.fixall(source) end, false)
    registerServerCommand('dvall', function(source, args) A.dvall(source, args) end, false)
    registerServerCommand('gotoid', function(source, args) A.gotoid(source, args) end, false)
    registerServerCommand('setclan', function(source, args) A.setclan(source, args) end, false)
end

SunsetAdmin.Actions = A
print('^2[sunset_admin]^7 presence tools loaded (freeze/slap/spectate/tpcar/ajail/mass)')
