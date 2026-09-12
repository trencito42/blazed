local PendingInvites = {}

local function normalizeInvite(invite)
    if not invite then return nil end
    local clanId = tonumber(invite.clan_id or invite.clanId)
    if not clanId then return nil end
    return {
        clan_id = clanId,
        expires_at = tonumber(invite.expires_at or invite.expiresAt),
        name = invite.name or invite.clanName,
        tag = invite.tag,
    }
end

local function setPremiumPoints(source, value)
    return exports.sunset_core:SetPersistentStat(source, 'account', 'premium_points', value)
end

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

local function memberRank(row)
    return SunsetClans.normalizeRank(row and row.rank)
end

local function clanRankLabels(row)
    return SunsetClans.decodeRankLabels(row and row.rank_labels)
end

local function isLeader(row, cid)
    if not row then return false end
    if tonumber(row.owner_character_id) == cid then return true end
    return memberRank(row) >= SunsetClans.MaxRank
end

local function isOfficer(row, cid)
    if not row then return false end
    if cid and isLeader(row, cid) then return true end
    return memberRank(row) >= 5
end

local function canManageMember(actorRow, targetRow, cid)
    if not actorRow or not targetRow then return false end
    if tonumber(targetRow.character_id) == tonumber(actorRow.owner_character_id) then return false end
    if tonumber(targetRow.character_id) == cid then return false end
    if isLeader(actorRow, cid) then return true end
    if not isOfficer(actorRow, cid) then return false end
    return memberRank(actorRow) > memberRank(targetRow)
end

local function rankLabelFor(row, rank)
    local labels = clanRankLabels(row)
    return SunsetClans.getRankLabel(labels, rank or memberRank(row))
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

local function rosterRankLabel(rank, labels)
    return SunsetClans.getRankLabel(labels, rank)
end

local function tagStyleLabel(style)
    local meta = SunsetClans.TagStyles[style]
    return meta and meta.label or style or '—'
end

local function characterDisplayName(characterId)
    characterId = tonumber(characterId)
    if not characterId then return 'Unknown' end
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

local function clanDirectoryRow(row, turfCount)
    local online = 0
    local members = MySQL.query.await('SELECT character_id FROM clan_members WHERE clan_id = ?', { row.id }) or {}
    for _, member in ipairs(members) do
        if sourceForChar(member.character_id) then online = online + 1 end
    end
    local leaderName = characterDisplayName(row.owner_character_id)
    return {
        id = row.id,
        name = row.name,
        tag = row.tag,
        tagColor = row.tag_color,
        tagStyle = row.tag_style,
        tagStyleLabel = tagStyleLabel(row.tag_style),
        description = row.description or '',
        motd = row.motd or '',
        total = tonumber(row.total) or 0,
        online = online,
        maxMembers = tonumber(row.max_members) or SunsetClans.MaxMembers,
        leader = leaderName,
        leaderCharacterId = tonumber(row.owner_character_id),
        turfs = tonumber(turfCount) or 0,   -- [LEADERBOARD] territories held
    }
end

-- [LEADERBOARD] Count of turfs owned per clan (turfs domain, read-only join).
local function turfCountsByClan()
    local counts = {}
    local ok, rows = pcall(function()
        return MySQL.query.await(
            'SELECT owner_clan_id, COUNT(*) AS n FROM turfs WHERE owner_clan_id IS NOT NULL GROUP BY owner_clan_id'
        ) or {}
    end)
    if ok then
        for _, r in ipairs(rows) do
            counts[tonumber(r.owner_clan_id)] = tonumber(r.n) or 0
        end
    end
    return counts
end

