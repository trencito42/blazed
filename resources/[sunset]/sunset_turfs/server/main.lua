-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Turf Wars Engine (server/main.lua)
--  Territory captures, live war HUD, and clan territory payouts
-- ═══════════════════════════════════════════════════════════════

local Turfs = {}
local ActiveWars = {}
local TurfCooldowns = {}

local function log(msg)
    print(('[sunset_turfs] %s'):format(msg))
end

local function refreshChatCommands()
    if GetResourceState('sunset_chat') ~= 'started' then return end
    pcall(function()
        exports.sunset_chat:RefreshCommandList()
    end)
end

-- [AUDIT P7-01] The war ticker called this per-player-per-second (~20-40 blocking
-- queries/s during a busy war). Cache results per character for 30s; membership
-- changes mid-war are reflected within the TTL, which is acceptable for scoring.
local ClanCache = {}
local CLAN_CACHE_TTL = 30

local function getPlayerClan(src)
    local char = exports.sunset_core:GetCharacter(src)
    if not char then return nil end

    local now = os.time()
    local cached = ClanCache[char.id]
    if cached and (now - cached.at) < CLAN_CACHE_TTL then
        return cached.row
    end

    local row = MySQL.single.await([[
        SELECT cm.clan_id, cm.rank, c.name, c.tag, c.tag_color
        FROM clan_members cm
        JOIN clans c ON c.id = cm.clan_id
        WHERE cm.character_id = ?
        LIMIT 1
    ]], { char.id })
    ClanCache[char.id] = { row = row, at = now }
    return row
end

AddEventHandler('playerDropped', function()
    local ok, char = pcall(function() return exports.sunset_core:GetCharacter(source) end)
    if ok and char and char.id then ClanCache[char.id] = nil end
end)

