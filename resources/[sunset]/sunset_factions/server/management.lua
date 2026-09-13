-- ═══════════════════════════════════════════════════════════════
--  FACTION MANAGEMENT — FP (faction punish), resignations,
--  membership join tracking.  (sql/46-faction-management.sql)
--
--  Rules (owner decision):
--   * Instant self-leave (/leavefaction): +60 FP automatically.
--   * Resignation request: member submits in /faction; the leader
--     accepts CLEAN (no FP) or WITH FP (60), or declines.
--   * Leader kick "with FP": also sets 60 FP.
--   * FP decays by 1 each payday the character is online for.
--   * FP > 0 blocks joining ANY faction (invite/accept).
--   * Leaders can pardon (clear) FP of anyone, incl. ex-members.
--   * Members who joined < 14 days ago get a roster badge (leader
--     should kick them WITH FP manually if they leave early).
-- ═══════════════════════════════════════════════════════════════

local FP_SELF_LEAVE = 60
local FP_KICK = 60
local FP_JOIN_BLOCK_LABEL = 'You are faction-punished (FP)'

FactionManagement = FactionManagement or {}

-- ── FP core ────────────────────────────────────────────────────

function FactionManagement.getFP(characterId)
    characterId = tonumber(characterId)
    if not characterId then return 0 end
    local row = MySQL.single.await('SELECT fp, reason FROM faction_punish WHERE character_id = ?', { characterId })
    return row and math.max(0, tonumber(row.fp) or 0) or 0, row and row.reason or nil
end

function FactionManagement.setFP(characterId, amount, reason, byCharacterId)
    characterId = tonumber(characterId)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not characterId then return false end
    if amount == 0 then
        MySQL.update.await('DELETE FROM faction_punish WHERE character_id = ?', { characterId })
    else
        MySQL.update.await([[
            INSERT INTO faction_punish (character_id, fp, reason, set_by_character_id)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE fp = VALUES(fp), reason = VALUES(reason), set_by_character_id = VALUES(set_by_character_id)
        ]], { characterId, amount, tostring(reason or 'No reason given'):sub(1, 255), tonumber(byCharacterId) })
    end
    return true
end

-- Payday decay: -1 FP per payday processed (economy emits per player).
AddEventHandler('sunset:payday:processed', function(source)
    local char = FactionCore.getChar(source)
    if not char or not char.id then return end
    local fp = FactionManagement.getFP(char.id)
    if fp <= 0 then return end
    local newFp = fp - 1
    if newFp <= 0 then
        FactionManagement.setFP(char.id, 0)
        TriggerClientEvent('sunset:client:notify', source,
            'Your faction punish (FP) expired. You can join a faction again.', 'success', 10000)
    else
        MySQL.update.await('UPDATE faction_punish SET fp = ? WHERE character_id = ?', { newFp, char.id })
        TriggerClientEvent('sunset:client:notify', source,
            ('FP: %d remaining (decreases by 1 each payday).'):format(newFp), 'warning', 8000)
    end
end)

-- ── Membership join tracking ───────────────────────────────────

AddEventHandler('sunset:server:factionChanged', function(source, newFaction, grade, previousFaction)
    local char = FactionCore.getChar(source)
    if not char or not char.id then return end
    if newFaction and newFaction ~= previousFaction then
        -- joined a (new) faction: record join time
        MySQL.update.await([[
            INSERT INTO faction_membership (character_id, faction_id, joined_at)
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE faction_id = VALUES(faction_id), joined_at = NOW()
        ]], { char.id, tostring(newFaction) })
    elseif not newFaction or newFaction == '' then
        MySQL.update.await('DELETE FROM faction_membership WHERE character_id = ?', { char.id })
    end
end)

