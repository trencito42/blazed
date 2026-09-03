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
    return char
end

function Sunset.SaveCharacter(source)
    local player = Sunset.GetPlayer(source)
    if not player or not player.character then return false end

    local char = player.character
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local position = json.encode({ x = coords.x, y = coords.y, z = coords.z, w = heading })

    MySQL.update.await([[
        UPDATE characters SET
            cash = ?, bank = ?, job = ?, job_grade = ?,
            position = ?, appearance = ?, metadata = ?,
            hunger = ?, thirst = ?, stress = ?, level = ?, xp = ?,
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
        char.is_dead and 1 or 0,
        char.home_property_id,
        char.id,
        player.id,
    })

    return true
end

function Sunset.AddMoney(source, account, amount, reason)
    local char = Sunset.GetCharacter(source)
    if not char or amount <= 0 then return false end

    if account == 'cash' then
        char.cash = (char.cash or 0) + amount
    elseif account == 'bank' then
        char.bank = (char.bank or 0) + amount
    else
        return false
    end

    TriggerClientEvent('sunset:client:updateMoney', source, char.cash, char.bank)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function Sunset.RemoveMoney(source, account, amount, reason)
    local char = Sunset.GetCharacter(source)
    if not char or amount <= 0 then return false end

    if account == 'cash' then
        if (char.cash or 0) < amount then return false end
        char.cash = char.cash - amount
    elseif account == 'bank' then
        if (char.bank or 0) < amount then return false end
        char.bank = char.bank - amount
    else
        return false
    end

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
    if not char or not Sunset.Jobs[job] then return false end
    char.job = job
    char.job_grade = grade or 0
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

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
exports('SetJob', Sunset.SetJob)
exports('GetSpawnPosition', Sunset.GetSpawnPosition)
