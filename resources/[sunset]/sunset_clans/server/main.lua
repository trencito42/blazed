local PendingInvites = {}

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function charId(source)
    local char = getChar(source)
    return char and tonumber(char.id)
end

local function notify(source, message, kind)
    TriggerClientEvent('sunset:client:notify', source, message, kind or 'info', 6000)
end

local function sourceForChar(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local char = getChar(src)
        if char and tonumber(char.id) == characterId then return src end
    end
end

local function playerName(characterId)
    local src = sourceForChar(characterId)
    if src then return ClanDisplay.baseName(src) end
    local row = MySQL.single.await(
        'SELECT firstname, lastname FROM characters WHERE id = ? LIMIT 1',
        { characterId }
    )
    if not row then return ('CID %d'):format(characterId) end
    local full = ((row.firstname or '') .. (row.lastname and row.lastname ~= '' and (' ' .. row.lastname) or ''))
        :gsub('^%s+', ''):gsub('%s+$', '')
    return full ~= '' and full or ('CID %d'):format(characterId)
end

local function audit(clanId, actorId, action, details)
    MySQL.insert.await(
        'INSERT INTO clan_audit_log (clan_id, actor_character_id, action, details) VALUES (?, ?, ?, ?)',
        { clanId, actorId, action, details and json.encode(details) or nil }
    )
end

local function cleanColor(hex)
    hex = tostring(hex or ''):gsub('#', '')
    if not hex:match('^%x%x%x%x%x%x$') then return '#FF8C00' end
    return '#' .. string.upper(hex)
end

local function cleanTag(tag)
    tag = tostring(tag or ''):gsub('%s+', '')
    if not tag:match('^[%w]+$') then return nil end
    if #tag < SunsetClans.MinTagLength or #tag > SunsetClans.MaxTagLength then return nil end
    return tag
end

local function cleanName(name)
    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #name < SunsetClans.MinNameLength or #name > SunsetClans.MaxNameLength then return nil end
    if not name:match('^[%w%s%-%.]+$') then return nil end
    return name
end

local function cleanText(value, maxLen)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return '' end
    return value:sub(1, maxLen or 512)
end

local function membershipFor(source)
    local cid = charId(source)
    if not cid then return nil, nil end
    return ClanDisplay.getMembership(cid), cid
end

local function isLeader(row, cid)
    if not row then return false end
    return row.rank == 'leader' or tonumber(row.owner_character_id) == cid
end

local function isOfficer(row)
    return row and (row.rank == 'leader' or row.rank == 'officer')
end

local function clanMemberCount(clanId)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM clan_members WHERE clan_id = ?', { clanId })) or 0
end

local function syncClanMembers(clanId)
    local members = MySQL.query.await('SELECT character_id FROM clan_members WHERE clan_id = ?', { clanId }) or {}
    for _, row in ipairs(members) do
        local src = sourceForChar(row.character_id)
        if src then ClanDisplay.sync(src) end
    end
end

local function tagStyleOptions()
    local out = {}
    for id, meta in pairs(SunsetClans.TagStyles) do
        out[#out + 1] = { id = id, label = meta.label }
    end
    table.sort(out, function(a, b)
        return (SunsetClans.TagStyles[a.id].order or 0) < (SunsetClans.TagStyles[b.id].order or 0)
    end)
    return out
end

local function rankLabel(rank)
    if rank == 'leader' then return 'Leader' end
    if rank == 'officer' then return 'Officer' end
    return 'Member'
end

local function buildRoster(clanId)
    local rows = MySQL.query.await([[
        SELECT cm.character_id, cm.rank, cm.joined_at
        FROM clan_members cm
        WHERE cm.clan_id = ?
        ORDER BY FIELD(cm.rank, 'leader', 'officer', 'member'), cm.joined_at ASC
    ]], { clanId }) or {}

    local roster = {}
    for _, row in ipairs(rows) do
        local src = sourceForChar(row.character_id)
        roster[#roster + 1] = {
            characterId = row.character_id,
            name = playerName(row.character_id),
            rank = row.rank,
            rankLabel = rankLabel(row.rank),
            online = src ~= nil,
            serverId = src,
            leader = row.rank == 'leader',
        }
    end
    return roster
end

local function dashboardPayload(source, row, cid)
    local player = exports.sunset_core:GetPlayer(source)
    local baseName = ClanDisplay.baseName(source)
    local previewName = baseName
    if row and row.tag and row.tag ~= '' then
        previewName = SunsetClans.formatTaggedName(row.tag, baseName, row.tag_style)
    end

    return {
        inClan = row ~= nil,
        clanId = row and row.clan_id or nil,
        name = row and row.name or nil,
        tag = row and row.tag or nil,
        description = row and (row.description or '') or '',
        motd = row and (row.motd or '') or '',
        tagColor = row and row.tag_color or '#FF8C00',
        tagStyle = row and row.tag_style or 'brackets',
        previewName = previewName,
        memberCount = row and clanMemberCount(row.clan_id) or 0,
        maxMembers = row and (row.max_members or SunsetClans.MaxMembers) or SunsetClans.MaxMembers,
        members = row and buildRoster(row.clan_id) or {},
        leader = row and isLeader(row, cid) or false,
        officer = row and isOfficer(row) or false,
        rank = row and row.rank or nil,
        rankLabel = row and rankLabel(row.rank) or nil,
        creationCost = SunsetClans.CreationCost,
        accountCoins = player and (tonumber(player.premium_points) or 0) or 0,
        tagStyles = tagStyleOptions(),
        permissions = {
            leader = row and isLeader(row, cid) or false,
            officer = row and isOfficer(row) or false,
            invite = row and isOfficer(row) or false,
            kick = row and isOfficer(row) or false,
            motd = row and isOfficer(row) or false,
            settings = row and isLeader(row, cid) or false,
            promote = row and isLeader(row, cid) or false,
            dissolve = row and isLeader(row, cid) or false,
            leave = row ~= nil,
        },
    }
end

local function spendCoins(source, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local player = exports.sunset_core:GetPlayer(source)
    if not player then return false, 'Account not loaded.' end
    local balance = tonumber(player.premium_points) or 0
    if balance < amount then
        return false, ('You need %d Sunset Coins (you have %d).'):format(amount, balance)
    end
    local ok, err = Sunset.SetPersistentStat(source, 'account', 'premium_points', balance - amount)
    if not ok then return false, err or 'Could not spend Sunset Coins.' end
    return true
end

exports.sunset_core:RegisterCallback('sunset:clanDashboard', function(source)
    local row, cid = membershipFor(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    return dashboardPayload(source, row, cid)
end)

exports.sunset_core:RegisterCallback('sunset:clanDirectory', function(source)
    if not charId(source) then return nil, 'Your character is not loaded. Reconnect and try again.' end
    local rows = MySQL.query.await([[
        SELECT c.id, c.name, c.tag, c.tag_color, c.tag_style, c.description,
               (SELECT COUNT(*) FROM clan_members cm WHERE cm.clan_id = c.id) AS total
        FROM clans c
        ORDER BY c.name ASC
    ]]) or {}

    local clans = {}
    for _, row in ipairs(rows) do
        local online = 0
        local members = MySQL.query.await('SELECT character_id FROM clan_members WHERE clan_id = ?', { row.id }) or {}
        for _, member in ipairs(members) do
            if sourceForChar(member.character_id) then online = online + 1 end
        end
        clans[#clans + 1] = {
            id = row.id,
            name = row.name,
            tag = row.tag,
            tagColor = row.tag_color,
            tagStyle = row.tag_style,
            description = row.description or '',
            total = tonumber(row.total) or 0,
            online = online,
            preview = SunsetClans.formatTaggedName(row.tag, 'Player', row.tag_style),
        }
    end
    return clans
end)

exports.sunset_core:RegisterCallback('sunset:clanCreate', function(source, payload)
    if type(payload) ~= 'table' then return nil, 'Invalid create request.' end
    local cid = charId(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    if ClanDisplay.getMembership(cid) then return nil, 'You are already in a clan.' end

    local name = cleanName(payload.name)
    local tag = cleanTag(payload.tag)
    local description = cleanText(payload.description, SunsetClans.MaxDescriptionLength)
    local tagColor = cleanColor(payload.tagColor)
    local tagStyle = tostring(payload.tagStyle or 'brackets')
    if not SunsetClans.isValidTagStyle(tagStyle) then tagStyle = 'brackets' end

    if not name then return nil, ('Clan name must be %d-%d letters, numbers, spaces, dots or dashes.'):format(
        SunsetClans.MinNameLength, SunsetClans.MaxNameLength) end
    if not tag then return nil, ('Clan tag must be %d-%d letters or numbers.'):format(
        SunsetClans.MinTagLength, SunsetClans.MaxTagLength) end

    local existing = MySQL.scalar.await('SELECT id FROM clans WHERE LOWER(name) = LOWER(?) OR LOWER(tag) = LOWER(?) LIMIT 1', { name, tag })
    if existing then return nil, 'That clan name or tag is already taken.' end

    local cost = SunsetClans.CreationCost
    local paid, payErr = spendCoins(source, cost)
    if not paid then return nil, payErr end

    local clanId = MySQL.insert.await([[
        INSERT INTO clans (name, tag, description, tag_color, tag_style, owner_character_id, max_members)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { name, tag, description, tagColor, tagStyle, cid, SunsetClans.MaxMembers })

    MySQL.insert.await('INSERT INTO clan_members (clan_id, character_id, rank) VALUES (?, ?, ?)', {
        clanId, cid, 'leader',
    })
    audit(clanId, cid, 'create', { name = name, tag = tag, cost = cost })
    ClanDisplay.sync(source)
    return dashboardPayload(source, ClanDisplay.getMembership(cid), cid)
end)

exports.sunset_core:RegisterCallback('sunset:clanManage', function(source, payload)
    if type(payload) ~= 'table' then return nil, 'Invalid clan action.' end
    local action = tostring(payload.action or '')
    local row, cid = membershipFor(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end

    if action == 'motd' then
        if not row or not isOfficer(row) then return nil, 'Only clan leaders and officers can set the MOTD.' end
        local motd = cleanText(payload.message, SunsetClans.MaxMotdLength)
        MySQL.update.await('UPDATE clans SET motd = ? WHERE id = ?', { motd, row.clan_id })
        audit(row.clan_id, cid, 'motd', { motd = motd })
        syncClanMembers(row.clan_id)
        return dashboardPayload(source, ClanDisplay.getMembership(cid), cid)
    end

    if action == 'settings' then
        if not row or not isLeader(row, cid) then return nil, 'Only the clan leader can change clan settings.' end
        local description = cleanText(payload.description, SunsetClans.MaxDescriptionLength)
        local tagColor = cleanColor(payload.tagColor)
        local tagStyle = tostring(payload.tagStyle or row.tag_style)
        if not SunsetClans.isValidTagStyle(tagStyle) then return nil, 'Invalid tag style.' end
        MySQL.update.await(
            'UPDATE clans SET description = ?, tag_color = ?, tag_style = ? WHERE id = ?',
            { description, tagColor, tagStyle, row.clan_id }
        )
        audit(row.clan_id, cid, 'settings', { tagColor = tagColor, tagStyle = tagStyle })
        syncClanMembers(row.clan_id)
        return dashboardPayload(source, ClanDisplay.getMembership(cid), cid)
    end

    if action == 'invite' then
        if not row or not isOfficer(row) then return nil, 'Only clan leaders and officers can invite members.' end
        if clanMemberCount(row.clan_id) >= (row.max_members or SunsetClans.MaxMembers) then
            return nil, 'Your clan is full.'
        end
        local targetId = tonumber(payload.targetId)
        if not targetId or not GetPlayerName(targetId) then
            return nil, ('Player ID %s is not online.'):format(tostring(payload.targetId or '?'))
        end
        if targetId == source then return nil, 'You cannot invite yourself.' end
        local targetCid = charId(targetId)
        if not targetCid then return nil, 'That player has not loaded a character yet.' end
        if ClanDisplay.getMembership(targetCid) then return nil, 'That player is already in a clan.' end

        local expiresAt = os.time() + SunsetClans.InviteExpirySec
        MySQL.insert.await([[
            INSERT INTO clan_invites (clan_id, character_id, invited_by, expires_at)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE invited_by = VALUES(invited_by), expires_at = VALUES(expires_at)
        ]], { row.clan_id, targetCid, cid, expiresAt })

        PendingInvites[targetId] = {
            clanId = row.clan_id,
            clanName = row.name,
            tag = row.tag,
            expiresAt = expiresAt,
            invitedBy = source,
        }
        notify(targetId, ('Clan invite from %s [%s]. Use /acceptclan or /declineclan.'):format(row.name, row.tag), 'info', 12000)
        audit(row.clan_id, cid, 'invite', { targetCharacterId = targetCid, targetId = targetId })
        return dashboardPayload(source, row, cid)
    end

    if action == 'kick' then
        if not row or not isOfficer(row) then return nil, 'Only clan leaders and officers can remove members.' end
        local targetId = tonumber(payload.targetId)
        if not targetId or not GetPlayerName(targetId) then
            return nil, ('Player ID %s is not online.'):format(tostring(payload.targetId or '?'))
        end
        local targetCid = charId(targetId)
        if not targetCid then return nil, 'That player has not loaded a character yet.' end
        local targetRow = ClanDisplay.getMembership(targetCid)
        if not targetRow or tonumber(targetRow.clan_id) ~= tonumber(row.clan_id) then
            return nil, 'That player is not in your clan.'
        end
        if targetRow.rank == 'leader' then return nil, 'You cannot remove the clan leader.' end
        if targetRow.rank == 'officer' and not isLeader(row, cid) then
            return nil, 'Only the leader can remove officers.'
        end
        MySQL.update.await('DELETE FROM clan_members WHERE clan_id = ? AND character_id = ?', { row.clan_id, targetCid })
        ClanDisplay.sync(targetId)
        notify(targetId, ('You were removed from %s.'):format(row.name), 'warning')
        audit(row.clan_id, cid, 'kick', { targetCharacterId = targetCid })
        return dashboardPayload(source, ClanDisplay.getMembership(cid), cid)
    end

    if action == 'promote' then
        if not row or not isLeader(row, cid) then return nil, 'Only the clan leader can change ranks.' end
        local targetId = tonumber(payload.targetId)
        local rank = tostring(payload.rank or '')
        if rank ~= 'officer' and rank ~= 'member' then return nil, 'Invalid rank.' end
        if not targetId or not GetPlayerName(targetId) then
            return nil, ('Player ID %s is not online.'):format(tostring(payload.targetId or '?'))
        end
        local targetCid = charId(targetId)
        local targetRow = targetCid and ClanDisplay.getMembership(targetCid)
        if not targetRow or tonumber(targetRow.clan_id) ~= tonumber(row.clan_id) then
            return nil, 'That player is not in your clan.'
        end
        if targetRow.rank == 'leader' then return nil, 'You cannot change the leader rank this way.' end
        MySQL.update.await('UPDATE clan_members SET rank = ? WHERE clan_id = ? AND character_id = ?', {
            rank, row.clan_id, targetCid,
        })
        notify(targetId, ('Your clan rank is now %s.'):format(rankLabel(rank)), 'info')
        audit(row.clan_id, cid, 'promote', { targetCharacterId = targetCid, rank = rank })
        return dashboardPayload(source, ClanDisplay.getMembership(cid), cid)
    end

    if action == 'leave' then
        if not row then return nil, 'You are not in a clan.' end
        if isLeader(row, cid) then
            return nil, 'Leaders must dissolve the clan or transfer leadership before leaving.'
        end
        MySQL.update.await('DELETE FROM clan_members WHERE clan_id = ? AND character_id = ?', { row.clan_id, cid })
        ClanDisplay.sync(source)
        audit(row.clan_id, cid, 'leave', {})
        return dashboardPayload(source, nil, cid)
    end

    if action == 'dissolve' then
        if not row or not isLeader(row, cid) then return nil, 'Only the clan leader can dissolve the clan.' end
        local members = MySQL.query.await('SELECT character_id FROM clan_members WHERE clan_id = ?', { row.clan_id }) or {}
        MySQL.update.await('DELETE FROM clans WHERE id = ?', { row.clan_id })
        for _, member in ipairs(members) do
            local src = sourceForChar(member.character_id)
            if src then ClanDisplay.sync(src) end
        end
        audit(row.clan_id, cid, 'dissolve', {})
        return dashboardPayload(source, nil, cid)
    end

    return nil, 'Unknown clan action.'
end)

local function acceptInvite(source)
    local cid = charId(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    if ClanDisplay.getMembership(cid) then return nil, 'You are already in a clan.' end

    local pending = PendingInvites[source]
    local invite = pending
    if not invite then
        invite = MySQL.single.await([[
            SELECT ci.clan_id, ci.expires_at, c.name, c.tag
            FROM clan_invites ci
            INNER JOIN clans c ON c.id = ci.clan_id
            WHERE ci.character_id = ?
            ORDER BY ci.expires_at DESC
            LIMIT 1
        ]], { cid })
    end
    if not invite then return nil, 'You have no pending clan invites.' end
    if tonumber(invite.expires_at) and tonumber(invite.expires_at) < os.time() then
        MySQL.update.await('DELETE FROM clan_invites WHERE clan_id = ? AND character_id = ?', { invite.clan_id, cid })
        PendingInvites[source] = nil
        return nil, 'That clan invite expired.'
    end

    local count = clanMemberCount(invite.clan_id)
    local maxMembers = tonumber(MySQL.scalar.await('SELECT max_members FROM clans WHERE id = ?', { invite.clan_id })) or SunsetClans.MaxMembers
    if count >= maxMembers then
        return nil, 'That clan is full.'
    end

    MySQL.insert.await('INSERT INTO clan_members (clan_id, character_id, rank) VALUES (?, ?, ?)', {
        invite.clan_id, cid, 'member',
    })
    MySQL.update.await('DELETE FROM clan_invites WHERE clan_id = ? AND character_id = ?', { invite.clan_id, cid })
    PendingInvites[source] = nil
    ClanDisplay.sync(source)
    audit(invite.clan_id, cid, 'join', {})
    return dashboardPayload(source, ClanDisplay.getMembership(cid), cid)
end

exports.sunset_core:RegisterCallback('sunset:clanAcceptInvite', function(source)
    return acceptInvite(source)
end)

exports.sunset_core:RegisterCallback('sunset:clanDeclineInvite', function(source)
    local cid = charId(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    local pending = PendingInvites[source]
    if pending then
        MySQL.update.await('DELETE FROM clan_invites WHERE clan_id = ? AND character_id = ?', { pending.clanId, cid })
        PendingInvites[source] = nil
        return true
    end
    MySQL.update.await('DELETE FROM clan_invites WHERE character_id = ?', { cid })
    return true
end)

RegisterCommand('clan', function(source)
    if source == 0 then return end
    TriggerClientEvent('sunset:clans:openDashboard', source)
end, false)

RegisterCommand('clans', function(source)
    if source == 0 then return end
    TriggerClientEvent('sunset:clans:openDirectory', source)
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if GetResourceState('sunset_chat') == 'started' then
        pcall(function() exports.sunset_chat:RefreshCommandList() end)
    end
end)
