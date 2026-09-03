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

    local ok, packed = pcall(function(...)
        local result, err = Callbacks[name](source, ...)
        return { result = result, err = err }
    end, ...)

    if not ok then
        print(('^1[SunsetMP]^7 Callback error (%s): %s'):format(name, tostring(packed)))
        TriggerClientEvent('sunset:client:callbackResponse', source, requestId, nil, tostring(packed))
        return
    end

    TriggerClientEvent('sunset:client:callbackResponse', source, requestId, packed.result, packed.err)
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

    local account = MySQL.single.await(
        'SELECT premium_points, admin_level FROM accounts WHERE id = ?',
        { accountId }
    )

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
        premium_points = account and tonumber(account.premium_points) or 0,
        admin_level = account and tonumber(account.admin_level) or 0,
        playtime = tonumber(player.playtime) or 0,
        sessionStart = os.time(),
        character = nil,
    }

    session.authenticated = true
    TriggerClientEvent('sunset:client:playerReady', source, {
        id = player.id,
        account_id = accountId,
        name = username,
        premium = account and tonumber(account.premium_points) or 0,
        playtime = tonumber(player.playtime) or 0,
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

function GetPlayerDisplayName(source)
    local player = Players[source]
    if player and player.name and player.name ~= '' then
        return player.name
    end
    local char = GetCharacter(source)
    if char then
        local full = (char.firstname or '') .. (char.lastname and char.lastname ~= '' and (' ' .. char.lastname) or '')
        if full ~= '' then return full end
    end
    return GetPlayerName(source) or 'Player'
end
exports('GetPlayerDisplayName', GetPlayerDisplayName)

local function syncCharacterAccountName(char, accountName)
    if not char or not accountName or accountName == '' then return char end
    if char.firstname == accountName and (not char.lastname or char.lastname == '') then
        return char
    end
    MySQL.update.await('UPDATE characters SET firstname = ?, lastname = ? WHERE id = ?', {
        accountName, '', char.id
    })
    char.firstname = accountName
    char.lastname = ''
    return char
end

local function grantStarterItems(characterId)
    local starter = { { 'water', 2, 1 }, { 'bread', 2, 2 }, { 'id_card', 1, 3 }, { 'phone', 1, 4 } }
    for _, row in ipairs(starter) do
        MySQL.insert.await('INSERT INTO character_inventory (character_id, item, count, slot) VALUES (?, ?, ?, ?)', {
            characterId, row[1], row[2], row[3]
        })
    end
end

local function createDefaultAccountCharacter(player)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE player_id = ?', { player.id })
    if count >= Sunset.Config.MaxCharacters then
        return nil, 'Character limit reached'
    end

    local spawn = Sunset.Config.DefaultSpawn
    local accountName = player.name or 'Player'
    local charId = MySQL.insert.await([[
        INSERT INTO characters (player_id, slot, firstname, lastname, dateofbirth, gender, nationality, cash, bank, position, appearance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.id, 1, accountName, '', '1990-01-01', 0, 'Romanian',
        Sunset.Config.StartingCash, Sunset.Config.StartingBank,
        json.encode({ x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }),
        json.encode({}),
    })

    grantStarterItems(charId)
    local char = MySQL.single.await('SELECT * FROM characters WHERE id = ?', { charId })
    return Sunset.DecodeCharacter(char)
end

local function loadCharacterForPlayer(source, player, charId)
    local char = MySQL.single.await('SELECT * FROM characters WHERE id = ? AND player_id = ?', { charId, player.id })
    if not char then return nil end

    char = Sunset.DecodeCharacter(char)
    char = syncCharacterAccountName(char, player.name)
    char.last_played_before = char.last_played
    MySQL.update.await('UPDATE characters SET last_played = NOW() WHERE id = ?', { charId })
    Players[source].character = char
    TriggerEvent('sunset:server:characterSelected', source, charId)
    return char
end

RegisterNetEvent('sunset:server:setCharacter', function(charData)
    local source = source
    if not Players[source] then return end
    charData = Sunset.DecodeCharacter(charData)
    Players[source].character = charData
    TriggerClientEvent('sunset:client:characterLoaded', source, charData)
end)

AddEventHandler('sunset:server:setActiveCharacter', function(source, charData)
    if not Players[source] or not charData then return end
    Players[source].character = Sunset.DecodeCharacter(charData)
end)

CreateThread(function()
    while true do
        Wait(300000) -- flush playtime every 5 minutes
        for src, player in pairs(Players) do
            if player.sessionStart then
                local mins = math.max(0, math.floor((os.time() - player.sessionStart) / 60))
                if mins > 0 then
                    MySQL.update.await('UPDATE players SET playtime = playtime + ? WHERE id = ?', { mins, player.id })
                    player.playtime = (tonumber(player.playtime) or 0) + mins
                    player.sessionStart = os.time()
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    local player = Players[source]
    if player and player.sessionStart then
        local mins = math.max(0, math.floor((os.time() - player.sessionStart) / 60))
        if mins > 0 then
            MySQL.update.await('UPDATE players SET playtime = playtime + ? WHERE id = ?', { mins, player.id })
        end
    end
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

    data = data or {}
    data.firstname = player.name
    data.lastname = ''
    data.dateofbirth = data.dateofbirth or '1990-01-01'
    data.gender = data.gender or 0
    data.nationality = data.nationality or 'Romanian'

    local slot = data.slot or (count + 1)
    local spawn = Sunset.Config.DefaultSpawn

    local charId = MySQL.insert.await([[
        INSERT INTO characters (player_id, slot, firstname, lastname, dateofbirth, gender, nationality, cash, bank, position, appearance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.id, slot, data.firstname, data.lastname, data.dateofbirth,
        data.gender, data.nationality,
        Sunset.Config.StartingCash, Sunset.Config.StartingBank,
        json.encode({ x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }),
        json.encode(data.appearance or {}),
    })

    grantStarterItems(charId)
    MySQL.insert.await('INSERT IGNORE INTO character_licenses (character_id, license_type) VALUES (?, ?)', {
        charId, 'driver'
    })

    local char = MySQL.single.await('SELECT * FROM characters WHERE id = ?', { charId })
    return Sunset.DecodeCharacter(char)
end)

RegisterCallback('sunset:selectCharacter', function(source, charId)
    local player = GetPlayer(source)
    if not player then return nil, 'Not logged in' end
    return loadCharacterForPlayer(source, player, charId)
end)

RegisterCallback('sunset:enterGame', function(source)
    local player = GetPlayer(source)
    if not player then return nil, 'Not logged in' end

    local row = MySQL.single.await(
        'SELECT id FROM characters WHERE player_id = ? ORDER BY slot LIMIT 1',
        { player.id }
    )

    if row then
        local char = loadCharacterForPlayer(source, player, row.id)
        if char then return { character = char } end
    end

    local char, err = createDefaultAccountCharacter(player)
    if not char then return nil, err or 'Could not create character' end

    char = loadCharacterForPlayer(source, player, char.id)
    return { character = char }
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
