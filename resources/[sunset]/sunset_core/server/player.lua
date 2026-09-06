local function decodeChar(char)
    if not char then return nil end
    if type(char.position) == 'string' then char.position = json.decode(char.position) end
    if type(char.appearance) == 'string' then char.appearance = json.decode(char.appearance) end
    if type(char.metadata) == 'string' then char.metadata = json.decode(char.metadata or '{}') end
    char.hunger = tonumber(char.hunger) or 100
    char.thirst = tonumber(char.thirst) or 100
    char.stress = tonumber(char.stress) or 0
    char.level = tonumber(char.level) or 1
    char.xp = tonumber(char.xp) or 0
    char.respect_points = tonumber(char.respect_points) or 0
    char.paydays_received = tonumber(char.paydays_received) or 0
    char = Sunset.MigrateCharacterProfile(char)
    return char
end

function Sunset.SaveCharacter(source)
    local player = Sunset.GetPlayer(source)
    if not player or not player.character then return false end

    local char = player.character
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    -- Instanced interiors reuse remote world coordinates. Persist their exterior
    -- safe position so "Last Location" can never strand a player underground.
    local safe = Player(source) and Player(source).state.sunsetPropertyExit
    if type(safe) == 'table' and tonumber(safe.x) then
        coords = vector3(safe.x, safe.y, safe.z)
        heading = tonumber(safe.w) or heading
    end
    local position = json.encode({ x = coords.x, y = coords.y, z = coords.z, w = heading })

    MySQL.update.await([[
        UPDATE characters SET
            cash = ?, bank = ?, job = ?, job_grade = ?,
            position = ?, appearance = ?, metadata = ?,
            hunger = ?, thirst = ?, stress = ?, level = ?, xp = ?, respect_points = ?, paydays_received = ?,
            is_dead = ?, home_property_id = ?, last_played = NOW()
        WHERE id = ? AND player_id = ?
    ]], {
        char.cash or 0,
        char.bank or 0,
        char.job or 'unemployed',
        char.job_grade or 0,
        position,
        json.encode(char.appearance or {}),
        json.encode(char.metadata or {}),
        char.hunger or 100,
        char.thirst or 100,
        char.stress or 0,
        char.level or 1,
        char.xp or 0,
        char.respect_points or 0,
        char.paydays_received or 0,
        char.is_dead and 1 or 0,
        char.home_property_id,
        char.id,
        player.id,
    })

    return true
end

local PersistentStatFields = {
    character = {
        cash = true, bank = true, level = true, xp = true,
        respect_points = true, paydays_received = true,
        hunger = true, thirst = true, stress = true,
    },
    player = { playtime = true },
    account = { premium_points = true },
}

function Sunset.SetPersistentStat(source, scope, field, value)
    local player = Sunset.GetPlayer(source)
    local char = player and player.character
    local allowed = PersistentStatFields[scope]
    if not player or not char then return false, 'Character data is unavailable.' end
    if not allowed or not allowed[field] then return false, 'That persistent field is not allowed.' end
    value = math.floor(tonumber(value) or -1)
    if value < 0 then return false, 'The value must be zero or greater.' end

    local tableName, rowId, cache
    if scope == 'character' then
        tableName, rowId, cache = 'characters', char.id, char
    elseif scope == 'player' then
        tableName, rowId, cache = 'players', player.id, player
    else
        tableName, rowId, cache = 'accounts', player.account_id, player
    end

    local changed = MySQL.update.await(('UPDATE %s SET %s = ? WHERE id = ?'):format(tableName, field), { value, rowId })
    if changed == nil then return false, 'The database rejected the update.' end
    cache[field] = value
    if scope == 'player' and field == 'playtime' then player.sessionStart = os.time() end

    if scope == 'character' then
        TriggerClientEvent('sunset:client:updateCharacter', source, char)
        if field == 'cash' or field == 'bank' then
            TriggerClientEvent('sunset:client:updateMoney', source, char.cash or 0, char.bank or 0)
        end
    end
    return true
end

