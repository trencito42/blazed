local Suggestions = {}

-- [ADMIN FILTER] Commands requiring admin levels (from SunsetAdmin.Commands,
-- loaded via @sunset_admin/shared/config.lua in our manifest) plus extra
-- admin-gated commands registered elsewhere. Players below the required level
-- never SEE these in the suggestion list (server-side checks still enforce).
local ExtraAdminCommands = {
    spy = 3, sweeporphans = 3, blzresmon = 3, gototurf = 2, forceturf = 3,
    stopwar = 2, resetturfcd = 2, turflist = 1, cinematic = 3, inspect = 3,
    clothingdebug = 3, robdebug = 3, validateoutfit = 3, ecudebug = 2,
    testall = 5, smoketest = 5, sessiontest = 5, integrity = 5, testradaralert = 5,
    abusiness = 3, abiz = 3, bizadmin = 3,
}

local myAdminLevel = 0

local function adminLevelFor(cmdName)
    local name = tostring(cmdName or ''):lower():gsub('^/', '')
    local fromAdminCfg = SunsetAdmin and SunsetAdmin.Commands and SunsetAdmin.Commands[name]
    if fromAdminCfg then return tonumber(fromAdminCfg) or 0 end
    return ExtraAdminCommands[name]
end

RegisterNetEvent('sunset:client:setAdmin', function(level)
    myAdminLevel = tonumber(level) or 0
    -- Re-push so admin suggestions appear/disappear immediately.
    SetTimeout(50, function()
        TriggerEvent('sunset:chat:rebuildSuggestions')
    end)
end)

local function normalizeCommand(name)
    name = tostring(name or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return '' end
    if name:sub(1, 1) ~= '/' then name = '/' .. name end
    return name
end

local function normalizeParams(params)
    local out = {}
    if type(params) ~= 'table' then return out end
    for i, row in ipairs(params) do
        if type(row) == 'table' then
            out[i] = {
                name = tostring(row.name or row.param or ''),
                help = tostring(row.help or ''),
            }
        elseif type(row) == 'string' then
            out[i] = { name = row, help = '' }
        end
    end
    return out
end

local function sortedList()
    local list = {}
    for _, row in pairs(Suggestions) do
        -- [ADMIN FILTER] hide admin-gated commands from players below the level.
        local need = adminLevelFor(row.name)
        if not need or myAdminLevel >= need then
            list[#list + 1] = row
        end
    end
    table.sort(list, function(a, b)
        return (a.name or '') < (b.name or '')
    end)
    return list
end

local function pushToUi()
    exports.sunset_ui:Send('chatSuggestions', {
        suggestions = sortedList(),
    })
end

local function addSuggestion(name, help, params)
    local key = normalizeCommand(name)
    if key == '' then return end
    Suggestions[key] = {
        name = key,
        help = tostring(help or ''),
        params = normalizeParams(params),
    }
end

local function removeSuggestion(name)
    local key = normalizeCommand(name)
    if key == '' then return end
    Suggestions[key] = nil
end

local function bootstrapCommandUsage()
    if not Sunset or not Sunset.CommandUsage then return end
    for cmd, def in pairs(Sunset.CommandUsage) do
        local usage = def.usage or ('/' .. cmd)
        local params = {}
        for token in usage:gmatch('%[([^%]]+)%]') do
            params[#params + 1] = { name = token, help = '' }
        end
        addSuggestion('/' .. cmd, usage, params)
    end
end

AddEventHandler('chat:addSuggestion', function(name, help, params)
    addSuggestion(name, help, params)
    pushToUi()
end)

RegisterNetEvent('chat:addSuggestion', function(name, help, params)
    addSuggestion(name, help, params)
    pushToUi()
end)

AddEventHandler('chat:removeSuggestion', function(name)
    removeSuggestion(name)
    pushToUi()
end)

RegisterNetEvent('chat:removeSuggestion', function(name)
    removeSuggestion(name)
    pushToUi()
end)

AddEventHandler('chat:addSuggestions', function(rows)
    if type(rows) ~= 'table' then return end
    for _, row in ipairs(rows) do
        if type(row) == 'table' then
            addSuggestion(row.name, row.help, row.params)
        end
    end
    pushToUi()
end)

AddEventHandler('chat:removeSuggestions', function(rows)
    if type(rows) ~= 'table' then return end
    for _, name in ipairs(rows) do
        removeSuggestion(name)
    end
    pushToUi()
end)

AddEventHandler('chat:clearSuggestions', function()
    Suggestions = {}
    pushToUi()
end)

AddEventHandler('sunset:chat:rebuildSuggestions', function()
    bootstrapCommandUsage()
    pushToUi()
end)

exports('GetChatSuggestions', function()
    return sortedList()
end)

exports('SyncChatSuggestions', function()
    pushToUi()
end)

CreateThread(function()
    Wait(250)
    bootstrapCommandUsage()
    Wait(5000)
    TriggerEvent('sunset:chat:rebuildSuggestions')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    if not resourceName:match('^sunset_') then return end
    SetTimeout(1000, function()
        TriggerEvent('sunset:chat:rebuildSuggestions')
    end)
end)
