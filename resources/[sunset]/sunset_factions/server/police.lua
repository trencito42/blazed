Police = Police or {}

local WantedOnline = {}
local JailedOnline = {}

local function notify(source, msg, typ, duration)
    FactionCore.notify(source, msg, typ or 'info', duration)
end

local function charId(source)
    local char = FactionCore.getChar(source)
    return char and char.id
end

local function syncWantedBag(source, data)
    Player(source).state:set('sunsetWanted', data, true)
end

local function syncJailBag(source, data)
    Player(source).state:set('sunsetJailed', data, true)
end

local function syncWantedClient(targetId, level, reason)
    TriggerClientEvent('sunset:client:wantedUpdate', targetId, level or 0, reason or '')
end

function Police.loadWantedFromDb(characterId)
    local row = MySQL.single.await([[
        SELECT id, character_id, level, reason_code, reason_label, jail_minutes,
               UNIX_TIMESTAMP(expires_at) AS expires_at
        FROM wanted_records
        WHERE character_id = ? AND active = 1
          AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY id DESC LIMIT 1
    ]], { characterId })
    if not row then return nil end
    return {
        level = row.level,
        reason = row.reason_label,
        reasonCode = row.reason_code,
        jailMinutes = row.jail_minutes,
        decayAt = row.expires_at,
        recordId = row.id,
        characterId = row.character_id,
    }
end

function Police.saveWantedToDb(characterId, data, issuedBy)
    MySQL.update.await(
        'UPDATE wanted_records SET active = 0, cleared_at = NOW() WHERE character_id = ? AND active = 1',
        { characterId }
    )
    MySQL.insert.await([[
        INSERT INTO wanted_records
            (character_id, level, reason_code, reason_label, issued_by_character_id, jail_minutes, active, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, 1, FROM_UNIXTIME(?))
    ]], {
        characterId,
        data.level,
        data.reasonCode,
        data.reason,
        issuedBy,
        data.jailMinutes,
        data.decayAt,
    })
end

function Police.deleteWantedFromDb(characterId, clearedBy)
    MySQL.update.await(
        'UPDATE wanted_records SET active = 0, cleared_at = NOW(), cleared_by_character_id = ? WHERE character_id = ? AND active = 1',
        { clearedBy, characterId }
    )
end

function Police.loadJailFromDb(characterId)
    return MySQL.single.await([[
        SELECT id, character_id, reason, duration_minutes, officer_character_id,
               UNIX_TIMESTAMP(ends_at) AS release_at
        FROM jail_sentences
        WHERE character_id = ? AND status = 'active' AND ends_at > NOW()
        ORDER BY id DESC LIMIT 1
    ]], { characterId })
end

function Police.saveJailToDb(characterId, releaseAt, minutes, reason, officerCharId)
    MySQL.update.await(
        "UPDATE jail_sentences SET status = 'served', released_at = NOW() WHERE character_id = ? AND status = 'active'",
        { characterId }
    )
    MySQL.insert.await([[
        INSERT INTO jail_sentences
            (character_id, officer_character_id, reason, duration_minutes, started_at, ends_at, status)
        VALUES (?, ?, ?, ?, NOW(), FROM_UNIXTIME(?), 'active')
    ]], { characterId, officerCharId, reason or '', minutes, releaseAt })
end

function Police.clearJailFromDb(characterId)
    MySQL.update.await(
        "UPDATE jail_sentences SET status = 'served', released_at = NOW() WHERE character_id = ? AND status = 'active'",
        { characterId }
    )
end

local function applyWanted(source, data)
    WantedOnline[source] = data
    syncWantedBag(source, {
        level = data.level,
        reason = data.reason,
        reasonCode = data.reasonCode,
        decayAt = data.decayAt,
    })
    syncWantedClient(source, data.level, data.reason)
end

local function setWanted(targetId, level, reason, reasonCode, jailMinutes, issuedBy)
    level = math.max(1, math.min(5, tonumber(level) or 1))
    local decayMin = (Sunset.Police and Sunset.Police.decayMinutes[level]) or 15
    local data = {
        level = level,
        reason = reason or 'Unknown',
        reasonCode = reasonCode or '',
        jailMinutes = jailMinutes or 2,
        decayAt = os.time() + decayMin * 60,
    }

    local cid = charId(targetId)
    if cid then
        Police.saveWantedToDb(cid, data, issuedBy)
    end
    applyWanted(targetId, data)
