Police = Police or {}

local WantedOnline = {}
local JailedOnline = {}
local RadarSessions = {}
local DeathCapturePending = {}

local function wantedStarSeconds()
    return math.max(60, math.floor(tonumber(Sunset.Police and Sunset.Police.wantedStarSeconds) or 900))
end

local function jailSecondsFor(level, surrenderable, deathCapture)
    level = math.max(1, math.min(5, math.floor(tonumber(level) or 1)))
    local tableName = (deathCapture or surrenderable == false) and 'noSurrenderJailSeconds' or 'arrestJailSeconds'
    local durations = Sunset.Police and Sunset.Police[tableName] or {}
    return math.max(60, math.floor(tonumber(durations[level]) or level * 4 * 60))
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    local remaining = seconds % 60
    return remaining > 0 and ('%dm %02ds'):format(minutes, remaining) or ('%d min'):format(minutes)
end

local function notify(source, msg, typ, duration)
    FactionCore.notify(source, msg, typ or 'info', duration)
end

local function policeChat(target, tag, message, messageType)
    TriggerClientEvent('sunset:police:chatAlert', target, {
        tag = tag,
        message = message,
        type = messageType or 'hq',
    })
end

local function findVehicleDriverSource(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0
                and GetVehiclePedIsIn(ped, false) == vehicle
                and GetPedInVehicleSeat(vehicle, -1) == ped then
                return src
            end
        end
    end
    return nil
end

local function officerRadarIdentity(source)
    local char = FactionCore.getChar(source)
    local factionId = char and select(1, FactionCore.getFactionOf(char))
    local faction = factionId and Sunset.Factions[factionId]
    local _, grade = FactionCore.getFactionOf(char)
    local gradeInfo = factionId and Sunset.GetFactionGrade and Sunset.GetFactionGrade(factionId, grade)
    return {
        id = source,
        name = exports.sunset_core:GetPlayerDisplayName(source),
        factionId = factionId,
        factionLabel = faction and faction.label or 'LSPD',
        rank = (gradeInfo and gradeInfo.label) or 'Officer',
    }
end

local function notifyRadarCaught(driverSource, officer, speed, limit, over)
    local officerName = exports.sunset_core:GetPlayerDisplayName(officer.id)
    local header = ('%s %s %s'):format(officer.factionLabel, officer.rank, officerName)
    local detail = ('caught you at %d km/h in a %d km/h zone (+%d).'):format(speed, limit, over)

    TriggerClientEvent('sunset:chat:message', driverSource, {
        id = officer.id,
        name = officerName,
        message = detail,
        time = os.date('%H:%M:%S'),
        type = 'radar_alert',
        factionId = officer.factionId,
        factionLabel = officer.factionLabel,
        rank = officer.rank,
        speed = speed,
        limit = limit,
        over = over,
    })
    TriggerClientEvent('sunset:client:notify', driverSource, ('%s %s'):format(header, detail), 'error', 10000)
end

local function broadcastToPolice(tag, message)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and FactionCore.isLawEnforcementMember(src) then
            policeChat(src, 'HQ', message, 'hq')
        end
    end
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
               surrenderable, decay_remaining_seconds
        FROM wanted_records
        WHERE character_id = ? AND active = 1
        ORDER BY id DESC LIMIT 1
    ]], { characterId })
    if not row then return nil end
    return {
        level = row.level,
        reason = row.reason_label,
        reasonCode = row.reason_code,
        jailMinutes = row.jail_minutes,
        surrenderable = tonumber(row.surrenderable) ~= 0,
        decayRemaining = math.max(1, tonumber(row.decay_remaining_seconds) or wantedStarSeconds()),
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
            (character_id, level, reason_code, reason_label, issued_by_character_id, jail_minutes,
             surrenderable, decay_remaining_seconds, active, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, FROM_UNIXTIME(?))
    ]], {
        characterId,
        data.level,
        data.reasonCode,
        data.reason,
        issuedBy,
        data.jailMinutes,
        data.surrenderable == false and 0 or 1,
        math.max(1, math.floor(tonumber(data.decayRemaining) or wantedStarSeconds())),
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

function Police.saveJailToDb(characterId, releaseAt, seconds, reason, officerCharId)
    MySQL.update.await(
        "UPDATE jail_sentences SET status = 'served', released_at = NOW() WHERE character_id = ? AND status = 'active'",
        { characterId }
    )
    MySQL.insert.await([[
        INSERT INTO jail_sentences
            (character_id, officer_character_id, reason, duration_minutes, duration_seconds, started_at, ends_at, status)
        VALUES (?, ?, ?, ?, ?, NOW(), FROM_UNIXTIME(?), 'active')
    ]], { characterId, officerCharId, reason or '', math.ceil(seconds / 60), seconds, releaseAt })
end

function Police.clearJailFromDb(characterId)
    MySQL.update.await(
        "UPDATE jail_sentences SET status = 'served', released_at = NOW() WHERE character_id = ? AND status = 'active'",
        { characterId }
    )
end

local LIMITED_WANTED_MAX = 2

local function hasFullWantedPerm(source)
    return FactionCore.hasPerm(source, 'wanted')
end

local function hasLimitedWantedPerm(source)
    return FactionCore.hasPerm(source, 'wanted_limited')
end

local function canIssueWanted(source)
    return hasFullWantedPerm(source) or hasLimitedWantedPerm(source)
end

local function wantedCapFor(source)
    if hasFullWantedPerm(source) then return 5 end
    return LIMITED_WANTED_MAX
end

local function applyWanted(source, data)
        data.decayRemaining = math.max(1, data.decayAt - os.time())
    end
    data.characterId = data.characterId or charId(source)
    WantedOnline[source] = data
    syncWantedBag(source, {
        level = data.level,
        reason = data.reason,
        reasonCode = data.reasonCode,
        decayAt = data.decayAt,
        surrenderable = data.surrenderable ~= false,
    })
    syncWantedClient(source, data.level, data.reason)
end

local function setWanted(targetId, level, reason, reasonCode, jailMinutes, issuedBy, silent, surrenderable, maxLevel)
    local previous = WantedOnline[targetId]
    local addedLevel = math.max(1, tonumber(level) or 1)
    level = math.max(1, math.min(maxLevel or 5, (previous and previous.level or 0) + addedLevel))
    local combinedReason = reason or 'Unknown'
    if previous and previous.reason and previous.reason ~= '' then
        combinedReason = previous.reason .. '; ' .. combinedReason
        if #combinedReason > 128 then combinedReason = combinedReason:sub(-128) end
    end
    local canSurrender = surrenderable ~= false
    if previous and previous.surrenderable == false then canSurrender = false end
    local decaySeconds = wantedStarSeconds()
    local data = {
        level = level,
        reason = combinedReason,
        reasonCode = reasonCode or '',
        jailMinutes = math.ceil(jailSecondsFor(level, canSurrender, false) / 60),
        surrenderable = canSurrender,
        decayRemaining = decaySeconds,
        decayAt = os.time() + decaySeconds,
    }

    local cid = charId(targetId)
    if cid then
        Police.saveWantedToDb(cid, data, issuedBy)
    end
    applyWanted(targetId, data)
    local name = 'Unknown'
    pcall(function()
        name = exports.sunset_core:GetPlayerDisplayName(targetId) or name
    end)
    if not silent then
        broadcastToPolice('WANTED', ('%s (#%d) is now wanted ★%d — %s — %s'):format(
            name, targetId, data.level, data.reason, data.surrenderable and 'RIGHT TO SURRENDER' or 'NO RIGHT TO SURRENDER'))
    end
    return data
end

function AddWantedCharge(targetId, reasonCode, issuedBy, options)
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player is not online' end
    reasonCode = string.lower(tostring(reasonCode or 'robbery'))
    local reasonRow = Sunset.GetPoliceReason(reasonCode)
    if not reasonRow then return nil, 'Unknown wanted reason' end
    local silent = type(options) == 'table' and options.silent == true
    local surrenderable = reasonRow.surrenderable ~= false
    if type(options) == 'table' and options.surrenderable ~= nil then
        surrenderable = options.surrenderable == true
    end
    return setWanted(targetId, reasonRow.stars, reasonRow.label, reasonCode, reasonRow.jailMinutes, issuedBy, silent, surrenderable)
end
exports('AddWantedCharge', AddWantedCharge)

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

local function beginJail(targetId, seconds, reason, officerSource)
    seconds = math.max(60, math.floor(tonumber(seconds) or 120))
    local minutes = math.ceil(seconds / 60)
    local releaseAt = os.time() + seconds
    local targetCharId = charId(targetId)
    local officerCharId = officerSource and charId(officerSource)

    if targetCharId then
        Police.saveJailToDb(targetCharId, releaseAt, seconds, reason, officerCharId)
    end

    JailedOnline[targetId] = { releaseAt = releaseAt, minutes = minutes, seconds = seconds, reason = reason }
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

local function nearestOnDutyOfficer(targetId, range)
    local targetPos = FactionCore.playerCoords(targetId)
    if not targetPos then return nil end

    local nearest, nearestDistance
    for _, id in ipairs(GetPlayers()) do
        local officer = tonumber(id)
        if officer and officer ~= targetId and FactionCore.isLawEnforcement(officer) then
            local distance = FactionCore.distBetween(targetPos, FactionCore.playerCoords(officer))
            if distance <= range and (not nearestDistance or distance < nearestDistance) then
                nearest, nearestDistance = officer, distance
            end
        end
    end
    return nearest, nearestDistance
end

local function captureWantedAfterDeath(targetId)
    targetId = tonumber(targetId)
    if not targetId or DeathCapturePending[targetId] or Police.isJailed(targetId) then return false end

    local wanted = WantedOnline[targetId]
    if not wanted then return false end

    local isDowned = false
    pcall(function()
        isDowned = exports.sunset_death:IsPlayerDowned(targetId) == true
    end)
    if not isDowned then return false end

    local range = math.max(5.0, tonumber(Sunset.Police and Sunset.Police.wantedDeathCaptureRange) or 125.0)
    local officer, distance = nearestOnDutyOfficer(targetId, range)
    if not officer then return false end

    DeathCapturePending[targetId] = true
    local sentenceSeconds = jailSecondsFor(wanted.level, wanted.surrenderable, true)
    local reason = wanted.reason or 'Active wanted status'
    local level = math.max(1, tonumber(wanted.level) or 1)

    local custodyCleared = false
    pcall(function()
        custodyCleared = exports.sunset_death:ClearDownedForCustody(targetId) == true
    end)
    if not custodyCleared then
        DeathCapturePending[targetId] = nil
        return false
    end

    clearWanted(targetId, charId(officer))
    beginJail(targetId, sentenceSeconds, reason, officer)
    DeathCapturePending[targetId] = nil

    local suspectName = exports.sunset_core:GetPlayerDisplayName(targetId)
    local officerName = exports.sunset_core:GetPlayerDisplayName(officer)
    notify(targetId, ('You died while wanted near law enforcement — jailed for %s (former wanted ★%d, no-surrender sentence).'):format(
        formatDuration(sentenceSeconds), level), 'error', 10000)
    notify(officer, ('Wanted suspect %s (#%d) was taken into custody after being downed nearby.'):format(
        suspectName, targetId), 'success', 8000)
    broadcastToPolice('SUSPECT IN CUSTODY', ('%s (#%d) was downed near %s (#%d) and jailed for %s: %s.'):format(
        suspectName, targetId, officerName, officer, formatDuration(sentenceSeconds), reason))
    FactionCore.auditLog('police', charId(officer), 'wanted_death_capture', charId(targetId), {
        wantedLevel = level,
        jailSeconds = sentenceSeconds,
        distance = math.floor((distance or 0.0) * 10 + 0.5) / 10,
        reason = reason,
    })
    return true
end

function Police.isDeathCapturePending(source)
    return DeathCapturePending[source] == true
end

local function endJail(source)
    local cid = charId(source)
    if cid then Police.clearJailFromDb(cid) end
    JailedOnline[source] = nil
    syncJailBag(source, nil)
    if Detention then Detention.releaseJail(source) end
    TriggerClientEvent('sunset:police:release', source)
end

local function bookingStatus(targetId)
    local targetPos = FactionCore.playerCoords(targetId)
    if not targetPos then return false, nil, 9999.0 end

    local radius = Sunset.Police and Sunset.Police.jailRadius or 12.0
    local nearest, nearestDistance
    for _, point in ipairs((Sunset.Police and Sunset.Police.bookingPoints) or {}) do
        local distance = FactionCore.distBetween(targetPos, point.coords)
        if not nearestDistance or distance < nearestDistance then
            nearest, nearestDistance = point, distance
        end
        if distance <= radius then return true, point, distance end
    end
    if not nearest and Sunset.Police and Sunset.Police.pdJailPoint then
        local point = { label = 'MRPD Booking — basement', coords = Sunset.Police.pdJailPoint }
        return FactionCore.distBetween(targetPos, point.coords) <= radius, point,
            FactionCore.distBetween(targetPos, point.coords)
    end
    return false, nearest, nearestDistance or 9999.0
end

local function buildWantedListRows()
    local now = os.time()
    local rows = MySQL.query.await([[
        SELECT wr.character_id, wr.level, wr.reason_label AS reason, wr.reason_code, wr.jail_minutes,
               wr.surrenderable, wr.decay_remaining_seconds,
               c.firstname, c.lastname
        FROM wanted_records wr
        INNER JOIN characters c ON c.id = wr.character_id
        WHERE wr.active = 1
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
        local onlineState = src and WantedOnline[src]
        local remaining = onlineState and math.max(0, (onlineState.decayAt or now) - now)
            or math.max(0, tonumber(row.decay_remaining_seconds) or wantedStarSeconds())
        local surrenderable = tonumber(row.surrenderable) ~= 0
        if onlineState then surrenderable = onlineState.surrenderable ~= false end
        list[#list + 1] = {
            id = src,
            characterId = row.character_id,
            name = ('%s %s'):format(row.firstname or '', row.lastname or ''):gsub('^%s+', ''):gsub('%s+$', ''),
            level = row.level,
            reason = row.reason,
            reasonCode = row.reason_code,
            remainingSec = remaining,
            surrenderable = surrenderable,
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
        wanted.decayAt = os.time() + math.max(1, wanted.decayRemaining or wantedStarSeconds())
        applyWanted(source, wanted)
    else
        syncWantedBag(source, nil)
        syncWantedClient(source, 0, '')
    end
    syncJailBag(source, nil)
end

exports.sunset_core:RegisterCallback('sunset:policeSetWanted', function(source, targetId, reasonCode)
    if not canIssueWanted(source) then
        return nil, FactionCore.accessError(source, 'wanted', 'add a wanted charge', 'law_enforcement')
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    if targetId == source then return nil, 'You cannot add a wanted charge to yourself.' end
    if Police.isJailed(targetId) then return nil, 'Suspect is already in custody' end

    reasonCode = string.lower(reasonCode or '')
    local reasonRow = Sunset.GetPoliceReason(reasonCode)
    if not reasonRow then
        local codes = {}
        for code in pairs(Sunset.Police.reasons or {}) do codes[#codes + 1] = code end
        table.sort(codes)
        return nil, ('Invalid reason. Use: %s'):format(table.concat(codes, ', '))
    end

    local maxLevel = wantedCapFor(source)
    local previous = WantedOnline[targetId]
    local currentLevel = previous and previous.level or 0
    local projected = math.min(maxLevel, currentLevel + reasonRow.stars)
    if projected <= currentLevel and not hasFullWantedPerm(source) then
        return nil, ('Your rank can only raise suspects up to ★%d wanted. Request supervisory backup for higher charges.'):format(LIMITED_WANTED_MAX)
    end

    local wanted = setWanted(targetId, reasonRow.stars, reasonRow.label, reasonCode, reasonRow.jailMinutes,
        charId(source), false, reasonRow.surrenderable ~= false, maxLevel)

    notify(targetId, ('New charge: %s (+★%d). Total wanted: ★%d — %s. One star expires per 15 minutes online.'):format(
        reasonRow.label, reasonRow.stars, wanted.level,
        wanted.surrenderable and 'you may surrender' or 'no right to surrender'), 'error', 10000)
    notify(source, ('Wanted charge added to #%d — now ★%d, %s'):format(
        targetId, wanted.level, wanted.surrenderable and 'surrender allowed' or 'no surrender'), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeClearWanted', function(source, targetId)
    if not FactionCore.hasPerm(source, 'clear_wanted') and not FactionCore.hasPerm(source, 'wanted') then
        return nil, FactionCore.accessError(source, 'clear_wanted', 'clear wanted status', 'law_enforcement')
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    if not WantedOnline[targetId] then
        return nil, 'That player has no active wanted status.'
    end
    clearWanted(targetId, charId(source))
    notify(targetId, 'Your wanted status has been cleared', 'success')
    notify(source, ('Cleared wanted for #%d'):format(targetId), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeSummon', function(source, targetId)
    if not FactionCore.hasPerm(source, 'mdc') then
        return nil, FactionCore.accessError(source, 'mdc', 'issue a police stop order', 'law_enforcement')
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    if targetId == source then return nil, 'You cannot issue a police stop order to yourself.' end

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
    local targetName = exports.sunset_core:GetPlayerDisplayName(targetId)
    local chatMessage = ('Officer %s (#%d) ordered %s (#%d) to stop and comply.'):format(
        officerName, source, targetName, targetId)
    policeChat(source, 'STOP ORDER', chatMessage, 'police_alert')
    policeChat(targetId, 'POLICE ORDER', chatMessage, 'police_alert')
    for _, id in ipairs(GetPlayers()) do
        local viewer = tonumber(id)
        local viewerPos = viewer and FactionCore.playerCoords(viewer)
        if viewer ~= source and viewer ~= targetId and viewerPos
            and (FactionCore.distBetween(viewerPos, officerPos) <= 80.0
            or FactionCore.distBetween(viewerPos, targetPos) <= 80.0) then
            policeChat(viewer, 'POLICE ALERT', chatMessage, 'police_alert')
        end
    end
    notify(source, ('Stop order sent to %s (#%d); nearby players saw the chat alert.'):format(
        targetName, targetId), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeWantedList', function(source)
    if not FactionCore.hasPerm(source, 'mdc') then
        return nil, FactionCore.accessError(source, 'mdc', 'view the wanted list', 'law_enforcement')
    end
    return buildWantedListRows()
end)

exports.sunset_core:RegisterCallback('sunset:policeFindWanted', function(source, targetId)
    if not FactionCore.hasPerm(source, 'mdc')
        and not FactionCore.hasPerm(source, 'wanted')
        and not FactionCore.hasPerm(source, 'wanted_limited') then
        return nil, FactionCore.accessError(source, 'mdc', 'track wanted suspects', 'law_enforcement')
    end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    local wanted = WantedOnline[targetId]
    if not wanted then
        return nil, ('Player (%d) has no active wanted status.'):format(targetId)
    end
    local coords = FactionCore.playerCoords(targetId)
    if not coords then
        return nil, 'Could not locate that player.'
    end
    return {
        id = targetId,
        name = exports.sunset_core:GetPlayerDisplayName(targetId),
        level = wanted.level or 1,
        reason = wanted.reason or 'Active wanted',
        x = coords.x,
        y = coords.y,
        z = coords.z,
    }
end)

exports.sunset_core:RegisterCallback('sunset:policeArrest', function(source, targetId)
    if not FactionCore.hasPerm(source, 'arrest') then
        return nil, FactionCore.accessError(source, 'arrest', 'arrest a suspect', 'law_enforcement')
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    if targetId == source then return nil, 'You cannot arrest yourself.' end
    if not Detention.isCuffed(targetId) then
        return nil, ('Player #%d is not cuffed. Stand within 3m and use /cuff %d first.'):format(targetId, targetId)
    end
    if not WantedOnline[targetId] then
        return nil, ('Player #%d has no active wanted charges. Add a valid charge with /su %d [reason].'):format(
            targetId, targetId)
    end
    local atBooking, nearest, bookingDistance = bookingStatus(targetId)
    if not atBooking then
        return nil, ('Take player #%d to %s (%.0fm away). Use /booking for GPS, escort them into the marker, then /arrest %d.'):format(
            targetId, nearest and nearest.label or 'MRPD Booking', bookingDistance, targetId)
    end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    local arrestRange = Sunset.Police and Sunset.Police.arrestRange or 5.0
    if FactionCore.distBetween(officerPos, targetPos) > arrestRange then
        return nil, ('You must be within %dm of the suspect'):format(math.floor(arrestRange))
    end

    local w = WantedOnline[targetId]
    local level = w and w.level or 1
    local surrenderable = not w or w.surrenderable ~= false
    local sentenceSeconds = jailSecondsFor(level, surrenderable, false)
    local reason = w and w.reason or 'Arrest'
    local bounty = (Sunset.Police and Sunset.Police.bounties[level]) or 100

    clearWanted(targetId, charId(source))
    beginJail(targetId, sentenceSeconds, reason, source)

    exports.sunset_core:AddMoney(source, 'bank', bounty, 'arrest_bounty')
    notify(source, ('Suspect arrested — %s jail (%s), $%s bounty'):format(
        formatDuration(sentenceSeconds), surrenderable and 'surrender sentence' or 'no-surrender sentence', bounty), 'success')
    notify(targetId, ('You have been arrested — %s (%s).'):format(
        formatDuration(sentenceSeconds), surrenderable and 'right-to-surrender sentence' or 'no-surrender sentence'), 'error', 10000)
    broadcastToPolice('ARREST', ('%s (#%d) arrested %s (#%d): %s, %s, %s.'):format(
        exports.sunset_core:GetPlayerDisplayName(source), source,
        exports.sunset_core:GetPlayerDisplayName(targetId), targetId, reason,
        formatDuration(sentenceSeconds), surrenderable and 'surrenderable' or 'no surrender'))
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeReasons', function(source)
    if not FactionCore.hasPerm(source, 'mdc')
        and not FactionCore.hasPerm(source, 'wanted')
        and not FactionCore.hasPerm(source, 'wanted_limited') then
        return nil, FactionCore.accessError(source, 'wanted', 'view wanted reason codes', 'law_enforcement')
    end
    local list = {}
    for code, row in pairs(Sunset.Police.reasons or {}) do
        list[#list + 1] = {
            code = code,
            label = row.label,
            stars = row.stars,
            jailMinutes = math.ceil(jailSecondsFor(row.stars, row.surrenderable ~= false, false) / 60),
            surrenderable = row.surrenderable ~= false,
        }
    end
    table.sort(list, function(a, b) return a.stars < b.stars end)
    return list
end)

exports.sunset_core:RegisterCallback('sunset:policeViolations', function(source)
    if not FactionCore.hasPerm(source, 'ticket') and not FactionCore.hasPerm(source, 'fine') then
        return nil, FactionCore.accessError(source, 'ticket', 'view the citation list', 'law_enforcement')
    end
    return Sunset.Police.violations or {}
end)

exports.sunset_core:RegisterCallback('sunset:policeConfiscate', function(source, targetId)
    if not FactionCore.hasPerm(source, 'confiscate') then
        return nil, FactionCore.accessError(source, 'confiscate', 'confiscate contraband', 'law_enforcement')
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end

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

local function broadcastFactionAction(source, message, factionId)
    local char = FactionCore.getChar(source)
    if not char then return end
    factionId = factionId or select(1, FactionCore.getFactionOf(char))
    if not factionId then return end

    local name = exports.sunset_core:GetPlayerDisplayName(source)
    local faction = Sunset.Factions[factionId]
    local label = faction and faction.label or factionId
    local _, grade = FactionCore.getFactionOf(char)
    local gradeInfo = Sunset.GetFactionGrade and Sunset.GetFactionGrade(factionId, grade)
    local rank = (gradeInfo and gradeInfo.label) or 'Member'
    local payload = {
        id = source,
        name = name,
        message = message,
        time = os.date('%H:%M:%S'),
        type = 'faction_action',
        factionId = factionId,
        factionLabel = label,
        rank = rank,
    }

    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('sunset:chat:message', tonumber(id), payload)
    end
end

local function validateRadarVehicle(source, networkId)
    if not FactionCore.hasPerm(source, 'radar') then
        return nil, FactionCore.accessError(source, 'radar', 'use the speed radar', 'law_enforcement')
    end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(networkId) or 0)
    local ped = GetPlayerPed(source)
    if vehicle == 0 or not DoesEntityExist(vehicle) or ped == 0 then
        return nil, 'You must be driving a valid LSPD patrol vehicle.'
    end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil, 'You must be in the driver seat of the LSPD patrol vehicle.'
    end
    local isFleet = Entity(vehicle).state.sunsetFactionVehicle == 'police'
    local model = GetEntityModel(vehicle)
    local depot = Sunset.Factions.police and Sunset.Factions.police.depot
    local isDepotModel = depot and depot.vehicle and model == joaat(depot.vehicle)
    local allowed = false
    for _, name in ipairs((Sunset.Police.radar and Sunset.Police.radar.allowedModels) or {}) do
        if model == joaat(name) then
            allowed = true
            break
        end
    end
    if not isFleet and not isDepotModel and not allowed then
        return nil, 'Get in an LSPD patrol car (MRPD garage or a marked cruiser) and try again.'
    end
    return vehicle
end

exports.sunset_core:RegisterCallback('sunset:policeRadarStart', function(source, networkId, requestedLimit)
    local vehicle, err = validateRadarVehicle(source, networkId)
    if not vehicle then return nil, err end
    local cfg = Sunset.Police.radar or {}
    local limit = math.floor(tonumber(requestedLimit) or 0)
    if limit < (cfg.minLimitKmh or 20) or limit > (cfg.maxLimitKmh or 250) then
        return nil, ('Choose a speed limit between %d and %d km/h. Example: /startradar 90'):format(
            cfg.minLimitKmh or 20, cfg.maxLimitKmh or 250)
    end
    RadarSessions[source] = { networkId = NetworkGetNetworkIdFromEntity(vehicle), limitKmh = limit, lastPlate = '', lastAt = 0 }
    broadcastFactionAction(source, ('placed a speed radar with a %d km/h limit.'):format(limit), 'police')
    return { limitKmh = limit }
end)

exports.sunset_core:RegisterCallback('sunset:policeRadarStop', function(source)
    RadarSessions[source] = nil
    return true
end)

local function radarCommand(source, args)
    if source == 0 then return end
    TriggerClientEvent('sunset:police:tryStartRadar', source, args[1])
end
RegisterCommand('startradar', radarCommand, false)
RegisterCommand('setradar', radarCommand, false)
RegisterCommand('radar', radarCommand, false)
RegisterCommand('stopradar', function(source)
    if source == 0 then return end
    TriggerClientEvent('sunset:police:tryStopRadar', source)
end, false)

exports.sunset_core:RegisterCallback('sunset:policeRadarLock', function(source, targetNetworkId)
    local session = RadarSessions[source]
    if not session then return nil, 'Radar is not active. Use /startradar [limit_kmh] first.' end
    local radarVehicle, err = validateRadarVehicle(source, session.networkId)
    if not radarVehicle then
        RadarSessions[source] = nil
        return nil, err
    end

    local targetVehicle = NetworkGetEntityFromNetworkId(tonumber(targetNetworkId) or 0)
    if targetVehicle == 0 or targetVehicle == radarVehicle or not DoesEntityExist(targetVehicle) then
        return nil, 'Radar target is no longer available.'
    end
    local cfg = Sunset.Police.radar or {}
    if #(GetEntityCoords(targetVehicle) - GetEntityCoords(radarVehicle)) > (cfg.mobileRange or 45.0) + 10.0 then
        return nil, 'Radar target is out of range.'
    end

    local speed = math.floor(GetEntitySpeed(targetVehicle) * 3.6 + 0.5)
    local limit = session.limitKmh
    if speed <= limit then return { speed = speed, limit = limit, flagged = false } end
    local plate = GetVehicleNumberPlateText(targetVehicle) or 'UNKNOWN'
    local now = os.time()
    if session.lastPlate == plate and now - session.lastAt < 4 then
        return { speed = speed, limit = limit, flagged = false }
    end
    session.lastPlate, session.lastAt = plate, now

    local over = speed - limit
    local officer = officerRadarIdentity(source)
    local message = ('%s (%d) recorded %s at %d km/h (limit %d, +%d).'):format(
        officer.name, officer.id, plate, speed, limit, over)
    policeChat(source, 'HQ', message, 'hq')

    local driverSource = findVehicleDriverSource(targetVehicle)
    if driverSource and driverSource ~= source then
        notifyRadarCaught(driverSource, officer, speed, limit, over)
    end

    return { speed = speed, limit = limit, flagged = true, plate = plate, message = message }
end)

exports.sunset_core:RegisterCallback('sunset:policeFixedRadars', function(source)
    if not FactionCore.hasPerm(source, 'radar') then
        return nil, FactionCore.accessError(source, 'radar', 'view fixed radars', 'law_enforcement')
    end
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
    if not FactionCore.hasPerm(source, 'backup') then
        return nil, FactionCore.accessError(source, 'backup', 'request police backup', 'law_enforcement')
    end
    if GetResourceState('sunset_dispatch') ~= 'started' then
        return nil, 'Cannot request backup: Dispatch is offline. Contact staff; no alert was created.'
    end

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
    if not FactionCore.hasPerm(source, 'backup') then
        return nil, FactionCore.accessError(source, 'backup', 'cancel police backup', 'law_enforcement')
    end
    if GetResourceState('sunset_dispatch') ~= 'started' then
        return nil, 'Cannot cancel backup: Dispatch is offline. Contact staff.'
    end

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
    captureWantedAfterDeath(victimSource)

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
    local wanted = WantedOnline[src]
    if wanted then
        wanted.decayRemaining = math.max(1, (tonumber(wanted.decayAt) or os.time()) - os.time())
        local cid = wanted.characterId or charId(src)
        if cid then Police.saveWantedToDb(cid, wanted, nil) end
    end
    WantedOnline[src] = nil
    JailedOnline[src] = nil
    RadarSessions[src] = nil
    DeathCapturePending[src] = nil
end)

CreateThread(function()
    while true do
        Wait(10000)
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
                    w.level = newLevel
                    w.decayRemaining = wantedStarSeconds()
                    w.decayAt = now + w.decayRemaining
                    w.jailMinutes = math.ceil(jailSecondsFor(newLevel, w.surrenderable, false) / 60)
                    if cid then Police.saveWantedToDb(cid, w, nil) end
                    applyWanted(src, w)
                    notify(src, ('Wanted reduced to ★%d. Next star expires after 15 more minutes online.'):format(newLevel), 'info')
                end
            elseif w.decayAt then
                w.decayRemaining = math.max(1, w.decayAt - now)
                local cid = w.characterId or charId(src)
                if cid and (not w.lastPersistAt or now - w.lastPersistAt >= 60) then
                    w.lastPersistAt = now
                    MySQL.update.await(
                        'UPDATE wanted_records SET decay_remaining_seconds = ?, expires_at = FROM_UNIXTIME(?) WHERE character_id = ? AND active = 1',
                        { w.decayRemaining, w.decayAt, cid }
                    )
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

AddEventHandler('sunset:police:autoWanted', function(targetId, reasonCode, reasonLabel)
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    setWanted(targetId, 5, reasonLabel or 'Murder', reasonCode or 'murder', 50, nil, false, false)
    notify(targetId, 'WANTED ★5: first-degree murder — no right to surrender. One star expires every 15 minutes online.', 'error', 10000)
end)

exports.sunset_core:RegisterCallback('sunset:getJailSpawnLock', function(source)
    if not Police.isJailed(source) then return { locked = false } end
    local jail = Sunset.Police and Sunset.Police.jailCoords
    if not jail then return { locked = true, x = 1845.0, y = 2585.0, z = 45.7, w = 270.0 } end
    return { locked = true, x = jail.x, y = jail.y, z = jail.z, w = jail.w or 0.0 }
end)

exports.sunset_core:RegisterCallback('sunset:policeUnjail', function(source, targetId)
    local isAdmin = false
    pcall(function() isAdmin = exports.sunset_admin:IsAdmin(source, 2) == true end)
    if not isAdmin and not FactionCore.hasPerm(source, 'arrest') then
        return nil, 'You cannot release prisoners.'
    end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, 'That player is not online.'
    end
    if not JailedOnline[targetId] then
        return nil, 'That player is not in jail.'
    end
    endJail(targetId)
    notify(targetId, 'You have been released from jail', 'success')
    notify(source, ('Released #%d from jail'):format(targetId), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeMdcLookup', function(source, targetId)
    if not FactionCore.hasPerm(source, 'mdc') then
        return { error = FactionCore.accessError(source, 'mdc', 'search the MDC', 'law_enforcement') }
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
        return nil, FactionCore.accessError(source, 'ticket', 'issue a citation', 'law_enforcement')
    end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Enter the server ID shown in F10.'):format(tostring(targetId or '?'))
    end
    if targetId == source then return nil, 'You cannot issue a citation to yourself.' end

    reasonCode = reasonCode and string.lower(reasonCode) or nil
    if reasonCode then
        local violation = Sunset.GetPoliceViolation(reasonCode)
        if not violation then return nil, 'That citation violation is invalid. Close and reopen /ticket to refresh the list.' end
        amount = violation.amount
        reason = violation.label
    else
        return nil, 'Select a violation in the citation window before pressing ISSUE CITATION.'
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > 50000 then return nil, 'Invalid citation amount' end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > 8.0 then
        return nil, ('Move closer to player #%d: citations require you to be within 8m.'):format(targetId)
    end

    local officer = FactionCore.getChar(source)
    local target = FactionCore.getChar(targetId)
    if not officer then return nil, 'Your character is no longer loaded. Reconnect and select it again.' end
    if not target then return nil, ('Player #%d has not loaded a character yet; wait for them to finish login.'):format(targetId) end

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
    if not ticketId then return nil, 'This citation has no valid ID. Close the window and ask the officer to issue it again.' end

    local char = FactionCore.getChar(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and select it again.' end

    local row = MySQL.single.await(
        'SELECT id, target_character_id, amount, reason, paid FROM tickets WHERE id = ?',
        { ticketId }
    )
    if not row or row.target_character_id ~= char.id then return nil, 'This citation does not exist or does not belong to your character.' end
    if row.paid == 1 then return nil, 'This citation has already been paid; no money was taken.' end
    if row.paid ~= 0 then return nil, 'This citation was already refused or is currently being processed; no money was taken.' end

    local claimed = MySQL.update.await('UPDATE tickets SET paid = 3 WHERE id = ? AND paid = 0', { ticketId })
    if not claimed or claimed < 1 then return nil, 'This citation was already handled; no money was taken.' end

    if not exports.sunset_core:RemoveMoney(source, 'bank', row.amount, 'ticket')
        and not exports.sunset_core:RemoveMoney(source, 'cash', row.amount, 'ticket') then
        MySQL.update.await('UPDATE tickets SET paid = 0 WHERE id = ? AND paid = 3', { ticketId })
        return nil, ('You need $%s in bank or cash to pay this citation.'):format(row.amount)
    end

    MySQL.update.await('UPDATE tickets SET paid = 1, paid_at = NOW() WHERE id = ? AND paid = 3', { ticketId })
    notify(source, ('Paid citation $%s — %s'):format(row.amount, row.reason or ''), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeRefuseTicket', function(source, ticketId)
    ticketId = tonumber(ticketId)
    if not ticketId then return nil, 'This citation has no valid ID. Close the window and ask the officer to issue it again.' end

    local char = FactionCore.getChar(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and select it again.' end

    local row = MySQL.single.await(
        'SELECT id, target_character_id, amount, reason, paid FROM tickets WHERE id = ?',
        { ticketId }
    )
    if not row or row.target_character_id ~= char.id then return nil, 'This citation does not exist or does not belong to your character.' end
    if row.paid == 1 then return nil, 'This citation was already paid and cannot be refused.' end
    if row.paid ~= 0 then return nil, 'This citation was already refused or is currently being processed.' end

    local refused = MySQL.update.await('UPDATE tickets SET paid = 2, paid_at = NOW() WHERE id = ? AND paid = 0', { ticketId })
    if not refused or refused < 1 then return nil, 'This citation was already handled; no new wanted charge was added.' end

    local wanted = setWanted(source, 1, 'Refused citation: ' .. (row.reason or ''), 'evading', 4, nil, false, false)
    notify(source, ('You refused citation #%d — wanted increased to ★%d.'):format(ticketId, wanted.level), 'error')
    broadcastToPolice('CITATION REFUSED', ('%s (#%d) refused citation #%d (%s); wanted is now ★%d.'):format(
        exports.sunset_core:GetPlayerDisplayName(source), source, ticketId, row.reason or 'violation', wanted.level))
    return true
end)
