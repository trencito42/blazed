local Suggestions = {}

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
        list[#list + 1] = row
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
