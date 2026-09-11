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

local function getPlayerClan(src)
    local char = exports.sunset_core:GetCharacter(src)
    if not char then return nil end

    local row = MySQL.single.await([[
        SELECT cm.clan_id, cm.rank, c.name, c.tag, c.tag_color
        FROM clan_members cm
        JOIN clans c ON c.id = cm.clan_id
        WHERE cm.character_id = ?
        LIMIT 1
    ]], { char.id })
    return row
end

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
            ownerName = r.clan_name or 'Liber',
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
                local pClan = getPlayerClan(src)
                if pClan and tonumber(pClan.clan_id) == tonumber(clanId) then
                    count = count + 1
                    table.insert(peds, src)
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
    local loserClanName = attackerWon and war.defenderName or war.attackerName

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

    syncTurfsToClient(-1)
    TriggerClientEvent('sunset:turfs:warEnd', -1, {
        turfId = turfId,
        turfName = turf.name,
        winnerName = winnerClanName,
        winnerTag = winnerClanTag,
        attackerScore = war.attackerScore,
        defenderScore = war.defenderScore,
    })

    local announcement = ('^2[TURF WAR] ^7Razboiul pentru ^3%s^7 s-a incheiat! ^2[%s] %s^7 a castigat teritoriul (%d vs %d puncte)!'):format(
        turf.name, winnerClanTag or '--', winnerClanName or 'Necunoscut', war.attackerScore, war.defenderScore
    )
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
        defenderName = defenderClan and defenderClan.name or 'Liber (neocupat)',
        defenderTag = defenderClan and defenderClan.tag or 'LIBER',
        defenderColor = defenderClan and defenderClan.tag_color or '#555555',
        defenderScore = 0,
        isNeutralCapture = isNeutralCapture,
        captureTarget = captureTarget,
        startedAt = os.time(),
        expiresAt = os.time() + durationSec,
    }

    ActiveWars[turfId] = warData
    TriggerClientEvent('sunset:turfs:warStart', -1, warData)

    local announcement = ('^1[TURF WAR] ^7Clanul ^3[%s] %s^7 a atacat teritoriul ^2%s^7 detinut de ^3[%s] %s^7! Durata: 10 minute.'):format(
        attackerClan.tag, attackerClan.name, turf.name, warData.defenderTag, warData.defenderName
    )
    TriggerClientEvent('chat:addMessage', -1, { color = { 255, 50, 50 }, args = { 'WAR', announcement } })

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
            local attCount = getClanMembersInTurf(current.attackerClanId, turf)
            local defCount = current.defenderClanId and getClanMembersInTurf(current.defenderClanId, turf) or 0

            if attCount > 0 then
                current.attackerScore = current.attackerScore + (attCount * SunsetTurfs.ScorePerSecond)
            end
            if current.defenderClanId and defCount > 0 then
                current.defenderScore = current.defenderScore + (defCount * SunsetTurfs.ScorePerSecond)
            end

            if current.isNeutralCapture and attCount > 0
                and current.attackerScore >= (current.captureTarget or SunsetTurfs.NeutralCaptureSec or 180) then
                endWar(turfId, 'neutral_captured')
                break
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
        TriggerClientEvent('sunset:client:notify', source, 'Nu faci parte din niciun clan.', 'error')
        return
    end

    if not canDeclareTurfAttack(pClan.rank) then
        TriggerClientEvent('sunset:client:notify', source, 'Doar ofiterii si liderii de clan (rank 5+) pot declara un atac.', 'error')
        return
    end

    local pCoords = GetEntityCoords(ped)
    local turf = findTurfAtCoords(pCoords)
    if not turf then
        TriggerClientEvent('sunset:client:notify', source, 'Nu te afli in interiorul niciunui teritoriu. Vezi blip-urile de pe harta.', 'error')
        return
    end

    if turf.ownerClanId and tonumber(turf.ownerClanId) == tonumber(pClan.clan_id) then
        TriggerClientEvent('sunset:client:notify', source, 'Acest teritoriu este deja controlat de clanul tau!', 'info')
        return
    end

    if ActiveWars[turf.id] then
        TriggerClientEvent('sunset:client:notify', source, 'Acest teritoriu este deja intr-un razboi activ.', 'warning')
        return
    end

    local cd = TurfCooldowns[turf.id] or 0
    if os.time() < cd then
        local remMin = math.ceil((cd - os.time()) / 60)
        TriggerClientEvent('sunset:client:notify', source, ('Acest teritoriu este sub protectie post-razboi inca %d minute.'):format(remMin), 'warning')
        return
    end

    for _, activeWar in pairs(ActiveWars) do
        if tonumber(activeWar.attackerClanId) == tonumber(pClan.clan_id)
            or tonumber(activeWar.defenderClanId) == tonumber(pClan.clan_id) then
            TriggerClientEvent('sunset:client:notify', source, 'Clanul tau este deja angajat intr-un razboi pe alt teritoriu!', 'error')
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

