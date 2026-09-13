local Downed = {}
local LastPvPAttacker = {}
-- [BUGFIX] Was declared at line ~225 but used by the playerDied handler above;
-- Lua compiled it as a nil GLOBAL there -> handler crashed on every death.
local MurderWindow = {}

AddEventHandler('sunset:death:recordAttacker', function(victimSrc, attackerSrc)
    victimSrc = tonumber(victimSrc)
    attackerSrc = tonumber(attackerSrc)
    if not victimSrc or not attackerSrc or victimSrc == attackerSrc then return end
    LastPvPAttacker[victimSrc] = { attacker = attackerSrc, at = os.time() }
end)

local function bleedoutDuration()
    return math.max(30, tonumber(Sunset.Death and Sunset.Death.bleedoutSeconds) or 300)
end

local function hospitalSpawn(char)
    local pos = char and exports.sunset_core:GetSpawnPosition(char, source)
    if pos and pos.x then return pos end
    local h = Sunset.Config.HospitalSpawn or Sunset.Config.DefaultSpawn
    return { x = h.x, y = h.y, z = h.z, w = h.w }
end

local function respawnPlayer(source, bill)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false, 'No character' end

    bill = bill or 0
    if bill > 0 then
        if not exports.sunset_core:RemoveMoney(source, 'bank', bill, 'hospital') then
            exports.sunset_core:RemoveMoney(source, 'cash', bill, 'hospital')
        end
    end

    char.is_dead = false
    Downed[source] = nil
    -- [AUDIT 3-5.1] Release any property routing bucket before hospital respawn;
    -- otherwise the player spawns at the hospital invisible to everyone.
    if GetResourceState('sunset_properties') == 'started' then
        pcall(function() exports.sunset_properties:LeaveProperty(source) end)
    end
    SetPlayerRoutingBucket(source, 0)
    local pos = hospitalSpawn(char)
    pcall(function() exports.sunset_core:SaveCharacter(source) end)
    TriggerClientEvent('sunset:death:forceHospital', source, pos, bill)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function RevivePlayer(targetId)
    targetId = tonumber(targetId)
    if not targetId then
        return false, 'Usage: /revive [player id]'
    end
    if not GetPlayerName(targetId) then
        return false, 'Player not found — check TAB for server ID'
    end

    local char = exports.sunset_core:GetCharacter(targetId)
    if char then
        char.is_dead = false
        TriggerClientEvent('sunset:client:updateCharacter', targetId, char)
    end

    Downed[targetId] = nil
    TriggerClientEvent('sunset:death:reviveInPlace', targetId)
    return true
end

-- Used by server-owned custody flows. The receiving resource is responsible for
-- resurrecting/positioning the player so the normal revive event cannot race it.
function ClearDownedForCustody(targetId)
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return false, 'Player not found'
    end

    local char = exports.sunset_core:GetCharacter(targetId)
    if char then
        char.is_dead = false
        pcall(function() exports.sunset_core:SaveCharacter(targetId) end)
        TriggerClientEvent('sunset:client:updateCharacter', targetId, char)
    end
    Downed[targetId] = nil
    return true
end

function StabilizePlayer(targetId)
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return false, 'Player not found'
    end
    if not Downed[targetId] then
        return false, 'Target is not downed'
    end
    Downed[targetId].stabilized = true
    Downed[targetId].releaseAt = os.time()
        + math.max(30, tonumber(Sunset.Death and Sunset.Death.stabilizeBonusSeconds) or 120)
    TriggerClientEvent('sunset:death:stabilized', targetId)
    return true
end

exports('RevivePlayer', RevivePlayer)
exports('RespawnPlayer', respawnPlayer)
exports('StabilizePlayer', StabilizePlayer)
exports('ClearDownedForCustody', ClearDownedForCustody)
exports('IsPlayerDowned', function(source) return Downed[source] ~= nil end)

local function getOnDutyEmsCount()
    local count = 0
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            local onDuty = false
            pcall(function()
                if exports.sunset_factions:IsOnDuty(src) then
                    local char = exports.sunset_core:GetCharacter(src)
                    if char then
                        local factionId = Sunset.GetCharacterFaction and select(1, Sunset.GetCharacterFaction(char))
                        if not factionId and type(char.metadata) == 'table' then
                            factionId = char.metadata.faction
                        end
                        if factionId == 'ems' or factionId == 'medic' or (Sunset.FactionTypeMatches and Sunset.FactionTypeMatches(factionId, 'medical')) then
                            count = count + 1
                        end
                    end
                end
            end)
            if onDuty then count = count + 1 end
        end
    end
    return count
end

local function bleedoutDurationFor(source)
    local ems = getOnDutyEmsCount()
    if ems == 0 then
        return math.max(15, tonumber(Sunset.Death and Sunset.Death.soloBleedoutSeconds) or 15)
    end
    return math.max(30, tonumber(Sunset.Death and Sunset.Death.bleedoutSeconds) or 180)
end

