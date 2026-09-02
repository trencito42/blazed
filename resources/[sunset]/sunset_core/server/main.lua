local Players = {}
local Callbacks = {}

-- ═══ CALLBACKS ═══

function RegisterCallback(name, cb)
    Callbacks[name] = cb
end
exports('RegisterCallback', RegisterCallback)

RegisterNetEvent('sunset:server:triggerCallback', function(name, requestId, ...)
    local source = source
    if not Callbacks[name] then
        TriggerClientEvent('sunset:client:callbackResponse', source, requestId, nil, 'Callback not found: ' .. name)
        return
    end
    local result, err = Callbacks[name](source, ...)
    TriggerClientEvent('sunset:client:callbackResponse', source, requestId, result, err)
end)

-- ═══ PLAYER LOADING ═══

local function loadOrCreatePlayer(source)
    local license = Sunset.GetIdentifier(source, 'license')
    if not license then return nil end

    local player = MySQL.single.await('SELECT * FROM players WHERE license = ?', { license })

    if not player then
        local insertId = MySQL.insert.await(
            'INSERT INTO players (license, steam, discord, name) VALUES (?, ?, ?, ?)',
            {
                license,
                Sunset.GetIdentifier(source, 'steam'),
                Sunset.GetIdentifier(source, 'discord'),
                Sunset.GetPlayerName(source),
            }
        )
        player = MySQL.single.await('SELECT * FROM players WHERE id = ?', { insertId })
        Sunset.Debug('Created new player:', license)
    else
        MySQL.update.await('UPDATE players SET name = ?, last_seen = NOW() WHERE id = ?', {
            Sunset.GetPlayerName(source),
            player.id,
        })
    end

    return player
end

RegisterNetEvent('sunset:server:playerLoaded', function()
    local source = source
    local playerData = loadOrCreatePlayer(source)
    if not playerData then
        DropPlayer(source, 'Nu s-a putut încărca contul tău. Reîncearcă.')
        return
    end

    Players[source] = {
        source = source,
        id = playerData.id,
        license = playerData.license,
        name = playerData.name,
        character = nil,
    }

    TriggerClientEvent('sunset:client:playerReady', source, {
        id = playerData.id,
        name = playerData.name,
    })

    Sunset.Debug('Player loaded:', source, playerData.name)
end)

-- ═══ CHARACTER ═══

function GetPlayer(source)
    return Players[source]
end
exports('GetPlayer', GetPlayer)

function GetCharacter(source)
    local player = Players[source]
    return player and player.character or nil
end
exports('GetCharacter', GetCharacter)

RegisterNetEvent('sunset:server:setCharacter', function(charData)
    local source = source
    if not Players[source] then return end
    Players[source].character = charData
    TriggerClientEvent('sunset:client:characterLoaded', source, charData)
end)

AddEventHandler('playerDropped', function()
    local source = source
    Players[source] = nil
end)

-- ═══ STARTUP ═══

CreateThread(function()
    MySQL.ready(function()
        print('^2[SunsetMP]^7 Core framework loaded — database connected.')
    end)
end)

RegisterCallback('sunset:getCharacters', function(source)
    local player = GetPlayer(source)
    if not player then return {} end

    local chars = MySQL.query.await(
        'SELECT id, slot, firstname, lastname, dateofbirth, gender, nationality, cash, bank, job, job_grade, position, appearance, last_played FROM characters WHERE player_id = ? ORDER BY slot',
        { player.id }
    )

    for _, char in ipairs(chars or {}) do
        char.position = json.decode(char.position)
        char.appearance = json.decode(char.appearance)
    end

    return chars or {}
end)

RegisterCallback('sunset:createCharacter', function(source, data)
    local player = GetPlayer(source)
    if not player then return nil, 'Player not loaded' end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE player_id = ?', { player.id })
    if count >= Sunset.Config.MaxCharacters then
        return nil, 'Ai atins limita de personaje (' .. Sunset.Config.MaxCharacters .. ')'
    end

    local slot = data.slot or (count + 1)
    local spawn = Sunset.Config.DefaultSpawn

    local charId = MySQL.insert.await([[
        INSERT INTO characters (player_id, slot, firstname, lastname, dateofbirth, gender, nationality, cash, bank, position, appearance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.id,
        slot,
        data.firstname,
        data.lastname,
        data.dateofbirth,
        data.gender or 0,
        data.nationality or 'Romanian',
        Sunset.Config.StartingCash,
        Sunset.Config.StartingBank,
        json.encode({ x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }),
        json.encode(data.appearance or {}),
    })

    local char = MySQL.single.await('SELECT * FROM characters WHERE id = ?', { charId })
    char.position = json.decode(char.position)
    char.appearance = json.decode(char.appearance)

    return char
end)

RegisterCallback('sunset:selectCharacter', function(source, charId)
    local player = GetPlayer(source)
    if not player then return nil, 'Player not loaded' end

    local char = MySQL.single.await(
        'SELECT * FROM characters WHERE id = ? AND player_id = ?',
        { charId, player.id }
    )

    if not char then return nil, 'Personaj invalid' end

    char.position = json.decode(char.position)
    char.appearance = json.decode(char.appearance)
    char.metadata = json.decode(char.metadata or '{}')

    MySQL.update.await('UPDATE characters SET last_played = NOW() WHERE id = ?', { charId })

    Players[source].character = char
    return char
end)

RegisterCallback('sunset:deleteCharacter', function(source, charId)
    local player = GetPlayer(source)
    if not player then return false, 'Player not loaded' end

    local affected = MySQL.update.await(
        'DELETE FROM characters WHERE id = ? AND player_id = ?',
        { charId, player.id }
    )

    return affected > 0
end)
