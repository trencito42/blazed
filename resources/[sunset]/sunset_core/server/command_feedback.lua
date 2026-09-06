Sunset = Sunset or {}

local function push(source, message, kind)
    if not message or message == '' then return end
    if not source or source == 0 then
        print(('[Command] %s'):format(message))
        return
    end
    TriggerClientEvent('sunset:client:notify', source, message, kind or 'info')
    if kind == 'error' or kind == 'warning' or kind == 'success' then
        TriggerClientEvent('sunset:chat:system', source, message, kind == 'success' and 'info' or kind)
    end
end

function Sunset.CommandReply(source, message, kind)
    push(source, message, kind)
end

function Sunset.CommandDenyAdmin(source, cmd)
    local need = 99
    local label = 'Admin'
    if SunsetAdmin and SunsetAdmin.Commands then
        need = SunsetAdmin.Commands[cmd] or 99
        label = (SunsetAdmin.Levels and SunsetAdmin.Levels[need]) or ('Level ' .. need)
    end
    local level = 0
    local ok, lvl = pcall(function()
        return exports.sunset_admin:GetAdminLevel(source)
    end)
    if ok then level = tonumber(lvl) or 0 end
    push(source, ('/%s requires %s (admin level %d). Your level: %d.'):format(
        tostring(cmd or 'command'), label, need, level
    ), 'error')
end

function Sunset.CommandDenyHeal(source)
    push(source,
        '/heal requires Admin level 2+, or on-duty EMS/LSFD with heal permission at your faction HQ.',
        'error')
end

function Sunset.CommandDenyRevive(source)
    push(source,
        '/revive requires Admin level 2+, or on-duty EMS with revive permission at Pillbox.',
        'error')
end

function Sunset.OnlinePlayerIds()
    local ids = {}
    for _, id in ipairs(GetPlayers()) do
        ids[#ids + 1] = tonumber(id)
    end
    table.sort(ids)
    return ids
end

function Sunset.CommandPlayerNotFound(source, idArg)
    local ids = Sunset.OnlinePlayerIds()
    local hint = #ids > 0
        and (' Players online: ' .. table.concat(ids, ', ') .. '.')
        or ' Nobody is online right now.'
    push(source, ('No online player matches "%s".%s'):format(tostring(idArg or '?'), hint), 'error')
end

function Sunset.CommandNoCharacter(source, targetId)
    push(source,
        ('Player #%d is connected but has not loaded a character yet.'):format(tonumber(targetId) or 0),
        'error')
end

function Sunset.CommandUsage(source, usage)
    push(source, usage, 'error')
end

function Sunset.CommandListKeys(map, limit)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    if limit and #keys > limit then
        local short = {}
        for i = 1, limit do short[i] = keys[i] end
        return table.concat(short, ', ') .. ', ...'
    end
    return table.concat(keys, ', ')
end

exports('CommandReply', Sunset.CommandReply)
exports('CommandDenyAdmin', Sunset.CommandDenyAdmin)
exports('CommandDenyHeal', Sunset.CommandDenyHeal)
exports('CommandDenyRevive', Sunset.CommandDenyRevive)
exports('CommandPlayerNotFound', Sunset.CommandPlayerNotFound)
exports('CommandNoCharacter', Sunset.CommandNoCharacter)
exports('CommandUsage', Sunset.CommandUsage)
exports('OnlinePlayerIds', Sunset.OnlinePlayerIds)
exports('CommandListKeys', Sunset.CommandListKeys)