RegisterNetEvent('sunset:server:playerDied', function()
    local source = source
    -- [AUDIT P2-07] Verify the ped is actually downed server-side; a live player
    -- must not be able to fake death to spam EMS dispatch or dodge activity.
    -- [SERVER NATIVE FIX] IsPedDeadOrDying is CLIENT-ONLY (nil on server):
    -- the old check crashed this handler mid-death, so downed players were
    -- never registered server-side. Server-side death check: health <= 100
    -- (fatal) or <= 160 (downed state sets the ped to exactly 150 client-side).
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        local hp = GetEntityHealth(ped)
        if hp > 160 then return end
    end
    -- [WAR REDESIGN] Turf-war deaths use the war respawn loop (kill-feed style);
    -- skip the downed/EMS flow entirely for active war participants.
    if GetResourceState('sunset_turfs') == 'started' then
        local ok, inWar = pcall(function() return exports.sunset_turfs:IsInWar(source) end)
        if ok and inWar then return end
    end
    if Downed[source] then return end
    local char = exports.sunset_core:GetCharacter(source)
    if char then char.is_dead = true end
    local now = os.time()
    local dur = bleedoutDurationFor(source)
    Downed[source] = { startedAt = now, releaseAt = now + dur, stabilized = false }
    TriggerEvent('sunset:death:playerDowned', source)
    TriggerClientEvent('sunset:death:syncTimer', source, dur)

    local pending = LastPvPAttacker[source]
    LastPvPAttacker[source] = nil
    if pending and pending.attacker and (now - (pending.at or 0)) <= 15 then
        local killer = pending.attacker
        if killer ~= source and GetPlayerName(killer) and not isOnDutyPolice(killer) then
            if not MurderWindow[source] then
                MurderWindow[source] = { killerId = killer, expires = now + 60 }
                TriggerClientEvent('sunset:client:notify', source,
                    'You were attacked! You have 60 seconds to use /112 to report the attacker.',
                    'error', 10000)
                SetTimeout(61000, function()
                    local row = MurderWindow[source]
                    if row and row.killerId == killer then
                        MurderWindow[source] = nil
                    end
                end)
            end
        end
    end
end)

RegisterNetEvent('sunset:death:enteredDowned', function()
    local source = source
    -- [AUDIT P2-07] Same server-side verification as playerDied.
    -- [SERVER NATIVE FIX] Client-only IsPedDeadOrDying replaced with the
    -- health window check (downed = 150, fatal <= 100, healthy = 200).
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        local hp = GetEntityHealth(ped)
        if hp > 160 then return end
    end
    if not Downed[source] then
        local now = os.time()
        local dur = bleedoutDurationFor(source)
        Downed[source] = { startedAt = now, releaseAt = now + dur, stabilized = false }
        TriggerClientEvent('sunset:death:syncTimer', source, dur)
    end
end)

RegisterNetEvent('sunset:server:bleedoutExpired', function()
    local source = source
    local state = Downed[source]
    if not state or os.time() < (state.releaseAt or math.huge) then return end
    respawnPlayer(source, Sunset.Config.HospitalBill or 250)
end)

RegisterNetEvent('sunset:server:requestRespawn', function()
    local source = source
    local state = Downed[source]
    if not state then
        TriggerClientEvent('sunset:client:notify', source, 'You are not downed.', 'info', 4000)
        return
    end
    local now = os.time()
    local ems = getOnDutyEmsCount()
    if ems == 0 and (now - (state.startedAt or 0)) >= 10 then
        respawnPlayer(source, Sunset.Config.HospitalBill or 250)
        return
    end

    if now < (state.releaseAt or math.huge) then
        local remaining = math.max(1, (state.releaseAt or now) - now)
        TriggerClientEvent('sunset:client:notify', source,
            ('You must wait %d more seconds before respawning at the hospital, or call /112.'):format(remaining),
            'warning', 5000)
        return
    end
    respawnPlayer(source, Sunset.Config.HospitalBill or 250)
end)

local function isOnDutyPolice(src)
    local onDuty = false
    pcall(function()
        onDuty = exports.sunset_factions:IsOnDuty(src) == true
    end)
    if not onDuty then return false end
    local char = exports.sunset_core:GetCharacter(src)
    if not char then return false end
    local md = type(char.metadata) == 'table' and char.metadata or {}
    local factionId = md.faction or char.job
    if factionId == 'police' then return true end
    if Sunset.GetCharacterFaction then
        factionId = select(1, Sunset.GetCharacterFaction(char)) or factionId
    end
    return Sunset.FactionTypeMatches
        and Sunset.FactionTypeMatches(factionId, 'law_enforcement') == true
end