function Sunset.SetHomeProperty(source, propertyId)
    local char = Sunset.GetCharacter(source)
    if not char then return false end
    propertyId = propertyId and tonumber(propertyId) or nil
    local changed = MySQL.update.await('UPDATE characters SET home_property_id = ? WHERE id = ?', { propertyId, char.id })
    if changed == nil then return false end
    char.home_property_id = propertyId
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function Sunset.AddMoney(source, account, amount, reason)
    local char = Sunset.GetCharacter(source)
    amount = math.floor(tonumber(amount) or 0)
    if not char or amount <= 0 then return false end

    local field
    if account == 'cash' then
        field = 'cash'
    elseif account == 'bank' then
        field = 'bank'
    else
        return false
    end

    local changed = MySQL.update.await(('UPDATE characters SET %s = %s + ? WHERE id = ?'):format(field, field), { amount, char.id })
    if not changed or changed < 1 then return false end
    char[field] = (tonumber(char[field]) or 0) + amount

    TriggerClientEvent('sunset:client:updateMoney', source, char.cash, char.bank)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function Sunset.RemoveMoney(source, account, amount, reason)
    local char = Sunset.GetCharacter(source)
    amount = math.floor(tonumber(amount) or 0)
    if not char or amount <= 0 then return false end

    local field
    if account == 'cash' then
        if (char.cash or 0) < amount then return false end
        field = 'cash'
    elseif account == 'bank' then
        if (char.bank or 0) < amount then return false end
        field = 'bank'
    else
        return false
    end

    local changed = MySQL.update.await(
        ('UPDATE characters SET %s = %s - ? WHERE id = ? AND %s >= ?'):format(field, field, field),
        { amount, char.id, amount }
    )
    if not changed or changed < 1 then return false end
    char[field] = (tonumber(char[field]) or 0) - amount

    TriggerClientEvent('sunset:client:updateMoney', source, char.cash, char.bank)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function Sunset.GetMoney(source, account)
    local char = Sunset.GetCharacter(source)
    if not char then return 0 end
    return account == 'bank' and (char.bank or 0) or (char.cash or 0)
end

function Sunset.SetJob(source, job, grade)
    local char = Sunset.GetCharacter(source)
    if not char then return false end
    if Sunset.Factions[job] then return false end
    if not (Sunset.CivilianJobs and Sunset.CivilianJobs[job]) then return false end

    grade = tonumber(grade) or 0
    if not Sunset.CivilianJobs[job].grades[grade] then return false end

    char.job = job
    char.job_grade = grade
    MySQL.update.await(
        'UPDATE characters SET job = ?, job_grade = ? WHERE id = ?',
        { char.job, char.job_grade, char.id }
    )
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    TriggerEvent('sunset:server:jobChanged', source, job, grade or 0)
    return true
end

function Sunset.SetFaction(source, factionId, grade)
    local char = Sunset.GetCharacter(source)
    if not char then return false end

    char.metadata = char.metadata or {}
    if not factionId or factionId == 'none' then
        char.metadata.faction = nil
        char.metadata.faction_grade = nil
    else
        if not Sunset.Factions[factionId] then return false end
        grade = tonumber(grade) or 0
        if not Sunset.Factions[factionId].grades[grade] then return false end
        char.metadata.faction = factionId
        char.metadata.faction_grade = grade
        if Sunset.Factions[char.job] then
            char.job = 'unemployed'
            char.job_grade = 0
        end
    end

    MySQL.update.await(
        'UPDATE characters SET job = ?, job_grade = ?, metadata = ? WHERE id = ?',
        { char.job or 'unemployed', char.job_grade or 0, json.encode(char.metadata), char.id }
    )
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    TriggerEvent('sunset:server:factionChanged', source, factionId, grade or 0)
    return true
end

function Sunset.AddXP(source, amount)
    local char = Sunset.GetCharacter(source)
    if not char or not amount or amount <= 0 then return false end

    char.xp = (char.xp or 0) + amount
    local xpMax = math.max(5000, (char.level or 1) * 5000)
    while char.xp >= xpMax do
        char.xp = char.xp - xpMax
        char.level = (char.level or 1) + 1
        xpMax = math.max(5000, char.level * 5000)
        TriggerClientEvent('sunset:client:notify', source, ('Level up! You are now level %d'):format(char.level), 'success', 6000)
    end

    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function Sunset.AddRespectPoints(source, amount)
    local char = Sunset.GetCharacter(source)
    amount = math.floor(tonumber(amount) or 0)
    if not char or amount <= 0 then return false end
    char.respect_points = (tonumber(char.respect_points) or 0) + amount
    char.paydays_received = (tonumber(char.paydays_received) or 0) + 1
    MySQL.update.await('UPDATE characters SET respect_points=?, paydays_received=? WHERE id=?', {
        char.respect_points, char.paydays_received, char.id
    })
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

