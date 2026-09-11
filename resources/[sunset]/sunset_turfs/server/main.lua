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
    pcall(loadTurfsFromDb)
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
                if pClan and pClan.clan_id == clanId then
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
    local attackerWon = war.attackerScore > war.defenderScore

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
        defenderName = defenderClan and defenderClan.name or 'Nimanui (Liber)',
        defenderTag = defenderClan and defenderClan.tag or 'FREE',
        defenderColor = defenderClan and defenderClan.tag_color or '#555555',
        defenderScore = 0,
        startedAt = os.time(),
        expiresAt = os.time() + SunsetTurfs.WarDurationSec,
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
            if defCount > 0 then
                current.defenderScore = current.defenderScore + (defCount * SunsetTurfs.ScorePerSecond)
            end

            current.attackerCount = attCount
            current.defenderCount = defCount
            current.remainingSec = math.max(0, current.expiresAt - os.time())

            TriggerClientEvent('sunset:turfs:warTick', -1, current)
        end
    end)
end

-- Attack command
RegisterCommand('attackturf', function(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local pClan = getPlayerClan(source)
    if not pClan then
        TriggerClientEvent('sunset:client:notify', source, 'Nu faci parte din niciun clan.', 'error')
        return
    end

    if (tonumber(pClan.rank) or 0) < 2 then
        TriggerClientEvent('sunset:client:notify', source, 'Doar liderul sau ofiterii de clan pot declara un atac de teritoriu.', 'error')
        return
    end

    local pCoords = GetEntityCoords(ped)
    local turf = findTurfAtCoords(pCoords)
    if not turf then
        TriggerClientEvent('sunset:client:notify', source, 'Nu te afli in interiorul niciunui teritoriu.', 'error')
        return
    end

    if turf.ownerClanId and turf.ownerClanId == pClan.clan_id then
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

    -- Check if clan is already fighting elsewhere
    for _, activeWar in pairs(ActiveWars) do
        if activeWar.attackerClanId == pClan.clan_id or activeWar.defenderClanId == pClan.clan_id then
            TriggerClientEvent('sunset:client:notify', source, 'Clanul tau este deja angajat intr-un razboi pe alt teritoriu!', 'error')
            return
        end
    end

    local defenderClan = nil
    if turf.ownerClanId then
        defenderClan = MySQL.single.await('SELECT id, name, tag, tag_color FROM clans WHERE id = ?', { turf.ownerClanId })
    end

    startWar(turf, pClan, defenderClan)
end, false)

TriggerEvent('chat:addSuggestion', '/attackturf', 'Ataca teritoriul in care te afli pentru a porni un razboi de clan')

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
        MySQL.update.await('UPDATE clans SET balance = balance + ? WHERE id = ?', { totalPayout, pClan.clan_id })
        TriggerClientEvent('sunset:client:notify', source,
            ('Clanul tau a incasat $%s din cele %d teritorii controlate!'):format(
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

-- /turflist - lists all territories and status
RegisterCommand('turflist', function(source)
    if not checkAdmin(source, 1) then
        TriggerClientEvent('sunset:client:notify', source, 'Nu ai permisiunea necesara.', 'error')
        return
    end

    local out = {}
    for id, t in pairs(Turfs) do
        local status = ActiveWars[id] and '^1[WAR ACTIV]^7' or '^2[PACE]^7'
        local msg = ('#%02d %s | Owner: %s (%s) | %s'):format(id, t.name, t.ownerTag or '--', t.ownerName or 'Liber', status)
        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('chat:addMessage', source, { color = { 0, 255, 204 }, args = { 'TURFS', msg } })
        end
    end
end, false)

-- /gototurf [turfId] - teleports admin to territory
RegisterCommand('gototurf', function(source, args)
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
end, false)

-- /forceturf [turfId] [optional attackerClanId] - starts war instantly (bypasses cooldown and distance)
RegisterCommand('forceturf', function(source, args)
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
end, false)

-- /stopwar [turfId] - terminates war immediately
RegisterCommand('stopwar', function(source, args)
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
end, false)

-- /resetturfcd [turfId or "all"]
RegisterCommand('resetturfcd', function(source, args)
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
end, false)
