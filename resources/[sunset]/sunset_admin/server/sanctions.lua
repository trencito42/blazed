-- ═══════════════════════════════════════════════════════════════
--  ADMIN SANCTIONS — warn / history / clearwarns / temp-ban +
--  public broadcasts (ADMIN_SYSTEM_SPEC.md §3).
--  Domain: sunset_admin owns admin_sanctions (sql/47).
-- ═══════════════════════════════════════════════════════════════

local Sanctions = {}

local function adminName(source)
    if source == 0 then return 'CONSOLE' end
    return GetPlayerName(source) or ('ID %d'):format(source)
end

local function targetIdentity(target)
    local char = exports.sunset_core:GetCharacter(target)
    local player = exports.sunset_core:GetPlayer(target)
    return {
        accountId = player and tonumber(player.account_id) or nil,
        characterId = char and tonumber(char.id) or nil,
        name = exports.sunset_core:GetPlayerDisplayName(target) or GetPlayerName(target) or '?',
        license = Sunset.GetIdentifier(target, 'license'),
    }
end

local function adminAccountId(source)
    if source == 0 then return nil end
    local player = exports.sunset_core:GetPlayer(source)
    return player and tonumber(player.account_id) or nil
end

-- ── Broadcast plumbing (§3.5) ──────────────────────────────────
local LastBroadcastAt = 0
local RecentBroadcasts = {} -- sliding window for the 5/min cap

local function broadcastPublic(text)
    local cfg = SunsetAdmin.Broadcast or {}
    local now = os.time()
    if cfg.cooldownSec and (now - LastBroadcastAt) < cfg.cooldownSec then return end
    -- cap 5 broadcasts/min (anti raid-flood); the rest still goes to staff+DB.
    for i = #RecentBroadcasts, 1, -1 do
        if now - RecentBroadcasts[i] > 60 then table.remove(RecentBroadcasts, i) end
    end
    if #RecentBroadcasts >= 5 then return end
    RecentBroadcasts[#RecentBroadcasts + 1] = now
    LastBroadcastAt = now
    TriggerClientEvent('sunset:chat:message', -1, {
        id = 0, name = 'SANCTION', message = text, type = 'admin_action',
    })
end

local function broadcastStaff(text)
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if src and IsAdmin(src, 1) then
            TriggerClientEvent('sunset:chat:system', src, text, 'warning')
        end
    end
end

-- ── Sanction recording ─────────────────────────────────────────
function Sanctions.record(action, target, adminSource, reason, durationMin)
    local id = targetIdentity(target)
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO admin_sanctions
                (action, target_account_id, target_character_id, target_name, target_license,
                 admin_account_id, admin_name, reason, duration_min)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            action, id.accountId, id.characterId, id.name, id.license,
            adminAccountId(adminSource), adminName(adminSource),
            tostring(reason or ''):sub(1, 255), durationMin and math.floor(durationMin) or nil,
        })
    end)
    if not ok then print(('[sanctions] record failed (%s): %s'):format(action, tostring(err))) end
    return id
end

local function recentWarnCount(license)
    if not license then return 0 end
    return tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM admin_sanctions
        WHERE action = 'warn' AND target_license = ?
          AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]], { license })) or 0
end