end

local function clearWanted(targetId, clearedBy)
    local cid = charId(targetId)
    if cid then Police.deleteWantedFromDb(cid, clearedBy) end
    WantedOnline[targetId] = nil
    syncWantedBag(targetId, nil)
    syncWantedClient(targetId, 0, '')
end

function GetWantedState(source)
    return WantedOnline[source]
end
exports('GetWantedState', GetWantedState)

function Police.isJailed(source)
    return JailedOnline[source] ~= nil
end

local function beginJail(targetId, minutes, reason, officerSource)
    minutes = math.max(1, tonumber(minutes) or 2)
    local releaseAt = os.time() + minutes * 60
    local targetCharId = charId(targetId)
    local officerCharId = officerSource and charId(officerSource)

    if targetCharId then
        Police.saveJailToDb(targetCharId, releaseAt, minutes, reason, officerCharId)
    end

    JailedOnline[targetId] = { releaseAt = releaseAt, minutes = minutes, reason = reason }
    syncJailBag(targetId, { releaseAt = releaseAt, minutes = minutes })

    if Detention then
        Detention.setJailed(targetId)
    end

    Detention.setCuffed(targetId, false)
    TriggerClientEvent('sunset:faction:uncuff', targetId)
    TriggerClientEvent('sunset:detention:sync', -1, targetId, {
        cuffed = false,
        escorted = false,
        state = Detention.States.JAILED,
    })

    local jail = Sunset.Police and Sunset.Police.jailCoords
    TriggerClientEvent('sunset:police:jail', targetId, {
        releaseAt = releaseAt,
        minutes = minutes,
        coords = jail and { x = jail.x, y = jail.y, z = jail.z, w = jail.w } or nil,
    })
end

local function endJail(source)
    local cid = charId(source)
    if cid then Police.clearJailFromDb(cid) end
    JailedOnline[source] = nil
    syncJailBag(source, nil)
    if Detention then Detention.releaseJail(source) end
    TriggerClientEvent('sunset:police:release', source)
end

local function isAtJailZone(targetId)
    local targetPos = FactionCore.playerCoords(targetId)
    if not targetPos then return false end

    local radius = Sunset.Police and Sunset.Police.jailRadius or 12.0
    if Sunset.Police and Sunset.Police.pdJailPoint then
        if FactionCore.distBetween(targetPos, Sunset.Police.pdJailPoint) <= radius then
            return true
        end
    end
    if Sunset.Police and Sunset.Police.jailCoords then
        local jail = Sunset.Police.jailCoords
        if FactionCore.distBetween(targetPos, vector3(jail.x, jail.y, jail.z)) <= radius then
            return true
        end
    end
    return false
end

local function buildWantedListRows()
    local now = os.time()
    local rows = MySQL.query.await([[
        SELECT wr.character_id, wr.level, wr.reason_label AS reason, wr.reason_code, wr.jail_minutes,
               UNIX_TIMESTAMP(wr.expires_at) AS decay_at,
               c.firstname, c.lastname
        FROM wanted_records wr
        INNER JOIN characters c ON c.id = wr.character_id
        WHERE wr.active = 1 AND (wr.expires_at IS NULL OR wr.expires_at > NOW())
        ORDER BY wr.level DESC
    ]]) or {}

    local onlineByChar = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local cid = charId(src)
        if cid then onlineByChar[cid] = src end
    end

    local list = {}
    for _, row in ipairs(rows) do
        local src = onlineByChar[row.character_id]
        local remaining = math.max(0, (row.decay_at or now) - now)
        list[#list + 1] = {
            id = src,
            characterId = row.character_id,
            name = ('%s %s'):format(row.firstname or '', row.lastname or ''):gsub('^%s+', ''):gsub('%s+$', ''),
            level = row.level,
            reason = row.reason,
            reasonCode = row.reason_code,
            remainingSec = remaining,
            online = src ~= nil,
        }
    end
    return list
end

