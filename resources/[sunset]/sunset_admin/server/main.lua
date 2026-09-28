local Admins = {}
local Helpers = {}

local function getLicense(source)
    return Sunset.GetIdentifier(source, 'license')
end

function IsAdmin(source, minLevel)
    minLevel = minLevel or 1
    local license = getLicense(source)
    if not license then return false end
    local level = Admins[license]
    return level and level >= minLevel
end
exports('IsAdmin', IsAdmin)

function GetAdminLevel(source)
    local license = getLicense(source)
    return license and Admins[license] or 0
end
exports('GetAdminLevel', GetAdminLevel)

function IsHelper(source, minLevel)
    minLevel = minLevel or 1
    local license = getLicense(source)
    if not license then return false end
    local hLevel = Helpers[license] or 0
    if hLevel >= minLevel then return true end
    -- Admins also satisfy helper permissions
    local aLevel = Admins[license] or 0
    return aLevel >= 1
end
exports('IsHelper', IsHelper)

function GetHelperLevel(source)
    local license = getLicense(source)
    return license and Helpers[license] or 0
end
exports('GetHelperLevel', GetHelperLevel)

function IsStaff(source)
    return IsAdmin(source, 1) or IsHelper(source, 1)
end
exports('IsStaff', IsStaff)

function loadAdmin(source)
    local license = getLicense(source)
    if not license then return end

    local level = 0
    local hLevel = 0

    -- Query admins and helpers tables
    local adminRow = MySQL.single.await('SELECT level FROM admins WHERE license = ?', { license })
    if adminRow and adminRow.level then level = tonumber(adminRow.level) or 0 end

    local helperRow = MySQL.single.await('SELECT level FROM helpers WHERE license = ?', { license })
    if helperRow and helperRow.level then hLevel = tonumber(helperRow.level) or 0 end

    -- Query accounts table
    local player = exports.sunset_core:GetPlayer(source)
    if player and player.account_id then
        local account = MySQL.single.await('SELECT admin_level, helper_level FROM accounts WHERE id = ?', { player.account_id })
        if account then
            if tonumber(account.admin_level) then level = math.max(level, tonumber(account.admin_level)) end
            if tonumber(account.helper_level) then hLevel = math.max(hLevel, tonumber(account.helper_level)) end
        end
    elseif player then
        if player.admin_level then level = math.max(level, tonumber(player.admin_level) or 0) end
        if player.helper_level then hLevel = math.max(hLevel, tonumber(player.helper_level) or 0) end
    end

    if level > 0 then
        Admins[license] = level
    else
        Admins[license] = nil
    end

    if hLevel > 0 then
        Helpers[license] = hLevel
    else
        Helpers[license] = nil
    end

    Player(source).state.adminLevel = level
    Player(source).state.helperLevel = hLevel

    TriggerClientEvent('sunset:client:setAdmin', source, level)
    TriggerClientEvent('sunset:client:setHelper', source, hLevel)
    TriggerClientEvent('sunset:client:setStaff', source, { admin = level, helper = hLevel })

    if level > 0 or hLevel > 0 then
        print(('^2[SunsetAdmin]^7 %s (src %s) loaded as Admin: %d | Helper: %d'):format(GetPlayerName(source) or license, tostring(source), level, hLevel))
    end
end
exports('RefreshAdmin', loadAdmin)
exports('RefreshStaff', loadAdmin)

local function getPlayerIP(src)
    local endpoint = GetPlayerEndpoint(src)
    if endpoint then
        local ip = endpoint:match('^([^:]+)')
        if ip and ip ~= '' then return ip end
    end
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, 3) == 'ip:' then
            return id:sub(4)
        end
    end
    return nil