RegisterNetEvent('sunset:death:playerKilled', function(victimId)
    local killer = source
    victimId = tonumber(victimId)
    if not victimId or victimId == killer or not GetPlayerName(victimId) then return end

    local killerPed = GetPlayerPed(killer)
    local victimPed = GetPlayerPed(victimId)
    if not killerPed or killerPed == 0 or not victimPed or victimPed == 0 then return end
    if GetEntityHealth(victimPed) > 0 then return end
    if #(GetEntityCoords(killerPed) - GetEntityCoords(victimPed)) > 500.0 then return end

    if isOnDutyPolice(killer) then return end
    if MurderWindow[victimId] then return end

    -- [AUDIT P2-07] Only accept the client claim when it matches server-recorded
    -- damage attribution (weaponDamageEvent -> recordAttacker). Without this any
    -- client within 500m could frame an innocent player for murder.
    local recorded = LastPvPAttacker[victimId]
    if not recorded or recorded.attacker ~= killer then return end

    MurderWindow[victimId] = { killerId = killer, expires = os.time() + 60 }
    TriggerClientEvent('sunset:client:notify', victimId, 'You were attacked! You have 60 seconds to use /112 to call emergency services and report your attacker.', 'error', 10000)
    SetTimeout(61000, function()
        local pending = MurderWindow[victimId]
        if pending and pending.killerId == killer then
            MurderWindow[victimId] = nil
        end
    end)
end)

RegisterNetEvent('sunset:death:call112', function()
    local src = source
    local pending = MurderWindow[src]
    if not pending or os.time() > pending.expires then
        TriggerClientEvent('sunset:client:notify', src, 'No emergency report window is open.', 'error')
        return
    end

    local killer = pending.killerId
    MurderWindow[src] = nil

    local ped = GetPlayerPed(src)
    local coords = (ped and ped ~= 0) and GetEntityCoords(ped) or vector3(0, 0, 0)
    local victimName = exports.sunset_core:GetPlayerDisplayName(src) or ('Player #' .. tostring(src))
    local killerName = (killer and GetPlayerName(killer)) and exports.sunset_core:GetPlayerDisplayName(killer) or 'Unknown Attacker'

    -- 1. Medic dispatch for downed victim
    if GetResourceState('sunset_dispatch') == 'started' then
        pcall(function()
            exports.sunset_dispatch:CreateServiceCall(src, 'medic', coords, {
                system = true,
                emergency = '112',
                category = 'medical',
                callerName = victimName,
            }, ('112 Emergency — Assault victim %s requires immediate medical response'):format(victimName))
        end)
    end

    -- 2. Report attacker for first-degree murder & alert police
    if killer and GetPlayerName(killer) then
        TriggerEvent('sunset:police:autoWanted', killer, 'murder', 'First-degree murder (Reported via 112)')
        TriggerClientEvent('sunset:client:notify', killer, 'A 112 emergency call reported your crime! You are now WANTED ★5 for murder.', 'error', 12000)

        -- Create police service call so it populates the Toughbook MDT 112 feed and blip on GPS
        if GetResourceState('sunset_dispatch') == 'started' then
            pcall(function()
                local dispatchDesc = ('10-99 EMERGENCY — Homicide victim %s reported attacker %s!'):format(victimName, killerName)
                local call = exports.sunset_dispatch:CreateServiceCall(src, 'police', coords, {
                    system = true,
                    emergency = '112',
                    category = 'shots',
                    street = 'Emergency 112 Scene',
                    area = 'Los Santos',
                    callerName = victimName,
                    suspect = killerName,
                    suspectId = killer,
                }, dispatchDesc)

                -- Broadcast audio chime, priority UI alert, and Toughbook MDT notification to all law enforcement
                local payload = {
                    callId = (type(call) == 'table' and call.id) or 0,
                    callType = 'police',
                    category = 'shots',
                    street = '112 Assault Scene',
                    area = 'Los Santos',
                    caller = victimName,
                    phone = '112-SOS',
                    description = dispatchDesc,
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                }

                for _, id in ipairs(GetPlayers()) do
                    local officerSrc = tonumber(id)
                    local isCop = false
                    pcall(function()
                        isCop = exports.sunset_factions:IsOnDuty(officerSrc) and Sunset.FactionTypeMatches(exports.sunset_factions:GetPlayerFaction(officerSrc), 'law_enforcement')
                    end)
                    if isCop then
                        TriggerClientEvent('sunset:dispatch:112CallAlert', officerSrc, payload)
                    end
                end
            end)
        end
    end

    TriggerClientEvent('sunset:client:notify', src, '112 received — Medic & Police dispatched! Attacker reported for murder.', 'success', 8000)
end)

AddEventHandler('playerDropped', function()
    Downed[source] = nil
    MurderWindow[source] = nil
    LastPvPAttacker[source] = nil
end)

exports.sunset_core:RegisterCallback('sunset:revivePlayer', function(source, targetId)
    targetId = tonumber(targetId)
    if not targetId then return nil, 'Usage: /revive [player id]' end

    local isAdmin = false
    pcall(function() isAdmin = exports.sunset_admin:IsAdmin(source, 2) end)
    local isEms = false
    pcall(function() isEms = exports.sunset_factions:HasFactionPerm(source, 'revive') end)
    if not isAdmin and not isEms then return nil, 'Not on duty or no permission' end

    local ok, err = RevivePlayer(targetId)
    if not ok then return nil, err end
    return true
end)