function Police.hydratePlayer(source, characterId)
    local jailRow = Police.loadJailFromDb(characterId)
    if jailRow and jailRow.release_at and jailRow.release_at > os.time() then
        local remainingSec = jailRow.release_at - os.time()
        local remainingMin = math.max(1, math.ceil(remainingSec / 60))
        JailedOnline[source] = { releaseAt = jailRow.release_at, minutes = remainingMin, reason = jailRow.reason }
        syncJailBag(source, { releaseAt = jailRow.release_at, minutes = remainingMin })
        if Detention then Detention.setJailed(source) end
        local jail = Sunset.Police and Sunset.Police.jailCoords
        TriggerClientEvent('sunset:police:jail', source, {
            releaseAt = jailRow.release_at,
            minutes = remainingMin,
            coords = jail and { x = jail.x, y = jail.y, z = jail.z, w = jail.w } or nil,
        })
        return
    elseif jailRow then
        Police.clearJailFromDb(characterId)
    end

    local wanted = Police.loadWantedFromDb(characterId)
    if wanted then
        if wanted.decayAt and wanted.decayAt <= os.time() then
            Police.deleteWantedFromDb(characterId, nil)
            syncWantedBag(source, nil)
            syncWantedClient(source, 0, '')
        else
            applyWanted(source, wanted)
        end
    else
        syncWantedBag(source, nil)
        syncWantedClient(source, 0, '')
    end
    syncJailBag(source, nil)
end

