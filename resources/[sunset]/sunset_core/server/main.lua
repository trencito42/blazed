local Players = {}
local Callbacks = {}
local Sessions = {}

Sunset.GetPlayer = function(source) return Players[source] end
Sunset.GetCharacter = function(source)
    local p = Players[source]
    return p and p.character or nil
end

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

-- ═══ SESSION ═══

local function getLicense(source)
    return Sunset.GetIdentifier(source, 'license')
end

RegisterNetEvent('sunset:server:playerLoaded', function()
    local source = source
    local license = getLicense(source)
    if not license then
        DropPlayer(source, 'Could not verify your game license.')
        return
    end

    Sessions[source] = { license = license, authenticated = false }
    TriggerClientEvent('sunset:client:sessionReady', source, { license = license })
    Sunset.Debug('Session ready:', source)
end)

RegisterNetEvent('sunset:server:authSuccess', function(accountId, username)
    local source = source
    local session = Sessions[source]
    if not session then return end

    local license = session.license
    local player = MySQL.single.await('SELECT * FROM players WHERE account_id = ?', { accountId })

    if not player then
        player = MySQL.single.await('SELECT * FROM players WHERE license = ?', { license })
        if player then
            MySQL.update.await('UPDATE players SET account_id = ? WHERE id = ?', { accountId, player.id })
            player.account_id = accountId
        end
    end

    if not player then
        local insertId = MySQL.insert.await(
            'INSERT INTO players (account_id, license, steam, discord, name) VALUES (?, ?, ?, ?, ?)',
            {
                accountId,
                license,
                Sunset.GetIdentifier(source, 'steam'),
                Sunset.GetIdentifier(source, 'discord'),
                username,
            }
        )
        player = MySQL.single.await('SELECT * FROM players WHERE id = ?', { insertId })
    else
        MySQL.update.await('UPDATE players SET license = ?, name = ?, last_seen = NOW() WHERE id = ?', {
            license, username, player.id
        })
    end

    Players[source] = {
        source = source,
        id = player.id,
        account_id = accountId,
        license = license,
        name = username,
        character = nil,
    }

    session.authenticated = true
    TriggerClientEvent('sunset:client:playerReady', source, {
        id = player.id,
        account_id = accountId,
        name = username,
    })
    Sunset.Debug('Player authenticated:', source, username)
end)

-- ═══ EXPORTS ═══

function GetPlayer(source) return Players[source] end
exports('GetPlayer', GetPlayer)

function GetCharacter(source)
    return Players[source] and Players[source].character or nil
end
exports('GetCharacter', GetCharacter)

RegisterNetEvent('sunset:server:setCharacter', function(charData)
    local source = source
    if not Players[source] then return end
    charData = Sunset.DecodeCharacter(charData)
    Players[source].character = charData
    TriggerClientEvent('sunset:client:characterLoaded', source, charData)
end)

AddEventHandler('playerDropped', function()
    local source = source
    if Players[source] and Players[source].character then
        Sunset.SaveCharacter(source)
    end
    Players[source] = nil
    Sessions[source] = nil
end)

-- ═══ CHARACTER CALLBACKS ═══

RegisterCallback('sunset:getCharacters', function(source)
    local player = GetPlayer(source)
    if not player then return {} end

    local chars = MySQL.query.await(
        'SELECT id, slot, firstname, lastname, dateofbirth, gender, nationality, cash, bank, job, job_grade, position, appearance, last_played, hunger, thirst, stress, level, xp, home_property_id FROM characters WHERE player_id = ? ORDER BY slot',
        { player.id }
    )

    for i, char in ipairs(chars or {}) do
        chars[i] = Sunset.DecodeCharacter(char)
    end
    return chars or {}
end)

RegisterCallback('sunset:createCharacter', function(source, data)
    local player = GetPlayer(source)
    if not player then return nil, 'Not logged in' end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE player_id = ?', { player.id })
    if count >= Sunset.Config.MaxCharacters then
        return nil, 'Character limit reached (' .. Sunset.Config.MaxCharacters .. ')'
    end

    local slot = data.slot or (count + 1)
    local spawn = Sunset.Config.DefaultSpawn

    local charId = MySQL.insert.await([[
        INSERT INTO characters (player_id, slot, firstname, lastname, dateofbirth, gender, nationality, cash, bank, position, appearance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.id, slot, data.firstname, data.lastname, data.dateofbirth,
        data.gender or 0, data.nationality or 'Romanian',
        Sunset.Config.StartingCash, Sunset.Config.StartingBank,
        json.encode({ x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }),
        json.encode(data.appearance or {}),
    })

    -- Starter items
    local starter = { { 'water', 2, 1 }, { 'bread', 2, 2 }, { 'id_card', 1, 3 }, { 'phone', 1, 4 } }
    for _, row in ipairs(starter) do
        MySQL.insert.await('INSERT INTO character_inventory (character_id, item, count, slot) VALUES (?, ?, ?, ?)', {
            charId, row[1], row[2], row[3]
        })
    end

    local char = MySQL.single.await('SELECT * FROM characters WHERE id = ?', { charId })
    return Sunset.DecodeCharacter(char)
end)

RegisterCallback('sunset:selectCharacter', function(source, charId)
    local player = GetPlayer(source)
    if not player then return nil, 'Not logged in' end

    local char = MySQL.single.await('SELECT * FROM characters WHERE id = ? AND player_id = ?', { charId, player.id })
    if not char then return nil, 'Invalid character' end

    char = Sunset.DecodeCharacter(char)
    MySQL.update.await('UPDATE characters SET last_played = NOW() WHERE id = ?', { charId })
    Players[source].character = char
    return char
end)

RegisterCallback('sunset:deleteCharacter', function(source, charId)
    local player = GetPlayer(source)
    if not player then return false, 'Not logged in' end
    local affected = MySQL.update.await('DELETE FROM characters WHERE id = ? AND player_id = ?', { charId, player.id })
    return affected > 0
end)

CreateThread(function()
    MySQL.ready(function()
        print('^2[SunsetMP]^7 Core framework loaded — database connected.')
    end)
end)
