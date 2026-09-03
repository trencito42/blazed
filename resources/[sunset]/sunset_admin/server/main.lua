local Admins = {}

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

function loadAdmin(source)
    local license = getLicense(source)
    if not license then return end

    local level = 0
    local row = MySQL.single.await('SELECT level FROM admins WHERE license = ?', { license })
    if row then level = row.level end

    local player = exports.sunset_core:GetPlayer(source)
    if player and player.account_id then
        local account = MySQL.single.await('SELECT admin_level FROM accounts WHERE id = ?', { player.account_id })
        if account and tonumber(account.admin_level) then
            level = math.max(level, tonumber(account.admin_level))
        end
    elseif player and player.admin_level then
        level = math.max(level, player.admin_level)
    end

    if level > 0 then
        Admins[license] = level
        TriggerClientEvent('sunset:client:setAdmin', source, level)
        print(('^2[SunsetAdmin]^7 %s loaded as level %d'):format(GetPlayerName(source), level))
    end
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Verificăm contul...')

    local license = getLicense(src)
    if not license then
        deferrals.done()
        return
    end

    local ban = MySQL.single.await(
        'SELECT * FROM bans WHERE license = ? AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY id DESC LIMIT 1',
        { license }
    )

    if ban then
        deferrals.done('Ești banat: ' .. ban.reason)
        return
    end

    deferrals.done()
end)

RegisterNetEvent('sunset:server:playerLoaded', function()
    loadAdmin(source)
end)

function SetAdmin(license, level, name, grantedBy)
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
        if getLicense(tonumber(id)) == license then
            TriggerClientEvent('sunset:client:setAdmin', tonumber(id), level or 0)
        end
    end
end
exports('SetAdmin', SetAdmin)

-- First-time owner setup via console: sunset_setowner [player id]
RegisterCommand('sunset_setowner', function(src, args)
    if src ~= 0 then return end
    local target = tonumber(args[1])
    if not target then print('Usage: sunset_setowner [player id]') return end

    local license = getLicense(target)
    if not license then print('No license found') return end

    SetAdmin(license, 5, GetPlayerName(target), 'console')
    print(('Owner set for %s (%s)'):format(GetPlayerName(target), license))
end, true)
