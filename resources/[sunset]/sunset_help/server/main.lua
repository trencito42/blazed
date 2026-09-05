local function getAdminLevel(source)
    local ok, level = pcall(function()
        return exports.sunset_admin:GetAdminLevel(source)
    end)
    return ok and tonumber(level) or 0
end

local function isOnDuty(source)
    local ok, state = pcall(function()
        return exports.sunset_factions:GetDutyState(source)
    end)
    return ok and state == true
end

local function isServiceProvider(source, callType)
    local ok, allowed = pcall(function()
        return exports.sunset_dispatch:IsProviderForType(source, callType)
    end)
    return ok and allowed == true
end

local function copyEntries(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
        out[#out + 1] = { cmd = row.cmd, desc = row.desc or '' }
    end
    return out
end

local function buildAdminCategory(source)
    local level = getAdminLevel(source)
    if level <= 0 then return nil end

    local label = SunsetAdmin and SunsetAdmin.Levels and SunsetAdmin.Levels[level]
        or ('Level ' .. level)
    local entries = {}
    local cmds = SunsetAdmin and SunsetAdmin.Commands or {}

    for cmd, need in pairs(cmds) do
        if level >= need then
            local desc = Sunset.HelpAdminDescriptions[cmd] or ('Admin command (level ' .. need .. '+)')
            entries[#entries + 1] = { cmd = '/' .. cmd, desc = desc }
        end
    end

    table.sort(entries, function(a, b) return a.cmd < b.cmd end)

    return {
        title = 'Admin (' .. label .. ')',
        entries = entries,
    }
end

local function buildJobCategory(char)
    local jobId = select(1, Sunset.GetCharacterJob(char))
    if not jobId or jobId == 'unemployed' then return nil end

    local def = Sunset.CivilianJobs and Sunset.CivilianJobs[jobId]
    local cfg = Sunset.GetJobConfig and Sunset.GetJobConfig(jobId)
    if not def then return nil end

    local entries = {
        { cmd = '/jobs', desc = 'Open jobs panel' },
        { cmd = '/work [cancel]', desc = 'Start shift or cancel current shift' },
        { cmd = '/jobhelp', desc = 'Quick help for this job' },
        { cmd = '/skills', desc = 'View job XP and levels' },
    }

    local helpText = cfg and cfg.help or def.description
    if helpText and helpText ~= '' then
        entries[#entries + 1] = { cmd = '—', desc = helpText }
    end

    return {
        title = 'Job (' .. (def.label or jobId) .. ')',
        entries = entries,
    }
end

local function buildFactionCategory(source, char)
    local factionId, grade = Sunset.GetCharacterFaction(char)
    if not factionId then return nil end

    local faction = Sunset.Factions[factionId]
    if not faction then return nil end

    local leader = false
    pcall(function() leader = exports.sunset_factions:IsFactionLeader(source) == true end)
    local entries = copyEntries(Sunset.GetFactionCommandsForGrade(factionId, grade, leader))

    if isOnDuty(source) then
        entries[#entries + 1] = { cmd = '/r [message]', desc = 'Faction radio (on-duty members)' }
        if Sunset.FactionTypeMatches(factionId, 'law_enforcement') then
            entries[#entries + 1] = { cmd = '/d [message]', desc = 'Law enforcement department radio' }
            entries[#entries + 1] = { cmd = '/backup', desc = 'Request LSPD backup' }
            entries[#entries + 1] = { cmd = '/cbackup', desc = 'Cancel backup request' }
        end
        if Sunset.IsLegalFaction and Sunset.IsLegalFaction(factionId) then
            entries[#entries + 1] = { cmd = '/gov [message]', desc = 'Government broadcast (legal factions)' }
        end
    end

    return {
        title = 'Faction (' .. (faction.label or factionId) .. ')',
        entries = entries,
    }
end

local function buildOnDutyCategory(source, char)
    if not isOnDuty(source) then return nil end

    local entries = {}
    local factionId = select(1, Sunset.GetCharacterFaction(char))
    local jobId = select(1, Sunset.GetCharacterJob(char))

    local providerTypes = {}
    for callType in pairs(Sunset.Dispatch.ServiceTypes or {}) do
        if callType ~= 'police_backup' and isServiceProvider(source, callType) then
            providerTypes[#providerTypes + 1] = callType
        end
    end

    if #providerTypes > 0 then
        for _, row in ipairs(Sunset.HelpDispatchEntries or {}) do
            entries[#entries + 1] = row
        end
    end

    if factionId == 'lsfd' or isServiceProvider(source, 'fire') then
        for _, row in ipairs(Sunset.HelpFireEntries or {}) do
            entries[#entries + 1] = row
        end
    end

    if jobId == 'mechanic' and not isServiceProvider(source, 'mechanic') then
        entries[#entries + 1] = { cmd = '/work', desc = 'Start mechanic roadside shift' }
    end

    if #entries == 0 then
        entries[#entries + 1] = { cmd = '/duty', desc = 'You are on duty — use faction commands above' }
    end

    return {
        title = 'On Duty',
        entries = entries,
    }
end

local function buildHelp(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character loaded' end

    local categories = {
        {
            title = 'General',
            entries = copyEntries(Sunset.HelpGeneralEntries),
        },
    }

    local factionCat = buildFactionCategory(source, char)
    if factionCat then categories[#categories + 1] = factionCat end

    local jobCat = buildJobCategory(char)
    if jobCat then categories[#categories + 1] = jobCat end

    local onDutyCat = buildOnDutyCategory(source, char)
    if onDutyCat then categories[#categories + 1] = onDutyCat end

    local adminCat = buildAdminCategory(source)
    if adminCat then categories[#categories + 1] = adminCat end

    return {
        categories = categories,
        adminLevel = getAdminLevel(source),
        onDuty = isOnDuty(source),
    }
end

exports.sunset_core:RegisterCallback('sunset:getHelp', function(source)
    return buildHelp(source)
end)

CreateThread(function()
    Wait(1000)
    TriggerClientEvent('chat:addSuggestion', -1, '/help', 'Open your personalized command guide')
end)