function FactionManagement.getJoinedAt(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end
    return MySQL.scalar.await('SELECT UNIX_TIMESTAMP(joined_at) FROM faction_membership WHERE character_id = ?', { characterId })
end

-- ── FP join gate (used by invite/accept flows) ─────────────────

function FactionManagement.assertCanJoin(characterId)
    local fp, reason = FactionManagement.getFP(characterId)
    if fp > 0 then
        return false, ('%s: %d FP remaining (%s). FP decays by 1 each payday; a leader can pardon you.'):format(
            FP_JOIN_BLOCK_LABEL, fp, reason or 'no reason')
    end
    return true
end

-- ── Resignations ───────────────────────────────────────────────

exports.sunset_core:RegisterCallback('sunset:factionResignSubmit', function(source, reason)
    local char = FactionCore.getChar(source)
    if not char then return nil, 'Your character is not loaded.' end
    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then return nil, 'You are not in a faction.' end
    if FactionCore.isFactionLeader(char.id, factionId) then
        return nil, 'Leaders cannot resign — transfer leadership or ask staff.'
    end
    reason = tostring(reason or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 255)

    local existing = MySQL.single.await(
        "SELECT id FROM faction_resignations WHERE character_id = ? AND status = 'pending' LIMIT 1", { char.id })
    if existing then return nil, 'You already have a pending resignation. Wait for the leader to handle it.' end

    MySQL.insert.await(
        'INSERT INTO faction_resignations (faction_id, character_id, reason) VALUES (?, ?, ?)',
        { factionId, char.id, reason == '' and nil or reason })
    FactionCore.auditLog(factionId, char.id, 'resign_submitted', char.id, { reason = reason })
    FactionCore.broadcastManagement(factionId, source, 'submitted a resignation request.')
    return true
end)

local function leaderOnlyForFaction(source)
    local char = FactionCore.getChar(source)
    if not char then return nil, nil, 'Your character is not loaded.' end
    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then return nil, nil, 'You are not in a faction.' end
    if not FactionCore.isFactionLeader(char.id, factionId)
        and not FactionCore.hasManagePerm(source, 'uninvite') then
        return nil, nil, 'Only the faction leader (or members with kick permission) can handle resignations.'
    end
    return char, factionId
end

exports.sunset_core:RegisterCallback('sunset:factionResignationsList', function(source)
    local char, factionId, err = leaderOnlyForFaction(source)
    if not char then return nil, err end
    local rows = MySQL.query.await([[
        SELECT fr.id, fr.character_id, fr.reason, fr.status, fr.created_at,
               c.firstname, c.lastname, fm.joined_at
        FROM faction_resignations fr
        LEFT JOIN characters c ON c.id = fr.character_id
        LEFT JOIN faction_membership fm ON fm.character_id = fr.character_id
        WHERE fr.faction_id = ? AND fr.status = 'pending'
        ORDER BY fr.created_at ASC
        LIMIT 50
    ]], { factionId }) or {}
    local out = {}
    local now = os.time()
    for _, row in ipairs(rows) do
        local joinedAt = row.joined_at and tonumber(row.joined_at) or nil
        out[#out + 1] = {
            id = tonumber(row.id),
            characterId = tonumber(row.character_id),
            name = (('%s %s'):format(row.firstname or '', row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
            reason = row.reason or '',
            createdAt = row.created_at and tostring(row.created_at) or '',
            daysInFaction = joinedAt and math.floor((now - joinedAt) / 86400) or nil,
        }
    end
    return out
end)

exports.sunset_core:RegisterCallback('sunset:factionResignHandle', function(source, resignationId, action)
    local char, factionId, err = leaderOnlyForFaction(source)
    if not char then return nil, err end
    resignationId = tonumber(resignationId)
    action = tostring(action or ''):lower()
    if not resignationId or (action ~= 'accept' and action ~= 'accept_fp' and action ~= 'decline') then
        return nil, 'Invalid resignation action.'
    end

    local row = MySQL.single.await(
        "SELECT * FROM faction_resignations WHERE id = ? AND faction_id = ? AND status = 'pending' LIMIT 1",
        { resignationId, factionId })
    if not row then return nil, 'That resignation request no longer exists.' end
    local targetCharId = tonumber(row.character_id)

    if action == 'decline' then
        MySQL.update.await(
            "UPDATE faction_resignations SET status = 'declined', handled_by_character_id = ?, handled_at = NOW() WHERE id = ?",
            { char.id, resignationId })
        FactionCore.auditLog(factionId, char.id, 'resign_declined', targetCharId, {})
        local targetName = FactionCore.memberDisplayName(targetCharId)
        FactionCore.broadcastManagement(factionId, source, ('declined the resignation of %s.'):format(targetName))
        return true
    end

    -- accept / accept_fp: remove the member from the faction.
    local withFp = (action == 'accept_fp')
    local targetSource
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local c = src and FactionCore.getChar(src)
        if c and tonumber(c.id) == targetCharId then targetSource = src break end
    end

    local removed
    if targetSource then
        removed = exports.sunset_core:SetFaction(targetSource, nil, 0)
    else
        removed = exports.sunset_core:SetFactionByCharacterId(targetCharId, nil, 0)
    end
    if not removed then return nil, 'Could not remove the member. Try again.' end

    MySQL.update.await(
        'DELETE FROM faction_leaders WHERE character_id = ?', { targetCharId })
    MySQL.update.await(
        "UPDATE faction_resignations SET status = ?, handled_by_character_id = ?, handled_at = NOW() WHERE id = ?",
        { withFp and 'accepted_fp' or 'accepted', char.id, resignationId })

    if withFp then
        FactionManagement.setFP(targetCharId, FP_KICK, 'Resignation accepted with FP', char.id)
    else
        FactionManagement.setFP(targetCharId, 0)
    end

    local targetName = FactionCore.memberDisplayName(targetCharId)
    FactionCore.auditLog(factionId, char.id, withFp and 'resign_accepted_fp' or 'resign_accepted', targetCharId, {})
    FactionCore.broadcastManagement(factionId, source,
        ('accepted the resignation of %s%s.'):format(targetName, withFp and ' (with FP)' or ''))
    if targetSource then
        TriggerClientEvent('sunset:client:notify', targetSource,
            withFp and ('Your resignation was accepted WITH faction punish (%d FP).'):format(FP_KICK)
                or 'Your resignation was accepted. You left the faction cleanly.',
            withFp and 'error' or 'info', 10000)
    end
    return true
end)

-- ── FP pardon + status (leader tools) ──────────────────────────

exports.sunset_core:RegisterCallback('sunset:factionPardonFP', function(source, targetCharacterId)
    local char, factionId, err = leaderOnlyForFaction(source)
    if not char then return nil, err end
    targetCharacterId = tonumber(targetCharacterId)
    if not targetCharacterId then return nil, 'Invalid member.' end
    local fp = FactionManagement.getFP(targetCharacterId)
    if fp <= 0 then return nil, 'That character has no FP to pardon.' end
    FactionManagement.setFP(targetCharacterId, 0)
    FactionCore.auditLog(factionId, char.id, 'fp_pardon', targetCharacterId, { previousFp = fp })
    FactionCore.notify(source, ('Pardoned %d FP for %s.'):format(fp, FactionCore.memberDisplayName(targetCharacterId)), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionFPStatus', function(source, targetCharacterId)
    local char = FactionCore.getChar(source)
    if not char then return nil, 'Your character is not loaded.' end
    local factionId = select(1, FactionCore.getFactionOf(char))
    if not factionId then return nil, 'You are not in a faction.' end
    targetCharacterId = tonumber(targetCharacterId) or tonumber(char.id)
    local fp, reason = FactionManagement.getFP(targetCharacterId)
    return { fp = fp, reason = reason }
end)

-- ── Instant self-leave hook: +60 FP ────────────────────────────
-- leaveFactionForSource lives in main.lua; it calls this after a
-- successful self-leave so the FP is recorded with the audit trail.

function FactionManagement.applySelfLeaveFP(source, char, factionId)
    if not char or not char.id then return end
    FactionManagement.setFP(char.id, FP_SELF_LEAVE, 'Left faction without a resignation request', char.id)
    FactionCore.auditLog(factionId, char.id, 'leave_fp', char.id, { fp = FP_SELF_LEAVE })
    TriggerClientEvent('sunset:client:notify', source,
        ('You left instantly: +%d FP. FP decays by 1 per payday and blocks joining any faction. Submit a resignation instead for a clean exit.'):format(FP_SELF_LEAVE),
        'warning', 14000)
end

-- ── Roster enrichment (joined days + fp) for the dashboard ─────
-- Batched: one query for membership + one for FP regardless of roster size
-- (per-member queries would be N+1 on big factions).

function FactionManagement.enrichRoster(roster)
    if type(roster) ~= 'table' or #roster == 0 then return roster end
    local ids = {}
    for _, member in ipairs(roster) do
        ids[#ids + 1] = tonumber(member.characterId)
    end
    local placeholders = table.concat(ids, ',')
    local joinRows = MySQL.query.await(
        ('SELECT character_id, UNIX_TIMESTAMP(joined_at) AS joined_at FROM faction_membership WHERE character_id IN (%s)'):format(placeholders)) or {}
    local fpRows = MySQL.query.await(
        ('SELECT character_id, fp FROM faction_punish WHERE character_id IN (%s)'):format(placeholders)) or {}
    local joinedByChar, fpByChar = {}, {}
    for _, row in ipairs(joinRows) do joinedByChar[tonumber(row.character_id)] = tonumber(row.joined_at) end
    for _, row in ipairs(fpRows) do fpByChar[tonumber(row.character_id)] = math.max(0, tonumber(row.fp) or 0) end
    local now = os.time()
    for _, member in ipairs(roster) do
        local cid = tonumber(member.characterId)
        local joinedAt = joinedByChar[cid]
        member.joinedAt = joinedAt
        member.daysInFaction = joinedAt and math.floor((now - joinedAt) / 86400) or nil
        member.fp = fpByChar[cid] or 0
    end
    return roster
end

print('^2[sunset_factions]^7 management module online (FP / resignations / membership tracking)')