end
exports('GetPlayerIP', getPlayerIP)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Checking account...')

    local license = getLicense(src)
    local ip = getPlayerIP(src)
    if not license then
        deferrals.done()
        return
    end

    local ban = MySQL.single.await(
        'SELECT * FROM bans WHERE (license = ? OR (ip IS NOT NULL AND ip != \'\' AND ip = ?)) AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY id DESC LIMIT 1',
        { license, ip or '' }
    )

    if ban then
        deferrals.done('You are banned: ' .. (ban.reason or 'Banned from server'))
        return
    end

    -- [BAN HARDENING] Also check hardware tokens: a banned player switching
    -- to a fresh license on the same PC still trips this (sql/47 ban_tokens).
    local tokenBan
    pcall(function()
        for i = 0, 4 do
            local token = GetPlayerToken(src, i)
            if token and token ~= '' then
                tokenBan = MySQL.single.await([[
                    SELECT b.reason FROM ban_tokens bt
                    JOIN bans b ON b.id = bt.ban_id
                    WHERE bt.token = ? AND (b.expires_at IS NULL OR b.expires_at > NOW())
                    LIMIT 1
                ]], { token })
                if tokenBan then break end
            end
        end
    end)
    if tokenBan then
        deferrals.done('You are banned: ' .. (tokenBan.reason or 'No reason given'))
        return
    end

    deferrals.done()
end)

RegisterNetEvent('sunset:server:playerLoaded', function()
    loadAdmin(source)
end)

AddEventHandler('sunset:server:playerReady', function(src)
    loadAdmin(src)
end)

AddEventHandler('sunset:server:authenticated', function(src)
    loadAdmin(src)
end)

RegisterNetEvent('sunset:server:characterSpawned', function()
    loadAdmin(source)
end)

function SetAdmin(license, level, name, grantedBy)
    level = tonumber(level) or 0
    if level > 0 then
        MySQL.insert.await(
            'INSERT INTO admins (license, level, name, granted_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE level = ?, name = ?',
            { license, level, name, grantedBy, level, name }
        )
        Admins[license] = level
    else
        MySQL.update.await('DELETE FROM admins WHERE license = ?', { license })
        Admins[license] = nil
    end

    for _, id in ipairs(GetPlayers()) do
        local pid = tonumber(id)
        if getLicense(pid) == license then
            local p = exports.sunset_core:GetPlayer(pid)
            if p and p.account_id then
                MySQL.update.await('UPDATE accounts SET admin_level = ? WHERE id = ?', { level, p.account_id })
                p.admin_level = level
            end
            TriggerClientEvent('sunset:client:setAdmin', pid, level or 0)
            TriggerClientEvent('sunset:client:setStaff', pid, { admin = level or 0, helper = Helpers[license] or 0 })
        end
    end
end
exports('SetAdmin', SetAdmin)

function SetHelper(license, level, name, grantedBy)
    level = tonumber(level) or 0
    if level > 0 then
        MySQL.insert.await(
            'INSERT INTO helpers (license, level, name, granted_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE level = ?, name = ?',
            { license, level, name, grantedBy, level, name }
        )
        Helpers[license] = level
    else
        MySQL.update.await('DELETE FROM helpers WHERE license = ?', { license })
        Helpers[license] = nil
    end

    for _, id in ipairs(GetPlayers()) do
        local pid = tonumber(id)
        if getLicense(pid) == license then
            local p = exports.sunset_core:GetPlayer(pid)
            if p and p.account_id then
                MySQL.update.await('UPDATE accounts SET helper_level = ? WHERE id = ?', { level, p.account_id })
                p.helper_level = level
            end
            TriggerClientEvent('sunset:client:setHelper', pid, level or 0)
            TriggerClientEvent('sunset:client:setStaff', pid, { admin = Admins[license] or 0, helper = level or 0 })
        end
    end
end
exports('SetHelper', SetHelper)

-- First-time owner setup via console: sunset_setowner [player id]
RegisterCommand('sunset_setowner', function(src, args)
    if src ~= 0 then return end
    local target = tonumber(args[1])
    if not target then print('Usage: sunset_setowner [player id]') return end

    local license = getLicense(target)
    if not license then print('No license found') return end

    SetAdmin(license, 6, GetPlayerName(target), 'console')
    print(('Owner (Admin 6) set for %s (%s)'):format(GetPlayerName(target), license))
end, true)
