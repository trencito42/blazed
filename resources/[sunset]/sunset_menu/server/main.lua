local function formatLogin(ts)
    if not ts then return '—' end
    if type(ts) == 'number' then
        return os.date('%d.%m.%Y %H:%M', ts)
    end
    if type(ts) == 'table' and ts.year then
        return ('%02d.%02d.%04d %02d:%02d'):format(ts.day, ts.month, ts.year, ts.hour or 0, ts.min or 0)
    end
    local s = tostring(ts)
    local y, mo, d, h, mi = s:match('(%d+)-(%d+)-(%d+)[ T](%d+):(%d+)')
    if y then return ('%s.%s.%s %s:%s'):format(d, mo, y, h, mi) end
    return s
end

local function getNextPaydayTime()
    local h = tonumber(os.date('%H'))
    local nextH = (h + 1) % 24
    return ('%02d:00'):format(nextH)
end

exports.sunset_core:RegisterCallback('sunset:getMenuData', function(source)
    local player = exports.sunset_core:GetPlayer(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not player or not char then return {} end

    local properties = 0
    pcall(function()
        properties = MySQL.scalar.await(
            'SELECT COUNT(*) FROM properties WHERE owner_character_id = ?',
            { char.id }
        ) or 0
    end)

    local home = nil
    pcall(function()
        if char.home_property_id then
            home = MySQL.single.await('SELECT label FROM properties WHERE id = ?', { char.home_property_id })
        end
    end)

    local jobId, jobGrade = Sunset.GetCharacterJob(char)
    local civilianJob = Sunset.CivilianJobs[jobId]
    local factionId, factionGrade = Sunset.GetCharacterFaction(char)
    local faction = factionId and Sunset.Factions[factionId]
    local factionGradeRow = factionId and Sunset.GetFactionGrade(factionId, factionGrade)
    local civilianGrade = civilianJob and civilianJob.grades[jobGrade or 0]

    local vehicles = {}
    pcall(function()
        vehicles = MySQL.query.await(
            'SELECT id, plate, model, stored, garage, fuel, engine, body FROM vehicles WHERE character_id = ? ORDER BY id',
            { char.id }
        ) or {}
    end)

    local onDuty = false
    pcall(function()
        onDuty = exports.sunset_factions:IsOnDuty(source) == true
    end)

    local sessionMin = 0
    if player.sessionStart then
        sessionMin = math.floor((os.time() - player.sessionStart) / 60)
    end
    local totalPlaytime = (tonumber(player.playtime) or 0) + sessionMin

    return {
        playtime = totalPlaytime,
        playtimeFormatted = ('%dH %dM'):format(math.floor(totalPlaytime / 60), totalPlaytime % 60),
        lastLogin = formatLogin(char.last_played_before or char.last_played),
        premium = player.premium_points or 0,
        nextPayday = getNextPaydayTime(),
        serverTime = os.date('%H:%M'),
        vehicleCount = vehicles and #vehicles or 0,
        vehicles = vehicles,
        propertyCount = properties,
        homeLabel = home and home.label or 'None',
        stress = char.stress or 0,
        hunger = char.hunger or 100,
        thirst = char.thirst or 100,
        level = char.level or 1,
        xp = char.xp or 0,
        jobId = jobId,
        jobLabel = civilianJob and civilianJob.label or (jobId == 'unemployed' and 'Unemployed' or jobId),
        jobGrade = jobGrade or 0,
        jobGradeLabel = civilianGrade and civilianGrade.label or '—',
        jobSalary = civilianGrade and civilianGrade.salary or 0,
        factionId = factionId,
        factionLabel = faction and faction.label or nil,
        factionGrade = factionGrade or 0,
        factionGradeLabel = factionGradeRow and factionGradeRow.label or nil,
        factionSalary = factionGradeRow and factionGradeRow.salary or 0,
        jobType = faction and faction.type or 'civilian',
        hasDuty = faction and faction.duty == true,
        onDuty = onDuty,
    }
end)