local function buildRoster(clanId, labels)
    labels = labels or SunsetClans.decodeRankLabels(MySQL.scalar.await(
        'SELECT rank_labels FROM clans WHERE id = ?', { clanId }
    ))
    local rows = MySQL.query.await([[
        SELECT cm.character_id, cm.rank, cm.warns, cm.joined_at
        FROM clan_members cm
        WHERE cm.clan_id = ?
        ORDER BY cm.rank DESC, cm.joined_at ASC
    ]], { clanId }) or {}

    local ownerId = tonumber(MySQL.scalar.await('SELECT owner_character_id FROM clans WHERE id = ?', { clanId }))
    local roster = {}
    for _, row in ipairs(rows) do
        local src = sourceForChar(row.character_id)
        local rank = SunsetClans.normalizeRank(row.rank)
        roster[#roster + 1] = {
            characterId = row.character_id,
            name = playerName(row.character_id),
            rank = rank,
            rankLabel = rosterRankLabel(rank, labels),
            warns = tonumber(row.warns) or 0,
            online = src ~= nil,
            serverId = src,
            leader = rank >= SunsetClans.MaxRank or tonumber(row.character_id) == ownerId,
        }
    end
    return roster
end

local function clanProfilePayload(clanId)
    clanId = tonumber(clanId)
    if not clanId then return nil, 'Invalid clan.' end
    local row = MySQL.single.await([[
        SELECT c.id, c.name, c.tag, c.tag_color, c.tag_style, c.description, c.motd,
               c.owner_character_id, c.max_members,
               (SELECT COUNT(*) FROM clan_members cm WHERE cm.clan_id = c.id) AS total
        FROM clans c
        WHERE c.id = ?
        LIMIT 1
    ]], { clanId })
    if not row then return nil, 'Clan not found.' end

    local profile = clanDirectoryRow(row)
    profile.members = buildRoster(clanId)
    return profile
end

