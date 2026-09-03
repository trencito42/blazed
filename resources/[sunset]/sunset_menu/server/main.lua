local LOGIN_MONTHS = {
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
}

local function parseLoginTimestamp(ts)
    if ts == nil then return nil end

    if type(ts) == 'number' then
        local sec = math.floor(ts)
        -- oxmysql typeCast returns Unix time in milliseconds
        if sec > 9999999999 then
            sec = math.floor(sec / 1000)
        end
        return sec > 0 and sec or nil
    end

    if type(ts) == 'table' and ts.year and ts.month and ts.day then
        return os.time({
            year = ts.year,
            month = ts.month,
            day = ts.day,
            hour = ts.hour or 0,
            min = ts.min or 0,
            sec = ts.sec or 0,
        })
    end

    if type(ts) == 'string' and ts ~= '' then
        local y, mo, d, h, mi, s = ts:match('^(%d+)-(%d+)-(%d+)[ T](%d+):(%d+):?(%d*)')
        if y then
            return os.time({
                year = tonumber(y),
                month = tonumber(mo),
                day = tonumber(d),
                hour = tonumber(h),
                min = tonumber(mi),
                sec = tonumber(s) or 0,
            })
        end
        local n = tonumber(ts)
        if n then return parseLoginTimestamp(n) end
    end

    return nil
end

local function formatLogin(ts)
    local sec = parseLoginTimestamp(ts)
    if not sec then return '—' end
    local t = os.date('*t', sec)
    if not t then return '—' end
    local mon = LOGIN_MONTHS[t.month] or '???'
    return ('%s %d, %d — %02d:%02d'):format(mon, t.day, t.year, t.hour, t.min)
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