-- Kill hook inside turf wars
AddEventHandler('sunset:death:recordAttacker', function(victimSrc, attackerSrc)
    victimSrc = tonumber(victimSrc)
    attackerSrc = tonumber(attackerSrc)
    if not victimSrc or not attackerSrc or victimSrc == attackerSrc then return end

    local aPed = GetPlayerPed(attackerSrc)
    if not aPed or aPed == 0 then return end
    local coords = GetEntityCoords(aPed)
    local turf = findTurfAtCoords(coords)
    if not turf or not ActiveWars[turf.id] then return end

    local war = ActiveWars[turf.id]
    local aClan = getPlayerClan(attackerSrc)
    local vClan = getPlayerClan(victimSrc)
    if not aClan or not vClan then return end

    if aClan.clan_id == war.attackerClanId and vClan.clan_id == war.defenderClanId then
        war.attackerScore = war.attackerScore + SunsetTurfs.ScorePerKill
        TriggerClientEvent('sunset:turfs:warKill', -1, {
            killer = GetPlayerName(attackerSrc),
            victim = GetPlayerName(victimSrc),
            clanTag = aClan.tag,
            turfId = turf.id
        })
    elseif aClan.clan_id == war.defenderClanId and vClan.clan_id == war.attackerClanId then
        war.defenderScore = war.defenderScore + SunsetTurfs.ScorePerKill
        TriggerClientEvent('sunset:turfs:warKill', -1, {
            killer = GetPlayerName(attackerSrc),
            victim = GetPlayerName(victimSrc),
            clanTag = aClan.tag,
            turfId = turf.id
        })
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
            ('Clanul tau a incasat $%s din cele %d teritorii controlate (virat in banca ta).'):format(
                string.format('%\'d', totalPayout):gsub('\'', ','), count
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
        TriggerClientEvent('sunset:client:notify', source, 'Nu ai permisiunea necesara.', 'error')
        return
    end

    local rows = {}
    for id, t in pairs(Turfs) do
        rows[#rows + 1] = {
            id = id,
            name = t.name,
            ownerTag = t.ownerTag or '--',
            ownerName = t.ownerName or 'Liber',
            war = ActiveWars[id] ~= nil,
        }
    end

    table.sort(rows, function(a, b) return a.id < b.id end)

    if #rows == 0 then
        local empty = 'Niciun teritoriu in DB. Verifica migrarea 34-turfs.sql.'
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
            ('%d teritorii listate in chat.'):format(#rows), 'success', 5000)
    end
end

RegisterCommand('turflist', function(source)
    runTurflist(source)
end, false)

local function runGototurf(source, args)
    if source == 0 then print('Comanda doar in joc.'); return end
    if not checkAdmin(source, 2) then
        TriggerClientEvent('sunset:client:notify', source, 'Nu ai permisiunea necesara.', 'error')
        return
    end

    local turfId = tonumber(args[1])
    local turf = turfId and Turfs[turfId]
    if not turf then
        TriggerClientEvent('sunset:client:notify', source, 'Folosire: /gototurf [1-16]. Vezi /turflist', 'warning')
        return
    end

    TriggerClientEvent('sunset:turfs:teleport', source, turf.coords)
    TriggerClientEvent('sunset:client:notify', source, ('Te-ai teleportat la teritoriul #%d (%s)'):format(turf.id, turf.name), 'success')
end

RegisterCommand('gototurf', function(source, args)
    runGototurf(source, args)
end, false)

local function runForceturf(source, args)
    if not checkAdmin(source, 2) then
        TriggerClientEvent('sunset:client:notify', source, 'Nu ai permisiunea necesara.', 'error')
        return
    end

    local turfId = tonumber(args[1])
    local turf = turfId and Turfs[turfId]
    if not turf then
        local tip = 'Folosire: /forceturf [turfId (1-16)] [optional attackerClanId]'
        if source == 0 then print(tip) else TriggerClientEvent('sunset:client:notify', source, tip, 'warning') end
        return
    end

    if ActiveWars[turf.id] then
        local msg = ('Teritoriul #%d este deja intr-un razboi activ! Foloseste /stopwar %d'):format(turf.id, turf.id)
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
        local err = 'Nu exista clanuri in baza de date pentru a porni razboiul. Creeaza un clan mai intai!'
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

    local note = ('[ADMIN] Razboi fortat pe teritoriul #%d (%s) de catre [%s] %s'):format(
        turf.id, turf.name, attackerClan.tag, attackerClan.name
    )
    if source == 0 then print(note) else TriggerClientEvent('sunset:client:notify', source, note, 'success') end
end

RegisterCommand('forceturf', function(source, args)
    runForceturf(source, args)
end, false)

local function runStopwar(source, args)
    if not checkAdmin(source, 2) then
        TriggerClientEvent('sunset:client:notify', source, 'Nu ai permisiunea necesara.', 'error')
        return
    end

    local turfId = tonumber(args[1])
    if not turfId or not ActiveWars[turfId] then
        local msg = 'Folosire: /stopwar [turfId]. Niciun razboi activ pe acest ID.'
        if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'warning') end
        return
    end

    endWar(turfId, 'admin_force_stop')
    local note = ('[ADMIN] Razboiul pentru teritoriul #%d a fost oprit fortat.'):format(turfId)
    if source == 0 then print(note) else TriggerClientEvent('sunset:client:notify', source, note, 'info') end
end

RegisterCommand('stopwar', function(source, args)
    runStopwar(source, args)
end, false)

local function runResetturfcd(source, args)
    if not checkAdmin(source, 2) then
        TriggerClientEvent('sunset:client:notify', source, 'Nu ai permisiunea necesara.', 'error')
        return
    end

    local target = args[1]
    if target == 'all' then
        TurfCooldowns = {}
        local msg = 'Toate cooldown-urile de teritorii au fost resetate!'
        if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'success') end
    else
        local id = tonumber(target)
        if id and Turfs[id] then
            TurfCooldowns[id] = nil
            local msg = ('Cooldown resetat pentru teritoriul #%d (%s)'):format(id, Turfs[id].name)
            if source == 0 then print(msg) else TriggerClientEvent('sunset:client:notify', source, msg, 'success') end
        else
            local msg = 'Folosire: /resetturfcd [1-16] sau /resetturfcd all'
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