exports.sunset_core:RegisterCallback('sunset:policeSetWanted', function(source, targetId, reasonCode)
    if not FactionCore.hasPerm(source, 'wanted') then return nil, 'You must be on-duty law enforcement' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end
    if Police.isJailed(targetId) then return nil, 'Suspect is already in custody' end

    reasonCode = string.lower(reasonCode or '')
    local reasonRow = Sunset.GetPoliceReason(reasonCode)
    if not reasonRow then
        local codes = {}
        for code in pairs(Sunset.Police.reasons or {}) do codes[#codes + 1] = code end
        table.sort(codes)
        return nil, ('Invalid reason. Use: %s'):format(table.concat(codes, ', '))
    end

    setWanted(targetId, reasonRow.stars, reasonRow.label, reasonCode, reasonRow.jailMinutes, charId(source))

    notify(targetId, ('Wanted level %d — %s'):format(reasonRow.stars, reasonRow.label), 'error')
    notify(source, ('Set wanted on #%d — %s (★%d)'):format(targetId, reasonRow.label, reasonRow.stars), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeClearWanted', function(source, targetId)
    if not FactionCore.hasPerm(source, 'clear_wanted') and not FactionCore.hasPerm(source, 'wanted') then
        return nil, 'You must be on-duty law enforcement'
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end

    clearWanted(targetId, charId(source))
    notify(targetId, 'Your wanted status has been cleared', 'success')
    notify(source, ('Cleared wanted for #%d'):format(targetId), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeSummon', function(source, targetId)
    if not FactionCore.isLawEnforcement(source) then return nil, 'You must be on-duty law enforcement' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end

    local range = Sunset.Police and Sunset.Police.summonRange or 125.0
    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > range then
        return nil, ('You must be within %dm of the suspect'):format(math.floor(range))
    end

    local officerName = exports.sunset_core:GetPlayerDisplayName(source)
    TriggerClientEvent('sunset:police:summonAlert', targetId, {
        officer = officerName,
        officerId = source,
        message = 'You are being summoned by law enforcement — stop and comply immediately',
    })
    notify(source, ('Summoned player #%d'):format(targetId), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeWantedList', function(source)
    if not FactionCore.hasPerm(source, 'mdc') and not FactionCore.isLawEnforcement(source) then
        return nil, 'You must be on-duty law enforcement'
    end
    return buildWantedListRows()
end)

exports.sunset_core:RegisterCallback('sunset:policeArrest', function(source, targetId)
    if not FactionCore.hasPerm(source, 'arrest') then return nil, 'You must be on-duty law enforcement' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end
    if not Detention.isCuffed(targetId) then return nil, 'Suspect must be restrained first (/cuff)' end
    if not isAtJailZone(targetId) then return nil, 'Suspect must be at the jail booking zone (MRPD or Bolingbroke)' end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    local arrestRange = Sunset.Police and Sunset.Police.arrestRange or 5.0
    if FactionCore.distBetween(officerPos, targetPos) > arrestRange then
        return nil, ('You must be within %dm of the suspect'):format(math.floor(arrestRange))
    end

    local w = WantedOnline[targetId]
    local level = w and w.level or 1
    local minutes = w and w.jailMinutes or 2
    local reason = w and w.reason or 'Arrest'
    local bounty = (Sunset.Police and Sunset.Police.bounties[level]) or 100

    clearWanted(targetId, charId(source))
    beginJail(targetId, minutes, reason, source)

    exports.sunset_core:AddMoney(source, 'bank', bounty, 'arrest_bounty')
    notify(source, ('Suspect arrested — %d min jail, $%s bounty'):format(minutes, bounty), 'success')
    notify(targetId, ('You have been arrested — %d minutes'):format(minutes), 'error', 8000)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeReasons', function(source)
    if not FactionCore.isLawEnforcement(source) then return nil end
    local list = {}
    for code, row in pairs(Sunset.Police.reasons or {}) do
        list[#list + 1] = {
            code = code,
            label = row.label,
            stars = row.stars,
            jailMinutes = row.jailMinutes,
        }
    end
    table.sort(list, function(a, b) return a.stars < b.stars end)
    return list
end)

exports.sunset_core:RegisterCallback('sunset:policeViolations', function(source)
    if not FactionCore.isLawEnforcement(source) then return nil end
    return Sunset.Police.violations or {}
end)

exports.sunset_core:RegisterCallback('sunset:policeConfiscate', function(source, targetId)
    if not FactionCore.hasPerm(source, 'confiscate') then return nil, 'Not on duty or no permission' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > 3.5 then
        return nil, 'You must be within 3m of the suspect'
    end

    local inv = exports.sunset_inventory:GetInventory(targetId) or {}
    local removed = {}
    for _, row in ipairs(inv) do
        if Sunset.IsConfiscatableItem(row.item) then
            local count = row.count or 1
            if exports.sunset_inventory:RemoveItem(targetId, row.item, count) then
                removed[#removed + 1] = { item = row.item, label = Sunset.Items[row.item] and Sunset.Items[row.item].label or row.item, count = count }
            end
        end
    end

    if #removed < 1 then return nil, 'No confiscatable items found' end

    local officerChar = charId(source)
    local targetChar = charId(targetId)
    if officerChar and targetChar then
        pcall(function()
            MySQL.insert.await(
                'INSERT INTO police_confiscations (officer_character_id, target_character_id, items) VALUES (?, ?, ?)',
                { officerChar, targetChar, json.encode(removed) }
            )
        end)
    end

    notify(targetId, 'Contraband has been confiscated by law enforcement', 'error')
    return removed
end)

exports.sunset_core:RegisterCallback('sunset:policeRadarLock', function(source, speedMph, plate)
    if not FactionCore.hasPerm(source, 'radar') then return nil, 'Not on duty or no permission' end
    speedMph = math.floor(tonumber(speedMph) or 0)
    if speedMph < 1 then return nil, 'Invalid reading' end

    local limit = Sunset.Police.radar and Sunset.Police.radar.defaultLimitMph or 55
    if speedMph <= limit then
        return { speed = speedMph, limit = limit, flagged = false }
    end

    return {
        speed = speedMph,
        limit = limit,
        flagged = true,
        plate = plate or 'UNKNOWN',
        message = ('Speed violation: %d mph in a %d mph zone'):format(speedMph, limit),
    }
end)

exports.sunset_core:RegisterCallback('sunset:policeFixedRadars', function(source)
    if not FactionCore.isLawEnforcement(source) then return nil end
    local list = {}
    for _, row in ipairs(Sunset.Police.fixedRadars or {}) do
        list[#list + 1] = {
            label = row.label,
            limitMph = row.limitMph,
            x = row.coords.x,
            y = row.coords.y,
            z = row.coords.z,
            radius = row.radius,
        }
    end
    return list
end)

exports.sunset_core:RegisterCallback('sunset:policeBackup', function(source)
    if not FactionCore.hasPerm(source, 'backup') then return nil, 'No permission' end
    if GetResourceState('sunset_dispatch') ~= 'started' then return nil, 'Dispatch unavailable' end

    local char = FactionCore.getChar(source)
    local factionId = char and FactionCore.getFactionOf(char)
    local pos = FactionCore.playerCoords(source)
    local name = exports.sunset_core:GetPlayerDisplayName(source)

    local call, err = exports.sunset_dispatch:CreateServiceCall(
        source,
        'police_backup',
        pos,
        { officerSource = source, officerName = name, factionId = factionId },
        ('BACKUP requested by %s (#%d)'):format(name, source)
    )
    if not call then return nil, err end
    return call.id
end)

exports.sunset_core:RegisterCallback('sunset:policeCancelBackup', function(source)
    if not FactionCore.hasPerm(source, 'backup') then return nil, 'No permission' end
    if GetResourceState('sunset_dispatch') ~= 'started' then return nil, 'Dispatch unavailable' end

    local call = exports.sunset_dispatch:GetPlayerActiveCall(source, 'police_backup')
    if not call then return nil, 'No active backup request' end

    local ok, err = exports.sunset_dispatch:CancelCall(source, 'police_backup', call.id, 'Backup cancelled by officer')
    if not ok then return nil, err end
    return true
end)

RegisterNetEvent('sunset:server:jailComplete', function()
    local src = source
    local jail = JailedOnline[src]
    if not jail then return end
    if not jail.releaseAt or os.time() < jail.releaseAt then
        notify(src, 'Your sentence is not complete yet', 'error')
        syncJailBag(src, { releaseAt = jail.releaseAt, minutes = math.max(1, math.ceil((jail.releaseAt - os.time()) / 60)) })
        return
    end
    endJail(src)
    notify(src, 'Your sentence is complete — you are free', 'success', 6000)
end)

AddEventHandler('sunset:server:characterSelected', function(source, characterId)
    if not characterId then
        local char = FactionCore.getChar(source)
        characterId = char and char.id
    end
    if characterId then
        Police.hydratePlayer(source, characterId)
    end
end)

AddEventHandler('sunset:death:playerDowned', function(victimSource)
    if GetResourceState('sunset_dispatch') ~= 'started' then return end
    pcall(function()
        local call = exports.sunset_dispatch:GetPlayerActiveCall(victimSource, 'police_backup')
        if call then
            exports.sunset_dispatch:CancelCall(victimSource, 'police_backup', call.id, 'Officer down — backup cancelled')
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    WantedOnline[src] = nil
    JailedOnline[src] = nil
end)

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for src, w in pairs(WantedOnline) do
            if not GetPlayerName(src) then
                WantedOnline[src] = nil
            elseif w.decayAt and now >= w.decayAt then
                local newLevel = w.level - 1
                local cid = charId(src)
                if newLevel <= 0 then
                    clearWanted(src, nil)
                    notify(src, 'Your wanted level has expired', 'success')
                else
                    local decayMin = (Sunset.Police and Sunset.Police.decayMinutes[newLevel]) or 15
                    w.level = newLevel
                    w.decayAt = now + decayMin * 60
                    if cid then Police.saveWantedToDb(cid, w, nil) end
                    applyWanted(src, w)
                    notify(src, ('Wanted level reduced to %d'):format(newLevel), 'info')
                end
            end
        end

        for src, jail in pairs(JailedOnline) do
            if jail.releaseAt and now >= jail.releaseAt then
                endJail(src)
            end
        end
    end
end)

exports('IsJailed', function(source) return Police.isJailed(source) end)

exports.sunset_core:RegisterCallback('sunset:policeMdcLookup', function(source, targetId)
    if not FactionCore.hasPerm(source, 'mdc') and not FactionCore.isLawEnforcement(source) then
        return { error = 'You must be on-duty law enforcement' }
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return { error = 'Player not online — search by server ID' }
    end

    local char = FactionCore.getChar(targetId)
    if not char then return { error = 'No character loaded' } end

    local wanted = WantedOnline[targetId]
    local jailed = JailedOnline[targetId]
    local unpaid = MySQL.scalar.await(
        'SELECT COALESCE(SUM(amount), 0) FROM tickets WHERE target_character_id = ? AND paid = 0',
        { char.id }
    ) or 0

    local charges = MySQL.query.await([[
        SELECT reason, amount, created_at FROM tickets
        WHERE target_character_id = ?
        ORDER BY created_at DESC LIMIT 8
    ]], { char.id }) or {}

    local chargeRows = {}
    for _, row in ipairs(charges) do
        chargeRows[#chargeRows + 1] = {
            reason = row.reason,
            amount = row.amount,
            date = row.created_at and tostring(row.created_at):sub(1, 10) or '',
        }
    end

    return {
        id = targetId,
        name = exports.sunset_core:GetPlayerDisplayName(targetId),
        wanted = wanted ~= nil,
        wantedLevel = wanted and wanted.level or 0,
        wantedReason = wanted and wanted.reason or '',
        jailed = jailed ~= nil,
        jailMinutes = jailed and math.max(1, math.ceil((jailed.releaseAt - os.time()) / 60)) or 0,
        finesOwed = unpaid,
        charges = chargeRows,
    }
end)

exports.sunset_core:RegisterCallback('sunset:policeIssueTicket', function(source, targetId, amount, reason, reasonCode)
    if not FactionCore.hasPerm(source, 'ticket') and not FactionCore.hasPerm(source, 'fine') then
        return nil, 'Not on duty or no permission'
    end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end

    reasonCode = reasonCode and string.lower(reasonCode) or nil
    if reasonCode then
        local violation = Sunset.GetPoliceViolation(reasonCode)
        if not violation then return nil, 'Invalid violation code' end
        amount = violation.amount
        reason = violation.label
    else
        return nil, 'Select a violation from the citation list'
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > 50000 then return nil, 'Invalid citation amount' end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > 8.0 then
        return nil, 'You must be near the target'
    end

    local officer = FactionCore.getChar(source)
    local target = FactionCore.getChar(targetId)
    if not officer or not target then return nil, 'Character error' end

    local ticketId = MySQL.insert.await([[
        INSERT INTO tickets (officer_character_id, target_character_id, amount, reason, reason_code, paid)
        VALUES (?, ?, ?, ?, ?, 0)
    ]], { officer.id, target.id, amount, reason or '', reasonCode or '' })

    TriggerClientEvent('sunset:ui:ticketReceive', targetId, {
        ticketId = ticketId,
        id = ticketId,
        amount = amount,
        reason = reason or 'Traffic violation',
        officer = exports.sunset_core:GetPlayerDisplayName(source),
        officerId = source,
    })
    notify(source, ('Citation #%d issued to #%d'):format(ticketId, targetId), 'success')
    return ticketId
end)

exports.sunset_core:RegisterCallback('sunset:policePayTicket', function(source, ticketId)
    ticketId = tonumber(ticketId)
    if not ticketId then return nil, 'Invalid ticket' end

    local char = FactionCore.getChar(source)
    if not char then return nil, 'No character' end

    local row = MySQL.single.await(
        'SELECT id, target_character_id, amount, reason, paid FROM tickets WHERE id = ?',
        { ticketId }
    )
    if not row or row.target_character_id ~= char.id then return nil, 'Ticket not found' end
    if row.paid == 1 then return nil, 'Already paid' end

    if not exports.sunset_core:RemoveMoney(source, 'bank', row.amount, 'ticket')
        and not exports.sunset_core:RemoveMoney(source, 'cash', row.amount, 'ticket') then
        return nil, 'Insufficient funds'
    end

    MySQL.update.await('UPDATE tickets SET paid = 1, paid_at = NOW() WHERE id = ?', { ticketId })
    notify(source, ('Paid citation $%s — %s'):format(row.amount, row.reason or ''), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeRefuseTicket', function(source, ticketId)
    ticketId = tonumber(ticketId)
    if not ticketId then return nil, 'Invalid ticket' end

    local char = FactionCore.getChar(source)
    if not char then return nil, 'No character' end

    local row = MySQL.single.await(
        'SELECT id, target_character_id, amount, reason, paid FROM tickets WHERE id = ?',
        { ticketId }
    )
    if not row or row.target_character_id ~= char.id then return nil, 'Ticket not found' end
    if row.paid == 1 then return nil, 'Already paid' end

    setWanted(source, 1, 'Refused citation: ' .. (row.reason or ''), 'evading', 4, nil)
    notify(source, 'You refused the citation — wanted level set', 'error')
    return true
end)