-- ── /warn ──────────────────────────────────────────────────────
function Sanctions.warn(source, target, reason)
    reason = tostring(reason or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #reason < 3 then return nil, 'Reason is mandatory (min 3 characters): /warn [id] [reason]' end

    -- helpers cannot warn staff of equal/higher level
    if source ~= 0 and IsAdmin(target, 1) then
        local myLevel = tonumber(GetAdminLevel(source)) or 0
        local theirLevel = tonumber(GetAdminLevel(target)) or 0
        if theirLevel >= myLevel then
            return nil, 'You cannot warn a staff member of your level or higher.'
        end
    end

    local id = Sanctions.record('warn', target, source, reason)
    local aName = adminName(source)

    TriggerClientEvent('sunset:client:notify', target,
        ('WARNING from %s: %s'):format(aName, reason), 'error', 12000)
    TriggerClientEvent('sunset:chat:system', target, ('You received a warning from %s: %s'):format(aName, reason), 'error')

    if (SunsetAdmin.Broadcast or {}).warn ~= false then
        broadcastPublic(('Warning issued to %s by %s: %s'):format(id.name, aName, reason))
    end

    local prior = recentWarnCount(id.license)
    broadcastStaff(('[SANCTION] %s warned %s (#%d): "%s" — %d warn(s) in the last 7 days'):format(
        aName, id.name, target, reason, prior + 1))

    -- auto-escalation: 3rd warn in 7 days -> staff alert suggesting kick
    if prior + 1 >= (SunsetAdmin.WarnsBeforeStaffAlert or 3) then
        broadcastStaff(('[SANCTION] %s now has %d warns in 7 days — consider /kick or /ban. (/history %d)')
            :format(id.name, prior + 1, target))
    end
    return { warns = prior + 1, reason = reason }
end

-- ── /history ───────────────────────────────────────────────────
function Sanctions.history(source, target)
    local id = targetIdentity(target)
    local rows = MySQL.query.await([[
        SELECT action, admin_name, reason, duration_min, created_at
        FROM admin_sanctions
        WHERE target_license = ? OR (target_account_id IS NOT NULL AND target_account_id = ?)
        ORDER BY created_at DESC LIMIT 10
    ]], { id.license, id.accountId }) or {}

    local lines = {}
    lines[#lines + 1] = ('History for %s (#%d):'):format(id.name, target)
    if #rows == 0 then
        lines[#lines + 1] = '  (no sanctions on record)'
    else
        for _, row in ipairs(rows) do
            local dur = row.duration_min and (' (%d min)'):format(row.duration_min) or ''
            lines[#lines + 1] = ('  %s%s by %s: %s — %s'):format(
                string.upper(row.action), dur, row.admin_name or '?', row.reason or '', tostring(row.created_at))
        end
    end

    local activeBan = MySQL.single.await(
        'SELECT reason, banned_by, expires_at FROM bans WHERE license = ? AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY id DESC LIMIT 1',
        { id.license })
    if activeBan then
        lines[#lines + 1] = ('  ACTIVE BAN by %s: %s%s'):format(
            activeBan.banned_by or '?', activeBan.reason or '',
            activeBan.expires_at and (' (until ' .. tostring(activeBan.expires_at) .. ')') or ' (permanent)')
    end

    for _, line in ipairs(lines) do
        TriggerClientEvent('sunset:chat:system', source, line, 'info')
    end
    return true
end

-- ── /clearwarns ────────────────────────────────────────────────
function Sanctions.clearWarns(source, target)
    local id = targetIdentity(target)
    Sanctions.record('clearwarns', target, source, 'Warn history cleared by staff')
    broadcastStaff(('[SANCTION] %s cleared the warn history of %s'):format(adminName(source), id.name))
    return true
end

-- ── Kick/ban extensions ────────────────────────────────────────
function Sanctions.kick(source, target, reason)
    local id = Sanctions.record('kick', target, source, reason)
    local aName = adminName(source)
    DropPlayer(target, ('You were kicked by %s: %s'):format(aName, reason))
    if (SunsetAdmin.Broadcast or {}).kick ~= false then
        broadcastPublic(('%s was kicked by %s: %s'):format(id.name, aName, reason))
    end
    broadcastStaff(('[SANCTION] %s kicked %s (#%d, %s): "%s"'):format(aName, id.name, target, tostring(id.license), reason))
    return true
end

local DURATION_TOKENS = {
    ['30m'] = 30, ['1h'] = 60, ['6h'] = 360, ['12h'] = 720,
    ['1d'] = 1440, ['3d'] = 4320, ['7d'] = 10080, ['14d'] = 20160, ['30d'] = 43200,
}

-- Parse "/ban [id] [duration|perm] [reason]" with backward compatibility:
-- if arg2 is not a duration token, the whole rest is the reason (permanent).
function Sanctions.parseBanArgs(args)
    local durationMin = nil
    local reasonStart = 2
    local token = args[2] and string.lower(tostring(args[2]))
    if token == 'perm' then
        durationMin = nil
        reasonStart = 3
    elseif token and DURATION_TOKENS[token] then
        durationMin = DURATION_TOKENS[token]
        reasonStart = 3
    end
    local reason = table.concat(args, ' ', reasonStart)
    if reason == '' then reason = durationMin and ('Temp ban %d min'):format(durationMin) or 'Permanent ban' end
    return durationMin, reason
end

function Sanctions.ban(source, target, durationMin, reason)
    local id = Sanctions.record(durationMin and 'tempban' or 'ban', target, source, reason, durationMin)
    local aName = adminName(source)
    local license = id.license
    if not license then return nil, 'Could not resolve the target license.' end

    local expiresAt = durationMin and (os.date('%Y-%m-%d %H:%M:%S', os.time() + durationMin * 60)) or nil
    local banId = MySQL.insert.await(
        'INSERT INTO bans (license, reason, banned_by, expires_at) VALUES (?, ?, ?, ?)',
        { license, reason, aName, expiresAt })

    -- [BAN HARDENING] store hardware tokens so alt-account evasion via a new
    -- license still trips the connecting deferral (checked in main.lua).
    pcall(function()
        for i = 0, 4 do
            local token = GetPlayerToken(target, i)
            if token and token ~= '' then
                MySQL.insert.await('INSERT IGNORE INTO ban_tokens (ban_id, token) VALUES (?, ?)',
                    { banId, token })
            end
        end
    end)

    DropPlayer(target, ('Banned by %s: %s%s'):format(aName, reason,
        durationMin and (' (expires in %d min)'):format(durationMin) or ' (permanent)'))

    if (SunsetAdmin.Broadcast or {}).ban ~= false then
        local showReason = ((SunsetAdmin.Broadcast or {}).showReason or {}).ban ~= false
        local reasonPart = showReason and (': ' .. reason) or ''
        if durationMin then
            broadcastPublic(('%s was banned for %d minutes by %s%s'):format(id.name, durationMin, aName, reasonPart))
        else
            broadcastPublic(('%s was permanently banned by %s%s'):format(id.name, aName, reasonPart))
        end
    end
    broadcastStaff(('[SANCTION] %s banned %s (%s)%s: "%s"'):format(
        aName, id.name, tostring(license),
        durationMin and (' for ' .. durationMin .. ' min') or ' PERMANENTLY', reason))
    return true
end

function Sanctions.unbanRecord(source, license, targetName)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO admin_sanctions (action, target_name, target_license, admin_account_id, admin_name, reason)
            VALUES ('unban', ?, ?, ?, ?, 'Ban lifted')
        ]], { tostring(targetName or license), tostring(license), adminAccountId(source), adminName(source) })
    end)
    if (SunsetAdmin.Broadcast or {}).unban == true then
        broadcastPublic(('%s ban was lifted by %s'):format(tostring(targetName or license), adminName(source)))
    end
    broadcastStaff(('[SANCTION] %s unbanned %s'):format(adminName(source), tostring(license)))
end

-- ── Ajail broadcast helper ─────────────────────────────────────
function Sanctions.jail(source, target, minutes, reason)
    local id = Sanctions.record('jail', target, source, reason, minutes)
    local aName = adminName(source)
    if (SunsetAdmin.Broadcast or {}).jail ~= false then
        broadcastPublic(('%s was jailed for %d min by %s: %s'):format(id.name, minutes, aName, reason))
    end
    broadcastStaff(('[SANCTION] %s jailed %s (#%d) for %d min: "%s"'):format(aName, id.name, target, minutes, reason))
end

function Sanctions.unjail(source, target)
    local id = Sanctions.record('unjail', target, source, 'Released by staff')
    broadcastStaff(('[SANCTION] %s released %s from jail'):format(adminName(source), id.name))
end

-- Duration token map exposed for the /ban command handler.
Sanctions.DURATION_TOKENS = DURATION_TOKENS

SunsetAdmin.Sanctions = Sanctions
exports('RecordSanction', Sanctions.record)
exports('BroadcastStaff', broadcastStaff)
print('^2[sunset_admin]^7 sanctions module online (warn/history/clearwarns/broadcasts)')
