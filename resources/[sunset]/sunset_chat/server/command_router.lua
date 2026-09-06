local serverCommands = {}

local function refreshServerCommands()
    serverCommands = {}
    for _, row in ipairs(GetRegisteredCommands()) do
        if row.name then
            serverCommands[string.lower(row.name)] = true
        end
    end
end

AddEventHandler('onResourceStart', function()
    SetTimeout(500, refreshServerCommands)
end)

CreateThread(function()
    Wait(2500)
    refreshServerCommands()
end)

local function countArgs(rest)
    if not rest or rest == '' then return 0 end
    local n = 0
    for _ in rest:gmatch('%S+') do
        n = n + 1
    end
    return n
end

local function chatSystem(source, message, kind)
    TriggerClientEvent('sunset:chat:system', source, message, kind or 'info')
end

local function getAdminLevel(source)
    local ok, level = pcall(function()
        return exports.sunset_admin:GetAdminLevel(source)
    end)
    return ok and tonumber(level) or 0
end

local function adminRequired(cmd)
    return SunsetAdmin and SunsetAdmin.Commands and SunsetAdmin.Commands[cmd]
end

local function commandExists(cmd)
    if serverCommands[cmd] then return true end
    if adminRequired(cmd) then return true end
    if Sunset.CommandUsage and Sunset.CommandUsage[cmd] then return true end
    if Sunset.ClientCommands and Sunset.ClientCommands[cmd] then return true end
    return false
end

local function parseArgs(rest)
    local args = {}
    if rest and rest ~= '' then
        for token in rest:gmatch('%S+') do
            args[#args + 1] = token
        end
    end
    return args
end

local function tryRunAdminCommand(src, cmd, rest)
    local args = parseArgs(rest)
    local ok, result = pcall(function()
        return exports.sunset_admin:ExecutePlayerCommand(src, cmd, args)
    end)
    if ok and result then return true end

    ok, result = pcall(function()
        return exports.sunset_vehicles:ExecutePlayerCommand(src, cmd, args)
    end)
    if ok and result then return true end

    ok, result = pcall(function()
        return exports.sunset_jobs:ExecutePlayerCommand(src, cmd, args)
    end)
    if ok and result then return true end

    ok, result = pcall(function()
        return exports.sunset_factions:ExecutePlayerCommand(src, cmd, args)
    end)
    if ok and result then return true end

    return false
end

RegisterNetEvent('sunset:chat:runCommand', function(line)
    local src = source
    if type(line) ~= 'string' then return end

    line = line:match('^%s*(.-)%s*$') or ''
    if line == '' then return end

    local cmd, rest = line:match('^(%S+)%s*(.*)$')
    cmd = cmd and string.lower(cmd) or ''
    if cmd == '' then return end

    if not commandExists(cmd) then
        chatSystem(src, ('Unknown command: /%s. Type /help for available commands.'):format(cmd), 'error')
        return
    end

    local need = adminRequired(cmd)
    if need then
        local level = getAdminLevel(src)
        if level < need then
            local label = (SunsetAdmin.Levels and SunsetAdmin.Levels[need]) or ('Level ' .. need)
            chatSystem(src, ('No access to /%s. Requires %s (admin level %d). Your level: %d.'):format(
                cmd, label, need, level
            ), 'error')
            return
        end
    end

    local usageDef = Sunset.CommandUsage and Sunset.CommandUsage[cmd]
    if usageDef then
        local minArgs = usageDef.minArgs or 0
        if countArgs(rest) < minArgs then
            chatSystem(src, usageDef.usage or ('Usage: /' .. cmd), 'error')
            return
        end
    end

    if adminRequired(cmd) then
        if tryRunAdminCommand(src, cmd, rest) then
            return
        end
        if Sunset.ClientAdminCommands and Sunset.ClientAdminCommands[cmd] then
            TriggerClientEvent('sunset:chat:executeCommand', src, line)
            return
        end
        if serverCommands[cmd] then
            local args = parseArgs(rest)
            local ok, err = pcall(function()
                if exports.sunset_factions:ExecutePlayerCommand(src, cmd, args) then
                    return
                end
                error('command handler returned false')
            end)
            if not ok then
                chatSystem(src,
                    ('/%s failed on the server: %s'):format(cmd, tostring(err)),
                    'error')
            end
            return
        end
        chatSystem(src,
            ('/%s is registered but has no handler on this server. Contact staff or reconnect.'):format(cmd),
            'error')
        return
    end

    TriggerClientEvent('sunset:chat:executeCommand', src, line)
end)

exports('RefreshCommandList', refreshServerCommands)