local function loadTurfsFromDb()
    local rows = MySQL.query.await([[
        SELECT t.*, c.name AS clan_name, c.tag AS clan_tag, c.tag_color AS clan_color
        FROM turfs t
        LEFT JOIN clans c ON c.id = t.owner_clan_id
    ]]) or {}

    Turfs = {}
    for _, r in ipairs(rows) do
        Turfs[r.id] = {
            id = r.id,
            name = r.name,
            coords = vector3(r.x, r.y, r.z),
            radius = tonumber(r.radius) or 110.0,
            ownerClanId = r.owner_clan_id and tonumber(r.owner_clan_id) or nil,
            ownerName = r.clan_name or 'Free',
            ownerTag = r.clan_tag or '--',
            ownerColor = r.clan_color or '#00ffcc',
            payout = tonumber(r.payout) or 1500,
            respectPayout = tonumber(r.respect_payout) or 2,
        }
    end
    log(('Loaded %d gang territories from database.'):format(#rows))
end

CreateThread(function()
    Wait(500)
    local ok, err = pcall(function()
        loadTurfsFromDb()
    end)
    if not ok then
        print(('^1[sunset_turfs]^7 startup failed: %s'):format(tostring(err)))
    else
        refreshChatCommands()
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(1000, refreshChatCommands)
end)

local function syncTurfsToClient(src)
    TriggerClientEvent('sunset:turfs:syncAll', src or -1, Turfs)
end

RegisterNetEvent('sunset:turfs:requestSync', function()
    local src = source
    -- [AUDIT P2-10] Full turf+war state dump per call: throttle to prevent DoS amplification.
    if not exports.sunset_core:RateLimit(src, 'turfsSync', 5000) then return end
    syncTurfsToClient(src)
    for turfId, war in pairs(ActiveWars) do
        TriggerClientEvent('sunset:turfs:warStart', src, war)
    end
end)

local function findTurfAtCoords(coords)
    for _, t in pairs(Turfs) do
        if #(coords - t.coords) <= t.radius then
            return t
        end
    end
    return nil
end

local function getClanMembersInTurf(clanId, turf)
    local count = 0
    local peds = {}
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if src then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and #(GetEntityCoords(ped) - turf.coords) <= turf.radius then
                -- [PHANTOM POINTS FIX] Dead/downed players must NOT count for
                -- zone-presence scoring (their corpse stays in the zone while
                -- they wait for the war respawn -> team kept scoring).
                local alive = GetEntityHealth(ped) > 0
                if alive and GetResourceState('sunset_death') == 'started' then
                    local okD, downed = pcall(function() return exports.sunset_death:IsPlayerDowned(src) end)
                    if okD and downed then alive = false end
                end
                if alive then
                    local pClan = getPlayerClan(src)
                    if pClan and tonumber(pClan.clan_id) == tonumber(clanId) then
                        count = count + 1
                        table.insert(peds, src)
                    end
                end
            end
        end
    end
    return count, peds
end

local function endWar(turfId, reason)
    local war = ActiveWars[turfId]
    if not war then return end

    ActiveWars[turfId] = nil
    TurfCooldowns[turfId] = os.time() + SunsetTurfs.TurfCooldownSec

    -- [WAR END FIX] Participants who are dead/downed when the war ends used to
    -- stay on the ground waiting for EMS (the war respawn UI disappears at
    -- warEnd). The war is over -> auto-revive everyone still in the war death
    -- loop so they are not stranded.
    if GetResourceState('sunset_death') == 'started' then
        for src in pairs(war.participants or {}) do
            if GetPlayerName(src) then
                local ped = GetPlayerPed(src)
                local isDead = ped and ped ~= 0 and (GetEntityHealth(ped) <= 0 or IsPedFatallyInjured(ped))
                local isDowned = false
                if not isDead then
                    local okD, downed = pcall(function() return exports.sunset_death:IsPlayerDowned(src) end)
                    isDowned = okD and downed == true
                end
                if isDead or isDowned then
                    pcall(function() exports.sunset_death:RevivePlayer(src) end)
                end
            end
        end
    end

    local turf = Turfs[turfId]
    local attackerWon
    if war.isNeutralCapture then
        attackerWon = war.attackerScore >= (war.captureTarget or SunsetTurfs.NeutralCaptureSec or 180)
    else
        attackerWon = war.attackerScore > war.defenderScore
    end

    local winnerClanId = attackerWon and war.attackerClanId or war.defenderClanId
    local winnerClanName = attackerWon and war.attackerName or war.defenderName
    local winnerClanTag = attackerWon and war.attackerTag or war.defenderTag

    if winnerClanId then
        MySQL.update.await('UPDATE turfs SET owner_clan_id = ? WHERE id = ?', { winnerClanId, turfId })
        local clanRow = MySQL.single.await('SELECT name, tag, tag_color FROM clans WHERE id = ?', { winnerClanId })
        if clanRow then
            turf.ownerClanId = winnerClanId
            turf.ownerName = clanRow.name
            turf.ownerTag = clanRow.tag
            turf.ownerColor = clanRow.tag_color or '#00ffcc'
        end
    end

    -- [WAR REDESIGN] Build per-player stats + MVP for the end screen.
    local stats, mvp = {}, nil
    for src, p in pairs(war.participants or {}) do
        stats[#stats + 1] = {
            name = GetPlayerName(src) or p.name or '?',
            src = src,
            kills = p.kills or 0,
            deaths = p.deaths or 0,
            side = tonumber(p.clanId) == tonumber(war.attackerClanId) and 'attacker' or 'defender',
        }
        if not mvp or (p.kills or 0) > (mvp.kills or 0) then
            mvp = { name = GetPlayerName(src) or p.name or '?', kills = p.kills or 0, deaths = p.deaths or 0 }
        end
    end

    syncTurfsToClient(-1)
    TriggerClientEvent('sunset:turfs:warEnd', -1, {
        turfId = turfId,
        turfName = turf.name,
        winnerName = winnerClanName,
        winnerTag = winnerClanTag,
        attackerName = war.attackerName,
        attackerTag = war.attackerTag,
        defenderName = war.defenderName,
        defenderTag = war.defenderTag,
        attackerWon = attackerWon,
        attackerScore = war.attackerScore,
        defenderScore = war.defenderScore,
        reason = reason,
        stats = stats,
        mvp = mvp,
        scoreTarget = war.scoreTarget,
    })

    -- [WAR FIX] A defender who wins (or ties) KEEPS the turf they already owned;
    -- the announcement must say "defended", not "conquered".
    local winnerIsDefender = (not war.isNeutralCapture) and not attackerWon
    local announcement
    if winnerIsDefender then
        announcement = ('^2[TURF WAR] ^7The war for ^3%s^7 ended! ^2[%s] %s^7 defended the territory (%d vs %d points)!'):format(
            turf.name, winnerClanTag or '--', winnerClanName or 'Unknown', war.defenderScore, war.attackerScore
        )
    else
        announcement = ('^2[TURF WAR] ^7The war for ^3%s^7 ended! ^2[%s] %s^7 captured the territory (%d vs %d points)!'):format(
            turf.name, winnerClanTag or '--', winnerClanName or 'Unknown', war.attackerScore, war.defenderScore
        )
    end
    TriggerClientEvent('chat:addMessage', -1, { color = { 0, 255, 204 }, args = { 'WAR', announcement } })
end

local function startWar(turf, attackerClan, defenderClan)
    local turfId = turf.id
    local isNeutralCapture = not defenderClan
    local captureTarget = isNeutralCapture and (SunsetTurfs.NeutralCaptureSec or 180) or nil
    local durationSec = SunsetTurfs.WarDurationSec
    if isNeutralCapture then
        durationSec = math.min(SunsetTurfs.WarDurationSec, (captureTarget or 180) + 90)
    end

    local warData = {
        turfId = turfId,
        turfName = turf.name,
        coords = turf.coords,
        radius = turf.radius,
        attackerClanId = attackerClan.clan_id,
        attackerName = attackerClan.name,
        attackerTag = attackerClan.tag,
        attackerColor = attackerClan.tag_color or '#00ffcc',
        attackerScore = 0,
        defenderClanId = defenderClan and defenderClan.id or nil,
        defenderName = defenderClan and defenderClan.name or 'Unowned (free turf)',
        defenderTag = defenderClan and defenderClan.tag or 'LIBER',
        defenderColor = defenderClan and defenderClan.tag_color or '#555555',
        defenderScore = 0,
        isNeutralCapture = isNeutralCapture,
        captureTarget = captureTarget,
        scoreTarget = isNeutralCapture and nil or SunsetTurfs.WarScoreTarget,
        participants = {},   -- [src] = { clanId, kills, deaths, name }
        startedAt = os.time(),
        expiresAt = os.time() + durationSec,
    }

    ActiveWars[turfId] = warData
    -- [ARMORY FIX] Register ALL online members of both clans as participants
    -- immediately (the zone ticker used to be the only registration path, so
    -- anyone outside the radius got "not in an active war" on /armory).
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if src then
            local pClan = getPlayerClan(src)
            if pClan then
                if tonumber(pClan.clan_id) == tonumber(warData.attackerClanId) then
                    warData.participants[src] = { clanId = warData.attackerClanId, kills = 0, deaths = 0, name = GetPlayerName(src) or '?' }
                    TriggerClientEvent('sunset:turfs:warJoined', src, { turfId = turfId, role = 'attacker' })
                elseif warData.defenderClanId and tonumber(pClan.clan_id) == tonumber(warData.defenderClanId) then
                    warData.participants[src] = { clanId = warData.defenderClanId, kills = 0, deaths = 0, name = GetPlayerName(src) or '?' }
                    TriggerClientEvent('sunset:turfs:warJoined', src, { turfId = turfId, role = 'defender' })
                end
            end
        end
    end
    TriggerClientEvent('sunset:turfs:warStart', -1, warData)

    -- [ANNOUNCE FIX] Duration was hardcoded "10 minutes" even for neutral
    -- captures (3-minute hold). Announce the actual computed duration and,
    -- for free turfs, the hold requirement.
    local durationMin = math.max(1, math.floor(durationSec / 60 + 0.5))
    local announcement
    if isNeutralCapture then
        announcement = ('^1[TURF WAR] ^7Clan ^3[%s] %s^7 is capturing unowned territory ^2%s^7! Hold the zone for %d minutes to claim it.'):format(
            attackerClan.tag, attackerClan.name, turf.name, durationMin
        )
    else
        announcement = ('^1[TURF WAR] ^7Clan ^3[%s] %s^7 attacked territory ^2%s^7 held by ^3[%s] %s^7! Duration: %d minutes.'):format(
            attackerClan.tag, attackerClan.name, turf.name, warData.defenderTag, warData.defenderName, durationMin
        )
    end
    TriggerClientEvent('chat:addMessage', -1, { color = { 255, 50, 50 }, args = { 'WAR', announcement } })

    -- [MOBILIZATION] Defenders get a rally window before zone scoring starts,
    -- so they have time to reach the turf when attacked.
    warData.rallyUntil = os.time() + (SunsetTurfs.RallyDelaySec or 60)

    -- War ticker thread
    CreateThread(function()
        while ActiveWars[turfId] do
            Wait(1000)
            local current = ActiveWars[turfId]
            if not current then break end

            if os.time() >= current.expiresAt then
                endWar(turfId, 'time_expired')
                break
            end

            -- Zone presence points
            local attCount, attPeds = getClanMembersInTurf(current.attackerClanId, turf)
            local defCount, defPeds = 0, {}
            if current.defenderClanId then
                defCount, defPeds = getClanMembersInTurf(current.defenderClanId, turf)
            end

            -- [WAR REDESIGN] Auto-register zone participants for stats/respawn/armory.
            for _, src in ipairs(attPeds or {}) do
                if not current.participants[src] then
                    current.participants[src] = { clanId = current.attackerClanId, kills = 0, deaths = 0, name = GetPlayerName(src) or '?' }
                    TriggerClientEvent('sunset:turfs:warJoined', src, { turfId = turfId, role = 'attacker' })
                end
            end
            for _, src in ipairs(defPeds or {}) do
                if not current.participants[src] then
                    -- [INTERVENTION] Keep each player's REAL clan on the participant
                    -- row (the defender clan can change mid-war via /intervene).
                    local srcClan = getPlayerClan(src)
                    current.participants[src] = {
                        clanId = (srcClan and srcClan.clan_id) or current.defenderClanId,
                        kills = 0, deaths = 0, name = GetPlayerName(src) or '?'
                    }
                    TriggerClientEvent('sunset:turfs:warJoined', src, { turfId = turfId, role = 'defender' })
                end
            end

            -- [MOBILIZATION] No zone scoring during the rally window (kills still
            -- score via scoreWarKill); gives defenders time to arrive.
            local rallyOver = not current.rallyUntil or os.time() >= current.rallyUntil
            if rallyOver then
                if attCount > 0 then
                    current.attackerScore = current.attackerScore + (attCount * SunsetTurfs.ScorePerSecond)
                end
                if current.defenderClanId and defCount > 0 then
                    current.defenderScore = current.defenderScore + (defCount * SunsetTurfs.ScorePerSecond)
                end
            end
            current.rallyRemaining = current.rallyUntil and math.max(0, current.rallyUntil - os.time()) or 0

            if current.isNeutralCapture and attCount > 0
                and current.attackerScore >= (current.captureTarget or SunsetTurfs.NeutralCaptureSec or 180) then
                endWar(turfId, 'neutral_captured')
                break
            end

            -- [WAR REDESIGN] Instant win on score target (kill-based races).
            if not current.isNeutralCapture and current.scoreTarget then
                if current.attackerScore >= current.scoreTarget then
                    endWar(turfId, 'score_target')
                    break
                end
                if current.defenderScore >= current.scoreTarget then
                    endWar(turfId, 'score_target')
                    break
                end
            end

            current.attackerCount = attCount
            current.defenderCount = defCount
            current.remainingSec = math.max(0, current.expiresAt - os.time())

            TriggerClientEvent('sunset:turfs:warTick', -1, current)
        end
    end)
end

local function canDeclareTurfAttack(rank)
    rank = SunsetClans and SunsetClans.normalizeRank(rank) or math.floor(tonumber(rank) or 0)
    return rank >= 5
end

local function runAttackTurf(source)
    if source == 0 then
        print('[sunset_turfs] /attackturf must be used in-game.')
        return
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local pClan = getPlayerClan(source)
    if not pClan then
        TriggerClientEvent('sunset:client:notify', source, 'You are not in a clan.', 'error')
        return
    end

    if not canDeclareTurfAttack(pClan.rank) then
        TriggerClientEvent('sunset:client:notify', source, 'Only clan officers and leaders (rank 5+) can declare an attack.', 'error')
        return
    end

    local pCoords = GetEntityCoords(ped)
    local turf = findTurfAtCoords(pCoords)
    if not turf then
        TriggerClientEvent('sunset:client:notify', source, 'You are not inside any territory. Check the blips on the map.', 'error')
        return
    end

    if turf.ownerClanId and tonumber(turf.ownerClanId) == tonumber(pClan.clan_id) then
        TriggerClientEvent('sunset:client:notify', source, 'This territory is already controlled by your clan!', 'info')
        return
    end

    if ActiveWars[turf.id] then
        TriggerClientEvent('sunset:client:notify', source, 'This territory is already in an active war.', 'warning')
        return
    end

    local cd = TurfCooldowns[turf.id] or 0
    if os.time() < cd then
        local remMin = math.ceil((cd - os.time()) / 60)
        TriggerClientEvent('sunset:client:notify', source, ('This territory is under post-war protection for %d more minutes.'):format(remMin), 'warning')
        return
    end

    for _, activeWar in pairs(ActiveWars) do
        if tonumber(activeWar.attackerClanId) == tonumber(pClan.clan_id)
            or tonumber(activeWar.defenderClanId) == tonumber(pClan.clan_id) then
            TriggerClientEvent('sunset:client:notify', source, 'Your clan is already engaged in a war on another territory!', 'error')
            return
        end
    end

    local defenderClan = nil
    if turf.ownerClanId then
        defenderClan = MySQL.single.await('SELECT id, name, tag, tag_color FROM clans WHERE id = ?', { turf.ownerClanId })
    end

    startWar(turf, pClan, defenderClan)
    log(('attackturf src=%s clan=%s turf=%s'):format(source, tostring(pClan.clan_id), tostring(turf.id)))
end

RegisterCommand('attackturf', function(source)
    runAttackTurf(source)
end, false)

RegisterCommand('atac', function(source)
    runAttackTurf(source)
end, false)

-- ═══════════════════════════════════════════════════════════════
--  [INTERVENTION] A third clan (leader, rank 5+) can claim an
--  UNOWNED turf that is currently being captured (/intervene).
--  The neutral capture war becomes a contested 1v1: the intervener
--  BECOMES the defender (armory, war respawn, kill scoring).
--  Intervention is NOT allowed on an owner-vs-attacker war —
--  that is already 1v1 and stays that way.
-- ═══════════════════════════════════════════════════════════════
local function runIntervene(source)
    if source == 0 then
        print('[sunset_turfs] /intervene must be used in-game.')
        return
    end

    local pClan = getPlayerClan(source)
    if not pClan then
        TriggerClientEvent('sunset:client:notify', source, 'You are not in a clan.', 'error')
        return
    end
    if not canDeclareTurfAttack(pClan.rank) then
        TriggerClientEvent('sunset:client:notify', source, 'Only clan officers and leaders (rank 5+) can declare an intervention.', 'error')
        return
    end

    local clanId = tonumber(pClan.clan_id)

    -- Clan must not be engaged anywhere already.
    for _, war in pairs(ActiveWars) do
        if tonumber(war.attackerClanId) == clanId
            or tonumber(war.defenderClanId or 0) == clanId then
            TriggerClientEvent('sunset:client:notify', source, 'Your clan is already engaged in a war!', 'error')
            return
        end
    end

    -- Only an UNOWNED turf under neutral capture can be claimed by intervention.
    local targetWar, targetTurfId
    for turfId, war in pairs(ActiveWars) do
        if war.isNeutralCapture and not war.defenderClanId then
            targetWar = war
            targetTurfId = turfId
            break
        end
    end
    if not targetWar then
        TriggerClientEvent('sunset:client:notify', source, 'There is no unowned territory being captured right now. /intervene only works on an empty turf.', 'error')
        return
    end

    -- Intervention window: the capture must still be in progress, and only
    -- during the first part of it (no last-second steals of a decided war).
    local elapsed = os.time() - (targetWar.startedAt or os.time())
    local window = SunsetTurfs.InterventionWindowSec or 240
    if elapsed > window then
        TriggerClientEvent('sunset:client:notify', source, 'The intervention window has closed — the capture is too far along.', 'warning')
        return
    end

    -- The intervening clan BECOMES the defender: neutral capture turns into
    -- a contested war (score target, full duration, no rally needed — both
    -- sides are already mobilized).
    targetWar.defenderClanId = clanId
    targetWar.defenderName = pClan.name
    targetWar.defenderTag = pClan.tag
    targetWar.defenderColor = pClan.tag_color or '#00ffcc'
    targetWar.isNeutralCapture = false
    targetWar.captureTarget = nil
    targetWar.scoreTarget = SunsetTurfs.WarScoreTarget
    targetWar.rallyUntil = nil
    targetWar.rallyRemaining = 0
    targetWar.expiresAt = math.max(targetWar.expiresAt, os.time() + SunsetTurfs.WarDurationSec)

    -- Register all online members of the intervening clan as defenders.
    local joined = 0
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if src then
            local mClan = getPlayerClan(src)
            if mClan and tonumber(mClan.clan_id) == clanId and not targetWar.participants[src] then
                targetWar.participants[src] = { clanId = clanId, kills = 0, deaths = 0, name = GetPlayerName(src) or '?' }
                TriggerClientEvent('sunset:turfs:warJoined', src, { turfId = targetTurfId, role = 'defender' })
                joined = joined + 1
            end
        end
    end

    -- Re-broadcast so every client sees the contested war state.
    TriggerClientEvent('sunset:turfs:warStart', -1, targetWar)

    local announcement = ('^3[TURF WAR] ^7Clan ^3[%s] %s^7 intervened on unowned territory ^2%s^7 — the capture is now a contested war against ^3[%s] %s^7!'):format(
        pClan.tag, pClan.name, targetWar.turfName or '?', targetWar.attackerTag or '--', targetWar.attackerName or '?'
    )
    TriggerClientEvent('chat:addMessage', -1, { color = { 255, 204, 0 }, args = { 'WAR', announcement } })
    log(('intervene src=%s clan=%s turf=%s joined=%d'):format(source, tostring(clanId), tostring(targetTurfId), joined))
end

RegisterCommand('intervene', function(source)
    runIntervene(source)
end, false)

-- Kill hook inside turf wars
-- [AUDIT P6-12] A dissolved clan must lose its turfs and any wars it is in.
AddEventHandler('sunset:clans:dissolved', function(clanId)
    clanId = tonumber(clanId)
    if not clanId then return end
    for turfId, war in pairs(ActiveWars) do
        if tonumber(war.attackerClanId) == clanId or tonumber(war.defenderClanId) == clanId then
            -- No ownership change: simply abort the war (both parties gone/invalid).
            ActiveWars[turfId] = nil
            TurfCooldowns[turfId] = os.time() + SunsetTurfs.TurfCooldownSec
            TriggerClientEvent('sunset:turfs:warEnd', -1, {
                turfId = turfId,
                turfName = Turfs[turfId] and Turfs[turfId].name or '?',
                winnerName = nil, winnerTag = nil,
                attackerScore = war.attackerScore or 0,
                defenderScore = war.defenderScore or 0,
            })
        end
    end
    MySQL.update.await('UPDATE turfs SET owner_clan_id = NULL WHERE owner_clan_id = ?', { clanId })
    for _, turf in pairs(Turfs) do
        if tonumber(turf.ownerClanId) == clanId then
            turf.ownerClanId = nil
            turf.ownerName = nil
            turf.ownerTag = nil
            turf.ownerColor = nil
        end
    end
    syncTurfsToClient(-1)
end)

-- [WAR KILL FIX] recordAttacker fires on EVERY weapon hit, not on kills —
-- previously each bullet scored team points ("I shoot someone, get points,
-- they're still alive"). Now hits only RECORD the last aggressor; the kill is
-- scored when the victim actually dies and requests the war respawn.
local LastWarHit = {} -- [victimSrc] = { attacker = src, at = os.time() }

AddEventHandler('sunset:death:recordAttacker', function(victimSrc, attackerSrc)
    victimSrc = tonumber(victimSrc)
    attackerSrc = tonumber(attackerSrc)
    if not victimSrc or not attackerSrc or victimSrc == attackerSrc then return end
    LastWarHit[victimSrc] = { attacker = attackerSrc, at = os.time() }
end)

local function scoreWarKill(victimSrc, turfId)
    local war = ActiveWars[turfId]
    if not war then return end
    local hit = LastWarHit[victimSrc]
    LastWarHit[victimSrc] = nil
    if not hit or (os.time() - hit.at) > 15 then return end
    local attackerSrc = hit.attacker
    if not GetPlayerName(attackerSrc) then return end

    local aClan = getPlayerClan(attackerSrc)
    local vClan = getPlayerClan(victimSrc)
    if not aClan or not vClan then return end

    local function bump(src, field)
        if war.participants[src] then
            war.participants[src][field] = (war.participants[src][field] or 0) + 1
        end
    end

    local scoringClan
    if aClan.clan_id == war.attackerClanId and vClan.clan_id == war.defenderClanId then
        scoringClan = 'attacker'
    elseif aClan.clan_id == war.defenderClanId and vClan.clan_id == war.attackerClanId then
        scoringClan = 'defender'
    end
    if not scoringClan then return end

    if scoringClan == 'attacker' then
        war.attackerScore = war.attackerScore + SunsetTurfs.ScorePerKill
    else
        war.defenderScore = war.defenderScore + SunsetTurfs.ScorePerKill
    end
    bump(attackerSrc, 'kills')
    bump(victimSrc, 'deaths')
    TriggerClientEvent('sunset:turfs:warKill', -1, {
        killer = GetPlayerName(attackerSrc),
        victim = GetPlayerName(victimSrc),
        clanTag = aClan.tag,
        turfId = turfId,
    })
    if war.scoreTarget then
        local score = scoringClan == 'attacker' and war.attackerScore or war.defenderScore
        if score >= war.scoreTarget then
            endWar(turfId, 'score_target')
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  [WAR REDESIGN] ARMORY (loadout chooser) + WAR RESPAWN
--  Server-authoritative: package list, rank/cost checks, weapon
--  granting happens via client event AFTER validation; respawn
--  coords always come from the server.
-- ═══════════════════════════════════════════════════════════════

local function findActiveWarForSource(src)
    for _, war in pairs(ActiveWars) do
        if war.participants[src] then
            return war
        end
    end
    return nil
end

local function getLoadoutById(id)
    for _, pkg in ipairs(SunsetTurfs.Loadouts or {}) do
        if pkg.id == id then return pkg end
    end
    return nil
end

-- Armory data for the UI: packages + which the player can afford/rank.
exports.sunset_core:RegisterCallback('sunset:turfs:armoryData', function(source)
    local war = findActiveWarForSource(source)
    if not war then return nil, 'You are not in an active war.' end
    local pClan = getPlayerClan(source)
    if not pClan then return nil, 'You are not in a clan.' end

    local packages = {}
    for _, pkg in ipairs(SunsetTurfs.Loadouts or {}) do
        local rankOk = (tonumber(pClan.rank) or 0) >= (pkg.rank or 1)
        local weapons = {}
        for _, w in ipairs(pkg.weapons or {}) do
            weapons[#weapons + 1] = { label = w.label or w.weapon, ammo = w.ammo, tag = w.tag or '' }
        end
        packages[#packages + 1] = {
            id = pkg.id,
            name = pkg.name,
            cost = pkg.cost or 0,
            rank = pkg.rank or 1,
            rankOk = rankOk,
            weapons = weapons,
        }
    end

    local turf = Turfs[war.turfId]
    return {
        packages = packages,
        turfId = war.turfId,
        turfName = turf and turf.name or '?',
        role = tonumber(pClan.clan_id) == tonumber(war.attackerClanId) and 'attacker' or 'defender',
        respawnDelay = SunsetTurfs.RespawnDelaySec or 5,
        warEndsAt = war.expiresAt,
    }
end)

-- Buy/equip a loadout. Validates rank, cost (RemoveMoney), war participation,
-- then tells the client which weapons to give locally (server keeps the list
-- so respawn re-grants the same kit).
exports.sunset_core:RegisterCallback('sunset:turfs:takeLoadout', function(source, loadoutId)
    local war = findActiveWarForSource(source)
    if not war then return nil, 'You are not in an active war.' end
    local pClan = getPlayerClan(source)
    if not pClan then return nil, 'You are not in a clan.' end

    local pkg = getLoadoutById(tostring(loadoutId or ''))
    if not pkg then return nil, 'Invalid package.' end
    if (tonumber(pClan.rank) or 0) < (pkg.rank or 1) then
        return nil, ('You need rank %d for this package.'):format(pkg.rank or 1)
    end

    -- One free loadout per war participant; paid packages can be re-bought.
    local participant = war.participants[source]
    if (pkg.cost or 0) > 0 then
        if not exports.sunset_core:RemoveMoney(source, 'cash', pkg.cost, 'turf_loadout') then
            if not exports.sunset_core:RemoveMoney(source, 'bank', pkg.cost, 'turf_loadout') then
                return nil, ('You do not have $%s for this package.'):format(pkg.cost)
            end
        end
    elseif participant.loadoutTaken then
        return nil, 'You already took the free package for this war.'
    end
    participant.loadoutTaken = true
    participant.loadout = pkg.id

    TriggerClientEvent('sunset:turfs:grantLoadout', source, {
        weapons = pkg.weapons,
        armor = pkg.armor or 0,
        heal = true,
    })
    return true, pkg.name
end)

-- War respawn: server picks a spawn point inside the turf zone and validates
-- the player is a participant, dead/downed, and the war is still active.
exports.sunset_core:RegisterCallback('sunset:turfs:warRespawn', function(source)
    local war = findActiveWarForSource(source)
    if not war then return nil, 'You are not in an active war.' end
    local turf = Turfs[war.turfId]
    if not turf then return nil, 'Invalid territory.' end

    local participant = war.participants[source]
    if not participant then return nil, 'You are no longer part of this war.' end

    -- [WAR KILL FIX] The victim actually died and used the war respawn: this is
    -- the authoritative kill moment. Score it now (not on every hit).
    scoreWarKill(source, war.turfId)

    -- Respawn point: random offset inside the zone.
    local angle = math.random() * 2 * math.pi
    local dist = math.random() * (turf.radius * 0.5)
    local spawn = vector3(
        turf.coords.x + math.cos(angle) * dist,
        turf.coords.y + math.sin(angle) * dist,
        turf.coords.z
    )

    local pkg = participant.loadout and getLoadoutById(participant.loadout) or nil

    -- Clear server-side downed state (sunset_death) so bleedout timers and
    -- /respawn do not race the war respawn; this is a server-owned revive.
    if GetResourceState('sunset_death') == 'started' then
        pcall(function() exports.sunset_death:ClearDownedForCustody(source) end)
    end

    TriggerClientEvent('sunset:turfs:doWarRespawn', source, {
        coords = { x = spawn.x, y = spawn.y, z = spawn.z },
        weapons = pkg and pkg.weapons or nil,
        armor = pkg and pkg.armor or 50,
    })
    return true
end)

-- Scoreboard data (Z key during war).
exports.sunset_core:RegisterCallback('sunset:turfs:warScoreboard', function(source)
    local war = findActiveWarForSource(source)
    if not war then return nil end
    local rows = {}
    for src, p in pairs(war.participants) do
        rows[#rows + 1] = {
            name = GetPlayerName(src) or p.name or '?',
            kills = p.kills or 0,
            deaths = p.deaths or 0,
            side = tonumber(p.clanId) == tonumber(war.attackerClanId) and 'attacker' or 'defender',
        }
    end
    table.sort(rows, function(a, b) return a.kills > b.kills end)
    return {
        rows = rows,
        attackerName = war.attackerName,
        defenderName = war.defenderName,
        attackerScore = war.attackerScore,
        defenderScore = war.defenderScore,
        scoreTarget = war.scoreTarget,
        turfName = war.turfName,
        remainingSec = math.max(0, war.expiresAt - os.time()),
    }
end)

-- [WAR REDESIGN] Export so sunset_death can suppress EMS dispatch for war
-- deaths (kill-feed respawn loop, not a medical emergency).
exports('IsInWar', function(src)
    src = tonumber(src)
    if not src then return false end
    for _, war in pairs(ActiveWars) do
        if war.participants[src] then return true end
    end
    return false
end)

-- Remove participants on disconnect (war keeps running; scores stay).
AddEventHandler('playerDropped', function()
    local src = source
    LastWarHit[src] = nil
    for _, war in pairs(ActiveWars) do
        if war.participants[src] then
            war.participants[src] = nil
        end
    end
end)

-- Payday Payouts for controlled turfs
AddEventHandler('sunset:payday:processed', function(source)
    local pClan = getPlayerClan(source)
    if not pClan or (tonumber(pClan.rank) or 0) < 5 then return end -- Leader processes once

    local count = 0
    local totalPayout = 0
    for _, t in pairs(Turfs) do
        if t.ownerClanId and t.ownerClanId == pClan.clan_id then
            count = count + 1
            totalPayout = totalPayout + t.payout
        end
    end

    if count > 0 and totalPayout > 0 then
        exports.sunset_core:AddMoney(source, 'bank', totalPayout, 'turf_payout')
        TriggerClientEvent('sunset:client:notify', source,
            ('Your clan collected $%s from %d controlled territories (deposited to your bank).'):format(
                tostring(math.floor(totalPayout)), count
            ), 'success', 10000)
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  ADMIN & TESTING COMMANDS (Instant 1v1 & War Control)
-- ═══════════════════════════════════════════════════════════════

local function checkAdmin(source, minLevel)
    if source == 0 then return true end
    if GetResourceState('sunset_admin') == 'started' then
        return exports.sunset_admin:IsAdmin(source, minLevel or 2)
    end
    return IsPlayerAceAllowed(source, 'command')
end

local function runTurflist(source)
    if not checkAdmin(source, 1) then
        TriggerClientEvent('sunset:client:notify', source, 'You do not have the required permission.', 'error')
        return
    end

    local rows = {}
    for id, t in pairs(Turfs) do
        rows[#rows + 1] = {
            id = id,
            name = t.name,
            ownerTag = t.ownerTag or '--',
            ownerName = t.ownerName or 'Free',
            war = ActiveWars[id] ~= nil,
        }
    end

    table.sort(rows, function(a, b) return a.id < b.id end)

    if #rows == 0 then
        local empty = 'No territories in DB. Check migration 34-turfs.sql.'
        if source == 0 then
            print(('[sunset_turfs] %s'):format(empty))
        else
            TriggerClientEvent('sunset:client:notify', source, empty, 'warning', 8000)
        end
        return
    end

    for _, row in ipairs(rows) do
        local status = row.war and '[WAR]' or '[PACE]'
        local msg = ('#%02d %s | Owner: %s (%s) | %s'):format(
            row.id, row.name, row.ownerTag, row.ownerName, status
        )
        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('sunset:chat:system', source, msg, 'info')
        end
    end

    if source ~= 0 then
        TriggerClientEvent('sunset:client:notify', source,
            ('%d territories listed in chat.'):format(#rows), 'success', 5000)
    end
end

RegisterCommand('turflist', function(source)
    runTurflist(source)
end, false)

local function runGototurf(source, args)
    if source == 0 then print('Comanda doar in joc.'); return end
    if not checkAdmin(source, 2) then
        TriggerClientEvent('sunset:client:notify', source, 'You do not have the required permission.', 'error')
        return
    end

    local turfId = tonumber(args[1])
    local turf = turfId and Turfs[turfId]
    if not turf then
        TriggerClientEvent('sunset:client:notify', source, 'Usage: /gototurf [1-16]. See /turflist', 'warning')
        return
    end

    TriggerClientEvent('sunset:turfs:teleport', source, turf.coords)
    TriggerClientEvent('sunset:client:notify', source, ('Teleported to territory #%d (%s)'):format(turf.id, turf.name), 'success')
end

RegisterCommand('gototurf', function(source, args)
    runGototurf(source, args)
end, false)

local function runForceturf(source, args)
    if not checkAdmin(source, 2) then
        TriggerClientEvent('sunset:client:notify', source, 'You do not have the required permission.', 'error')
        return
    end

    local turfId = tonumber(args[1])
    local turf = turfId and Turfs[turfId]
    if not turf then
        local tip = 'Usage: /forceturf [turfId (1-16)] [optional attackerClanId]'
        if source == 0 then print(tip) else TriggerClientEvent('sunset:client:notify', source, tip, 'warning') end
        return
    end

    if ActiveWars[turf.id] then
        local msg = ('Territory #%d is already in an active war! Use /stopwar %d'):format(turf.id, turf.id)
        if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'error') end
        return
    end

    local attackerClan = nil
    local forcedClanId = tonumber(args[2])

    if forcedClanId then
        attackerClan = MySQL.single.await('SELECT id AS clan_id, name, tag, tag_color FROM clans WHERE id = ?', { forcedClanId })
    elseif source ~= 0 then
        attackerClan = getPlayerClan(source)
    end

    if not attackerClan then
        -- Default fallback to first clan in DB if none provided
        attackerClan = MySQL.single.await('SELECT id AS clan_id, name, tag, tag_color FROM clans LIMIT 1')
    end

    if not attackerClan then
        local err = 'No clans exist in the database to start a war. Create a clan first!'
        if source == 0 then print(err) else TriggerClientEvent('sunset:client:notify', source, err, 'error') end
        return
    end

    local defenderClan = nil
    if turf.ownerClanId then
        defenderClan = MySQL.single.await('SELECT id, name, tag, tag_color FROM clans WHERE id = ?', { turf.ownerClanId })
    end

    -- Clear any existing cooldown
    TurfCooldowns[turf.id] = nil

    startWar(turf, attackerClan, defenderClan)

    local note = ('[ADMIN] War forced on territory #%d (%s) by [%s] %s'):format(
        turf.id, turf.name, attackerClan.tag, attackerClan.name
    )
    if source == 0 then print(note) else TriggerClientEvent('sunset:client:notify', source, note, 'success') end
end

RegisterCommand('forceturf', function(source, args)
    runForceturf(source, args)
end, false)

local function runStopwar(source, args)
    if not checkAdmin(source, 2) then
        TriggerClientEvent('sunset:client:notify', source, 'You do not have the required permission.', 'error')
        return
    end

    local turfId = tonumber(args[1])
    if not turfId or not ActiveWars[turfId] then
        local msg = 'Usage: /stopwar [turfId]. No active war on this ID.'
        if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'warning') end
        return
    end

    endWar(turfId, 'admin_force_stop')
    local note = ('[ADMIN] The war for territory #%d was force-stopped.'):format(turfId)
    if source == 0 then print(note) else TriggerClientEvent('sunset:client:notify', source, note, 'info') end
end

RegisterCommand('stopwar', function(source, args)
    runStopwar(source, args)
end, false)

local function runResetturfcd(source, args)
    if not checkAdmin(source, 2) then
        TriggerClientEvent('sunset:client:notify', source, 'You do not have the required permission.', 'error')
        return
    end

    local target = args[1]
    if target == 'all' then
        TurfCooldowns = {}
        local msg = 'All territory cooldowns have been reset!'
        if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'success') end
    else
        local id = tonumber(target)
        if id and Turfs[id] then
            TurfCooldowns[id] = nil
            local msg = ('Cooldown reset for territory #%d (%s)'):format(id, Turfs[id].name)
            if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'success') end
        else
            local msg = 'Usage: /resetturfcd [1-16] or /resetturfcd all'
            if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'warning') end
        end
    end
end

RegisterCommand('resetturfcd', function(source, args)
    runResetturfcd(source, args)
end, false)

function RunChatCommand(source, name, args)
    if source == 0 then return false end
    name = string.lower(tostring(name or ''))
    args = args or {}
    if name == 'attackturf' or name == 'atac' or name == 'attack' then
        runAttackTurf(source)
        return true
    end
    return false
end
exports('RunChatCommand', RunChatCommand)

function ExecutePlayerCommand(source, name, args)
    name = string.lower(tostring(name or ''))
    args = args or {}
    if name == 'turflist' then
        runTurflist(source)
        return true
    end
    if name == 'gototurf' then
        runGototurf(source, args)
        return true
    end
    if name == 'forceturf' then
        runForceturf(source, args)
        return true
    end
    if name == 'stopwar' then
        runStopwar(source, args)
        return true
    end
    if name == 'resetturfcd' then
        runResetturfcd(source, args)
        return true
    end
    return false
end
exports('ExecutePlayerCommand', ExecutePlayerCommand)
