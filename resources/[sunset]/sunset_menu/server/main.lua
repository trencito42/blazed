local function formatLogin(ts)
    if not ts then return '—' end
    if type(ts) == 'number' then
        return os.date('%d.%m.%Y %H:%M', ts)
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
    if not player or not char then return nil end

    local sessionMin = 0
    if player.sessionStart then
        sessionMin = math.floor((os.time() - player.sessionStart) / 60)
    end
    local totalPlaytime = (tonumber(player.playtime) or 0) + sessionMin

    local vehicles = MySQL.scalar.await(
        'SELECT COUNT(*) FROM vehicles WHERE character_id = ?',
        { char.id }
    ) or 0
    local properties = MySQL.scalar.await(
        'SELECT COUNT(*) FROM properties WHERE owner_character_id = ?',
        { char.id }
    ) or 0

    local home = nil
    if char.home_property_id then
        home = MySQL.single.await('SELECT label FROM properties WHERE id = ?', { char.home_property_id })
    end

    return {
        playtime = totalPlaytime,
        playtimeFormatted = ('%dH %dM'):format(math.floor(totalPlaytime / 60), totalPlaytime % 60),
        lastLogin = formatLogin(char.last_played_before or char.last_played),
        nextPayday = getNextPaydayTime(),
        serverTime = os.date('%H:%M'),
        vehicleCount = vehicles,
        propertyCount = properties,
        homeLabel = home and home.label or 'None',
        stress = char.stress or 0,
        hunger = char.hunger or 100,
        thirst = char.thirst or 100,
        level = char.level or 1,
        xp = char.xp or 0,
    }
end)