local function dashboardPayload(source, row, cid)
    local player = exports.sunset_core:GetPlayer(source)
    local baseName = ClanDisplay.baseName(source)
    local previewName = baseName
    if row and row.tag and row.tag ~= '' then
        previewName = SunsetClans.formatTaggedName(row.tag, baseName, row.tag_style)
    end

    local labels = row and clanRankLabels(row) or SunsetClans.defaultRankLabels()
    local rank = row and memberRank(row) or nil

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
        -- [LEADERBOARD] territories held by this clan, shown in /clan panel.
        turfs = row and (tonumber(MySQL.scalar.await(
            'SELECT COUNT(*) FROM turfs WHERE owner_clan_id = ?', { row.clan_id })) or 0) or 0,
        memberCount = row and clanMemberCount(row.clan_id) or 0,
        maxMembers = row and (row.max_members or SunsetClans.MaxMembers) or SunsetClans.MaxMembers,
        members = row and buildRoster(row.clan_id, labels) or {},
        leader = row and isLeader(row, cid) or false,
        officer = row and isOfficer(row, cid) or false,
        rank = rank,
        rankLabel = row and rankLabelFor(row, rank) or nil,
        rankLabels = labels,
        creationCost = SunsetClans.CreationCost,
        accountCoins = player and (tonumber(player.premium_points) or 0) or 0,
        tagStyles = tagStyleOptions(),
        viewerCharacterId = cid,
        permissions = {
            leader = row and isLeader(row, cid) or false,
            officer = row and isOfficer(row, cid) or false,
            invite = row and isOfficer(row, cid) or false,
            kick = row and isOfficer(row, cid) or false,
            motd = row and isOfficer(row, cid) or false,
            settings = row and isLeader(row, cid) or false,
            promote = row and isOfficer(row, cid) or false,
            rankLabels = row and isLeader(row, cid) or false,
            warn = row and isOfficer(row, cid) or false,
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
        return false, ('You need %d Blaze Points (you have %d).'):format(amount, balance)
    end
    local ok, err = setPremiumPoints(source, balance - amount)
    if not ok then return false, err or 'Could not spend Blaze Points.' end
    return true
end

local function broadcastClanManagement(clanId, actorSource, message)
    clanId = tonumber(clanId)
    message = tostring(message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if not clanId or message == '' then return end

    local clanRow = MySQL.single.await(
        'SELECT name, tag, tag_color, tag_style, rank_labels FROM clans WHERE id = ? LIMIT 1',
        { clanId }
    )

    local actorName = 'System'
    local rank = 0
    local rankLabel = ''
    local tag = clanRow and clanRow.tag or ''
    local tagColor = clanRow and clanRow.tag_color or '#FF8C00'
    local tagStyle = clanRow and clanRow.tag_style or 'brackets'

    if actorSource then
        actorName = exports.sunset_core:GetPlayerBaseName(actorSource) or ClanDisplay.baseName(actorSource)
        local actorCid = charId(actorSource)
        local memberRow = actorCid and ClanDisplay.getMembership(actorCid)
        if memberRow and tonumber(memberRow.clan_id) == clanId then
            rank = SunsetClans.normalizeRank(memberRow.rank)
            rankLabel = SunsetClans.getRankLabel(clanRankLabels(memberRow), rank)
            tag = memberRow.tag or tag
            tagColor = memberRow.tag_color or tagColor
            tagStyle = memberRow.tag_style or tagStyle
        end
    end

    local payload = {
        id = actorSource or 0,
        name = actorName,
        message = message,
        time = os.date('%H:%M:%S'),
        type = 'clan_action',
        clanId = clanId,
        clanName = clanRow and clanRow.name or '',
        clanTag = tag,
        clanTagColor = tagColor,
        clanTagStyle = tagStyle,
        clanRank = rank,
        clanRankLabel = rankLabel,
    }

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local memberCid = charId(src)
        if not memberCid then goto continue end
        local member = ClanDisplay.getMembership(memberCid)
        if member and tonumber(member.clan_id) == clanId then
            TriggerClientEvent('sunset:chat:message', src, payload)
        end
        ::continue::
    end
end

local function audit(clanId, actorId, action, details)
    MySQL.insert.await(
        'INSERT INTO clan_audit_log (clan_id, actor_character_id, action, details) VALUES (?, ?, ?, ?)',
        { clanId, actorId, action, details and json.encode(details) or nil }
    )
end

local function safeAudit(...)
    local ok, err = pcall(audit, ...)
    if not ok then
        print(('^3[sunset_clans]^7 audit failed: %s'):format(tostring(err)))
    end
end

local function safeBroadcast(...)
    local ok, err = pcall(broadcastClanManagement, ...)
    if not ok then
        print(('^3[sunset_clans]^7 broadcast failed: %s'):format(tostring(err)))
    end
end

local function safeSyncMembers(clanId)
    local ok, err = pcall(syncClanMembers, clanId)
    if not ok then
        print(('^3[sunset_clans]^7 member sync failed: %s'):format(tostring(err)))
    end
end

local function clanManageDashboard(source, cid)
    local fresh = ClanDisplay.getMembership(cid)
    if not fresh then
        return nil, 'Your clan membership could not be reloaded. Reopen /clan.'
    end
    local ok, dashboard = pcall(dashboardPayload, source, fresh, cid)
    if not ok then
        print(('^1[sunset_clans]^7 dashboard failed: %s'):format(tostring(dashboard)))
        return nil, 'Changes saved. Reopen /clan to see the update.'
    end
    return dashboard
end

local function showClanMotd(source)
    local row, cid = membershipFor(source)
    if not cid then return false, 'Your character is not loaded. Reconnect and try again.' end
    if not row then return false, 'You are not in a clan.' end
    local message = tostring(row.motd or '')
    TriggerClientEvent('sunset:chat:message', source, {
        type = 'clan_motd',
        id = 0,
        time = '',
        clanTag = row.tag,
        clanName = row.name,
        name = row.name,
        message = message ~= '' and message or 'No message of the day has been set.',
        command = '/cmotd',
    })
    return true
end

local function applyClanMotd(source, message)
    local row, cid = membershipFor(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    if not row or not isOfficer(row, cid) then return nil, 'Only clan leaders and officers can set the MOTD.' end
    local motd = cleanText(message, SunsetClans.MaxMotdLength)
    MySQL.update.await('UPDATE clans SET motd = ? WHERE id = ?', { motd, row.clan_id })
    safeAudit(row.clan_id, cid, 'motd', { motd = motd })
    safeBroadcast(row.clan_id, source,
        motd ~= '' and ('updated the clan MOTD: %s'):format(motd) or 'cleared the clan MOTD.')
    safeSyncMembers(row.clan_id)
    return clanManageDashboard(source, cid)
end

exports.sunset_core:RegisterCallback('sunset:clanDashboard', function(source)
    local row, cid = membershipFor(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    return dashboardPayload(source, row, cid)
end)

exports.sunset_core:RegisterCallback('sunset:clanDirectory', function(source)
    if not charId(source) then return nil, 'Your character is not loaded. Reconnect and try again.' end
    local rows = MySQL.query.await([[
        SELECT c.id, c.name, c.tag, c.tag_color, c.tag_style, c.description, c.motd,
               c.owner_character_id, c.max_members,
               (SELECT COUNT(*) FROM clan_members cm WHERE cm.clan_id = c.id) AS total
        FROM clans c
        ORDER BY c.name ASC
    ]]) or {}

    local turfCounts = turfCountsByClan()
    local clans = {}
    for _, row in ipairs(rows) do
        clans[#clans + 1] = clanDirectoryRow(row, turfCounts[tonumber(row.id)])
    end
    -- [LEADERBOARD] Sort by territories held, then members, then name — so the
    -- directory doubles as a clan turf-war leaderboard for all players.
    table.sort(clans, function(a, b)
        if (a.turfs or 0) ~= (b.turfs or 0) then return (a.turfs or 0) > (b.turfs or 0) end
        if (a.total or 0) ~= (b.total or 0) then return (a.total or 0) > (b.total or 0) end
        return (a.name or '') < (b.name or '')
    end)
    return clans
end)

exports.sunset_core:RegisterCallback('sunset:clanProfile', function(source, clanId)
    if not charId(source) then return nil, 'Your character is not loaded. Reconnect and try again.' end
    return clanProfilePayload(clanId)
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

    local player = exports.sunset_core:GetPlayer(source)
    local balanceBefore = player and tonumber(player.premium_points) or 0
    local cost = SunsetClans.CreationCost
    local paid, payErr = spendCoins(source, cost)
    if not paid then return nil, payErr end

    local function refundCoins()
        if cost > 0 then
            setPremiumPoints(source, balanceBefore)
        end
    end

    local clanId
    local insertOk, insertErr = pcall(function()
        clanId = MySQL.insert.await([[
            INSERT INTO clans (name, tag, description, tag_color, tag_style, owner_character_id, max_members)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], { name, tag, description, tagColor, tagStyle, cid, SunsetClans.MaxMembers })
    end)
    if not insertOk or not clanId then
        refundCoins()
        print(('[sunset_clans] clanCreate insert failed for %s: %s'):format(source, tostring(insertErr or clanId)))
        return nil, 'Could not create clan in the database. Your Blaze Points were refunded.'
    end

    local memberOk, memberErr = pcall(function()
        MySQL.insert.await('INSERT INTO clan_members (clan_id, character_id, rank) VALUES (?, ?, ?)', {
            clanId, cid, SunsetClans.MaxRank,
        })
    end)
    if not memberOk then
        pcall(function() MySQL.update.await('DELETE FROM clans WHERE id = ?', { clanId }) end)
        refundCoins()
        print(('[sunset_clans] clanCreate member insert failed for %s: %s'):format(source, tostring(memberErr)))
        return nil, 'Could not add you as clan leader. Your Blaze Points were refunded.'
    end

    pcall(function()
        audit(clanId, cid, 'create', { name = name, tag = tag, cost = cost })
    end)

    local syncOk, syncErr = pcall(function()
        ClanDisplay.sync(source)
    end)
    if not syncOk then
        print(('[sunset_clans] clanCreate sync failed for %s: %s'):format(source, tostring(syncErr)))
    end

    local row = ClanDisplay.getMembership(cid)
    if not row then
        return nil, 'Clan was created but could not be loaded. Reopen /clan.'
    end

    local payloadOk, payload = pcall(dashboardPayload, source, row, cid)
    if not payloadOk then
        print(('[sunset_clans] clanCreate dashboard failed for %s: %s'):format(source, tostring(payload)))
        return nil, 'Clan created. Reopen /clan to view your clan page.'
    end
    safeBroadcast(clanId, source, ('founded the clan %s [%s].'):format(name, tag))
    return payload
end)

exports.sunset_core:RegisterCallback('sunset:clanGetMotd', function(source)
    local row, cid = membershipFor(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    if not row then return nil, 'You are not in a clan.' end
    return {
        tag = row.tag,
        name = row.name,
        message = tostring(row.motd or ''),
    }
end)

local function handleClanManage(source, payload)
    if type(payload) ~= 'table' then return nil, 'Invalid clan action.' end
    local action = tostring(payload.action or '')
    local row, cid = membershipFor(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end

    if action == 'motd' then
        return applyClanMotd(source, payload.message)
    end

    if action == 'settings' then
        if not row or not isLeader(row, cid) then return nil, 'Only the clan leader can change clan settings.' end
        local description = cleanText(payload.description, SunsetClans.MaxDescriptionLength)
        local tag = cleanTag(payload.tag)
        if not tag then
            return nil, ('Clan tag must be %d-%d letters or numbers.'):format(
                SunsetClans.MinTagLength, SunsetClans.MaxTagLength)
        end
        if tag:lower() ~= tostring(row.tag or ''):lower() then
            local taken = MySQL.scalar.await(
                'SELECT id FROM clans WHERE LOWER(tag) = LOWER(?) AND id <> ? LIMIT 1',
                { tag, row.clan_id }
            )
            if taken then return nil, 'That clan tag is already taken.' end
        end
        local tagColor = cleanColor(payload.tagColor)
        local tagStyle = tostring(payload.tagStyle or row.tag_style or 'brackets')
        if not SunsetClans.isValidTagStyle(tagStyle) then return nil, 'Invalid tag style.' end
        MySQL.update.await(
            'UPDATE clans SET description = ?, tag = ?, tag_color = ?, tag_style = ? WHERE id = ?',
            { description, tag, tagColor, tagStyle, row.clan_id }
        )
        safeAudit(row.clan_id, cid, 'settings', { tag = tag, tagColor = tagColor, tagStyle = tagStyle })
        safeBroadcast(row.clan_id, source, 'updated clan settings.')
        safeSyncMembers(row.clan_id)
        return clanManageDashboard(source, cid)
    end

    if action == 'invite' then
        if not row or not isOfficer(row, cid) then return nil, 'Only clan leaders and officers can invite members.' end
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
        safeAudit(row.clan_id, cid, 'invite', { targetCharacterId = targetCid, targetId = targetId })
        safeBroadcast(row.clan_id, source,
            ('invited %s to join the clan.'):format(exports.sunset_core:GetPlayerDisplayName(targetId)))
        return clanManageDashboard(source, cid)
    end

    local function resolveClanMember(payload, requireOnline)
        local targetCid = tonumber(payload.targetCharacterId)
        local targetId = tonumber(payload.targetId)

        if targetCid then
            local targetRow = ClanDisplay.getMembership(targetCid)
            if not targetRow or tonumber(targetRow.clan_id) ~= tonumber(row.clan_id) then
                return nil, nil, nil, 'That player is not in your clan.'
            end
            local src = sourceForChar(targetCid)
            if requireOnline and not src then
                return nil, nil, nil, 'That clan member must be online for this action.'
            end
            return src, targetCid, targetRow
        end

        if targetId and GetPlayerName(targetId) then
            local resolvedCid = charId(targetId)
            if not resolvedCid then return nil, nil, nil, 'That player has not loaded a character yet.' end
            local targetRow = ClanDisplay.getMembership(resolvedCid)
            if not targetRow or tonumber(targetRow.clan_id) ~= tonumber(row.clan_id) then
                return nil, nil, nil, 'That player is not in your clan.'
            end
            return targetId, resolvedCid, targetRow
        end

        if targetId then
            return nil, nil, nil, ('Player ID %s is not online.'):format(tostring(targetId))
        end
        return nil, nil, nil, 'Select a clan member.'
    end

    if action == 'kick' then
        if not row or not isOfficer(row, cid) then return nil, 'Only clan leaders and officers can remove members.' end
        local targetId, targetCid, targetRow, err = resolveClanMember(payload, false)
        if not targetCid then return nil, err end
        if not canManageMember(row, targetRow, cid) then
            return nil, 'You cannot remove that member.'
        end
        if memberRank(targetRow) >= SunsetClans.MaxRank then
            return nil, 'You cannot remove the clan leader.'
        end
        safeBroadcast(row.clan_id, source,
            ('removed %s from the clan.'):format(playerName(targetCid)))
        MySQL.update.await('DELETE FROM clan_members WHERE clan_id = ? AND character_id = ?', { row.clan_id, targetCid })
        if targetId then
            ClanDisplay.sync(targetId)
            notify(targetId, ('You were removed from %s.'):format(row.name), 'warning')
        end
        safeAudit(row.clan_id, cid, 'kick', { targetCharacterId = targetCid })
        return clanManageDashboard(source, cid)
    end

    if action == 'rankUp' or action == 'rankDown' then
        if not row or not isOfficer(row, cid) then return nil, 'Only clan officers and leaders can change ranks.' end
        local targetId, targetCid, targetRow, err = resolveClanMember(payload, true)
        if not targetCid then return nil, err end
        if not canManageMember(row, targetRow, cid) then
            return nil, 'You cannot change that member\'s rank.'
        end
        local current = memberRank(targetRow)
        local nextRank
        if action == 'rankUp' then
            nextRank = current + 1
        else
            nextRank = current - 1
        end
        if not isLeader(row, cid) and nextRank >= memberRank(row) then
            return nil, 'You can only promote members below your own rank.'
        end
        if nextRank < 1 or nextRank > SunsetClans.MaxRank then
            return nil, 'That rank change is not allowed.'
        end
        if nextRank >= SunsetClans.MaxRank and tonumber(targetCid) ~= tonumber(row.owner_character_id) then
            return nil, 'Only the clan owner can hold the top rank.'
        end
        MySQL.update.await('UPDATE clan_members SET rank = ? WHERE clan_id = ? AND character_id = ?', {
            nextRank, row.clan_id, targetCid,
        })
        local labels = clanRankLabels(row)
        if targetId then
            notify(targetId, ('Your clan rank is now %s (rank %d).'):format(
                SunsetClans.getRankLabel(labels, nextRank), nextRank), 'info')
        end
        safeAudit(row.clan_id, cid, action, { targetCharacterId = targetCid, rank = nextRank })
        local verb = action == 'rankUp' and 'promoted' or 'demoted'
        safeBroadcast(row.clan_id, source,
            ('%s %s to %s (rank %d).'):format(
                verb, playerName(targetCid), SunsetClans.getRankLabel(labels, nextRank), nextRank))
        syncClanMembers(row.clan_id)
        return clanManageDashboard(source, cid)
    end

    if action == 'warn' then
        if not row or not isOfficer(row, cid) then return nil, 'Only clan officers and leaders can issue warnings.' end
        local targetId, targetCid, targetRow, err = resolveClanMember(payload, false)
        if not targetCid then return nil, err end
        if not canManageMember(row, targetRow, cid) then
            return nil, 'You cannot warn that member.'
        end
        local warns = tonumber(targetRow.warns) or 0
        if warns >= SunsetClans.MaxWarns then
            return nil, 'This member already has 3/3 clan warnings.'
        end
        local reason = cleanText(payload.reason, 128)
        if reason == '' then reason = 'No reason given' end
        local nextWarns = warns + 1
        if nextWarns >= SunsetClans.MaxWarns then
            safeBroadcast(row.clan_id, source,
                ('removed %s from the clan after 3/3 warnings: %s'):format(playerName(targetCid), reason))
            MySQL.update.await('DELETE FROM clan_members WHERE clan_id = ? AND character_id = ?', {
                row.clan_id, targetCid,
            })
            if targetId then
                ClanDisplay.sync(targetId)
                notify(targetId, ('Clan warning 3/3 — removed from %s: %s'):format(row.name, reason), 'error', 10000)
            end
            safeAudit(row.clan_id, cid, 'warn_kick', { targetCharacterId = targetCid, reason = reason })
        else
            MySQL.update.await('UPDATE clan_members SET warns = ? WHERE clan_id = ? AND character_id = ?', {
                nextWarns, row.clan_id, targetCid,
            })
            if targetId then
                notify(targetId, ('Clan warning %d/3: %s'):format(nextWarns, reason), 'warning', 8000)
            end
            safeAudit(row.clan_id, cid, 'warn', { targetCharacterId = targetCid, reason = reason, warns = nextWarns })
            safeBroadcast(row.clan_id, source,
                ('issued a clan warning (%d/3) to %s: %s'):format(nextWarns, playerName(targetCid), reason))
        end
        notify(source, ('Warning issued (%d/3): %s'):format(math.min(nextWarns, SunsetClans.MaxWarns), reason), 'success')
        syncClanMembers(row.clan_id)
        return clanManageDashboard(source, cid)
    end

    if action == 'rankLabels' then
        if not row or not isLeader(row, cid) then return nil, 'Only the clan leader can rename ranks.' end
        local labels = SunsetClans.defaultRankLabels()
        if type(payload.labels) == 'table' then
            for i = 1, SunsetClans.MaxRank do
                local label = payload.labels[tostring(i)] or payload.labels[i]
                if type(label) == 'string' and label:gsub('%s+', '') ~= '' then
                    labels[i] = label:sub(1, 48)
                end
            end
        end
        MySQL.update.await('UPDATE clans SET rank_labels = ? WHERE id = ?', {
            SunsetClans.encodeRankLabels(labels), row.clan_id,
        })
        safeAudit(row.clan_id, cid, 'rank_labels', { labels = labels })
        safeBroadcast(row.clan_id, source, 'updated clan rank names.')
        safeSyncMembers(row.clan_id)
        return clanManageDashboard(source, cid)
    end

    if action == 'leave' then
        if not row then return nil, 'You are not in a clan.' end
        if isLeader(row, cid) then
            return nil, 'Leaders must dissolve the clan or transfer leadership before leaving.'
        end
        local clanId = row.clan_id
        safeAudit(clanId, cid, 'leave', {})
        safeBroadcast(clanId, source, 'left the clan.')
        MySQL.update.await('DELETE FROM clan_members WHERE clan_id = ? AND character_id = ?', { clanId, cid })
        ClanDisplay.sync(source)
        print(('^2[sunset_clans]^7 leave ok src=%s cid=%s clan=%s'):format(tostring(source), tostring(cid), tostring(clanId)))
        return dashboardPayload(source, nil, cid)
    end

    if action == 'dissolve' then
        if not row or not isLeader(row, cid) then return nil, 'Only the clan leader can dissolve the clan.' end
        local clanId = row.clan_id
        local members = MySQL.query.await('SELECT character_id FROM clan_members WHERE clan_id = ?', { clanId }) or {}
        safeAudit(clanId, cid, 'dissolve', {})
        safeBroadcast(clanId, source, 'dissolved the clan.')
        -- [AUDIT P6-12] End active turf wars and release turf ownership BEFORE the
        -- clan row disappears (turfs.owner_clan_id has no FK; a dangling id left
        -- the turf unattackable-as-neutral while payouts silently stopped).
        TriggerEvent('sunset:clans:dissolved', clanId)
        MySQL.update.await('DELETE FROM clans WHERE id = ?', { clanId })
        for _, member in ipairs(members) do
            local src = sourceForChar(member.character_id)
            if src then ClanDisplay.sync(src) end
        end
        ClanDisplay.sync(source)
        print(('^2[sunset_clans]^7 dissolve ok src=%s cid=%s clan=%s members=%d'):format(
            tostring(source), tostring(cid), tostring(clanId), #members))
        return dashboardPayload(source, nil, cid)
    end

    return nil, 'Unknown clan action.'
end

exports.sunset_core:RegisterCallback('sunset:clanManage', function(source, payload)
    local res, err = handleClanManage(source, payload)
    if not res and err then
        local action = type(payload) == 'table' and payload.action or 'unknown'
        print(('^3[sunset_clans]^7 clanManage [%s] failed for src %s: %s'):format(tostring(action), tostring(source), tostring(err)))
    end
    return res, err
end)

local function acceptInvite(source)
    local cid = charId(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    if ClanDisplay.getMembership(cid) then return nil, 'You are already in a clan.' end

    local invite = normalizeInvite(PendingInvites[source])
    if not invite then
        invite = normalizeInvite(MySQL.single.await([[
            SELECT ci.clan_id, ci.expires_at, c.name, c.tag
            FROM clan_invites ci
            INNER JOIN clans c ON c.id = ci.clan_id
            WHERE ci.character_id = ?
            ORDER BY ci.expires_at DESC
            LIMIT 1
        ]], { cid }))
    end
    if not invite then return nil, 'You have no pending clan invites.' end
    if invite.expires_at and invite.expires_at < os.time() then
        MySQL.update.await('DELETE FROM clan_invites WHERE clan_id = ? AND character_id = ?', { invite.clan_id, cid })
        PendingInvites[source] = nil
        return nil, 'That clan invite expired.'
    end

    local count = clanMemberCount(invite.clan_id)
    local maxMembers = tonumber(MySQL.scalar.await('SELECT max_members FROM clans WHERE id = ?', { invite.clan_id })) or SunsetClans.MaxMembers
    if count >= maxMembers then
        return nil, 'That clan is full.'
    end

    local insertOk, insertErr = pcall(function()
        MySQL.insert.await('INSERT INTO clan_members (clan_id, character_id, rank) VALUES (?, ?, ?)', {
            invite.clan_id, cid, 1,
        })
    end)
    if not insertOk then
        print(('[sunset_clans] acceptInvite insert failed for %s: %s'):format(source, tostring(insertErr)))
        return nil, 'Could not join the clan. Ask the leader to invite you again.'
    end
    MySQL.update.await('DELETE FROM clan_invites WHERE clan_id = ? AND character_id = ?', { invite.clan_id, cid })
    PendingInvites[source] = nil
    ClanDisplay.sync(source)
    safeAudit(invite.clan_id, cid, 'join', {})
    safeBroadcast(invite.clan_id, source, 'joined the clan.')
    return clanManageDashboard(source, cid)
end

exports.sunset_core:RegisterCallback('sunset:clanAcceptInvite', function(source)
    return acceptInvite(source)
end)

exports.sunset_core:RegisterCallback('sunset:clanDeclineInvite', function(source)
    local cid = charId(source)
    if not cid then return nil, 'Your character is not loaded. Reconnect and try again.' end
    local pending = PendingInvites[source]
    local clanId = pending and pending.clanId
    if pending then
        MySQL.update.await('DELETE FROM clan_invites WHERE clan_id = ? AND character_id = ?', { pending.clanId, cid })
        PendingInvites[source] = nil
    else
        local row = MySQL.single.await(
            'SELECT clan_id FROM clan_invites WHERE character_id = ? ORDER BY expires_at DESC LIMIT 1',
            { cid }
        )
        clanId = row and tonumber(row.clan_id)
        MySQL.update.await('DELETE FROM clan_invites WHERE character_id = ?', { cid })
    end
    if clanId then
        safeBroadcast(clanId, source, 'declined the clan invitation.')
    end
    return true
end)

function RunMotdCommand(source, args)
    if source == 0 then return true end
    args = args or {}
    local msg = table.concat(args, ' ')
    if msg == '' then
        local ok, err = showClanMotd(source)
        if not ok then
            TriggerClientEvent('sunset:client:notify', source, err or 'Clan MOTD could not be loaded.', 'error', 6000)
        end
        return true
    end
    local dashboard, err = applyClanMotd(source, msg)
    if dashboard then
        TriggerClientEvent('sunset:client:notify', source, 'Clan MOTD updated.', 'success', 6000)
    else
        TriggerClientEvent('sunset:client:notify', source, err or 'MOTD update failed. Officers can set it with /cmotd [message].', 'error', 7000)
    end
    return true
end
exports('RunMotdCommand', RunMotdCommand)

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