RegisterCommand('buylevel', function(source)
    if source == 0 then return end
    local char = Sunset.GetCharacter(source)
    if not char then return end
    local rpCost = Sunset.GetLevelRespectCost(char.level)
    local moneyCost = Sunset.GetLevelMoneyCost(char.level)
    if (char.respect_points or 0) < rpCost then
        return TriggerClientEvent('sunset:client:notify', source,
            ('Level %d requires %d RP; you have %d. You earn 1 RP at every payday.'):format((char.level or 1) + 1, rpCost, char.respect_points or 0), 'error', 7000)
    end
    local account
    if Sunset.GetMoney(source, 'bank') >= moneyCost then account = 'bank'
    elseif Sunset.GetMoney(source, 'cash') >= moneyCost then account = 'cash' end
    if not account then
        return TriggerClientEvent('sunset:client:notify', source,
            ('Level %d costs $%d. Keep the full amount in bank or cash.'):format((char.level or 1) + 1, moneyCost), 'error', 7000)
    end
    if not Sunset.RemoveMoney(source, account, moneyCost, 'buy_level') then return end
    char.respect_points = char.respect_points - rpCost
    char.level = (char.level or 1) + 1
    MySQL.update.await('UPDATE characters SET level=?, respect_points=?, cash=?, bank=? WHERE id=?', {
        char.level, char.respect_points, char.cash or 0, char.bank or 0, char.id
    })
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    TriggerClientEvent('sunset:client:notify', source,
        ('Level purchased! You are now level %d. Paid %d RP and $%d; %d RP remain.'):format(char.level, rpCost, moneyCost, char.respect_points), 'success', 9000)
end, false)

function Sunset.GetSpawnPosition(char)
    if char.home_property_id then
        local prop = MySQL.single.await('SELECT entry FROM properties WHERE id = ? AND owner_character_id = ?', {
            char.home_property_id, char.id
        })
        if prop and prop.entry then
            local entry = json.decode(prop.entry)
            if entry then return entry end
        end
    end
    local pos = char.position or {}
    if pos.x then return pos end
    local spawn = Sunset.Config.DefaultSpawn
    return { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }
end

Sunset.DecodeCharacter = decodeChar

exports('SaveCharacter', Sunset.SaveCharacter)
exports('AddMoney', Sunset.AddMoney)
exports('RemoveMoney', Sunset.RemoveMoney)
exports('GetMoney', Sunset.GetMoney)
exports('SetPersistentStat', Sunset.SetPersistentStat)
exports('SetHomeProperty', Sunset.SetHomeProperty)
exports('SetJob', Sunset.SetJob)
exports('SetFaction', Sunset.SetFaction)
exports('AddXP', Sunset.AddXP)
function Sunset.GetRobPoints(source)
    local char = Sunset.GetCharacter(source)
    if not char then return 0 end
    char.metadata = type(char.metadata) == 'table' and char.metadata or {}
    return math.max(0, math.floor(tonumber(char.metadata.rob_points) or 0))
end

function Sunset.SetRobPoints(source, value)
    local char = Sunset.GetCharacter(source)
    if not char then return false end
    value = math.max(0, math.floor(tonumber(value) or 0))
    char.metadata = type(char.metadata) == 'table' and char.metadata or {}
    char.metadata.rob_points = value
    MySQL.update.await('UPDATE characters SET metadata = ? WHERE id = ?', { json.encode(char.metadata), char.id })
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function Sunset.AddRobPoints(source, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return true end
    local nextValue = Sunset.GetRobPoints(source) + amount
    if nextValue < 0 then return false end
    return Sunset.SetRobPoints(source, nextValue)
end

exports('AddRespectPoints', Sunset.AddRespectPoints)
exports('GetRobPoints', Sunset.GetRobPoints)
exports('SetRobPoints', Sunset.SetRobPoints)
exports('AddRobPoints', Sunset.AddRobPoints)
exports('GetSpawnPosition', Sunset.GetSpawnPosition)
