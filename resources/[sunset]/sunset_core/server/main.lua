local Players = {}
local Callbacks = {}
local Sessions = {}
local CallbackRate = {}
local FlowTraceRate = {}

RegisterNetEvent('sunset:server:flowTrace', function(stage, detail)
    local source = source
    if type(stage) ~= 'string' or #stage > 64 or type(detail) ~= 'string' or #detail > 160 then return end
    local now = GetGameTimer()
    local previous = FlowTraceRate[source] or 0
    if now - previous < 100 then return end
    FlowTraceRate[source] = now
    print(('[SunsetFlow:%d] %s%s'):format(source, stage, detail ~= '' and (' | ' .. detail) or ''))
end)

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
    if type(name) ~= 'string' or #name > 80 or type(requestId) ~= 'number' then return end
    local now = GetGameTimer()
    local rate = CallbackRate[source]
    if not rate or now - rate.window >= 1000 then
        rate = { window = now, count = 0 }
        CallbackRate[source] = rate
    end
    rate.count = rate.count + 1
    if rate.count > 30 then
        print(('^3[SunsetMP]^7 Callback flood blocked from %s'):format(source))
        TriggerClientEvent('sunset:client:callbackResponse', source, requestId, nil, 'Too many requests — wait a moment')
        return
    end
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
        TriggerClientEvent('sunset:client:callbackResponse', source, requestId, nil,
            ('Server error while processing %s. Try once more; if it repeats, report this action to staff.'):format(name))
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

local function completeAuthentication(source, accountId, username)
    local session = Sessions[source]
    if not session or session.authenticated then return false end

    accountId = tonumber(accountId)
    if not accountId or type(username) ~= 'string' or username == '' then return false end

    local account = MySQL.single.await(
        'SELECT id, username, premium_points, admin_level FROM accounts WHERE id = ?',
        { accountId }
    )
    if not account then return false end
    username = account.username

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
    return true
end

exports('CompleteAuthentication', completeAuthentication)

-- ═══ EXPORTS ═══

function GetPlayer(source) return Players[source] end
exports('GetPlayer', GetPlayer)

function GetCharacter(source)
    return Players[source] and Players[source].character or nil
end
exports('GetCharacter', GetCharacter)

function GetPlayerBaseName(source)
    local char = GetCharacter(source)
    local base
    if char then
        local full = ((char.firstname or '') .. (char.lastname and char.lastname ~= '' and (' ' .. char.lastname) or ''))
            :gsub('^%s+', ''):gsub('%s+$', '')
        if full ~= '' then base = full end
    end
    if not base then
        local player = Players[source]
        if player and player.name and player.name ~= '' then
            base = player.name
        else
            base = GetPlayerName(source) or 'Player'
        end
    end
    return base
end
exports('GetPlayerBaseName', GetPlayerBaseName)

function GetPlayerDisplayName(source)
    local base = GetPlayerBaseName(source)
    if GetResourceState('sunset_clans') == 'started' then
        local ok, formatted = pcall(function()
            return exports.sunset_clans:FormatDisplayName(source, base)
        end)
        if ok and type(formatted) == 'string' and formatted ~= '' then
            base = formatted
        end
    end
    local sid = tonumber(source)
    if not sid or sid <= 0 then return base end
    return ('%s (%d)'):format(base, sid)
end
exports('GetPlayerDisplayName', GetPlayerDisplayName)

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
        player.id, 1, accountName, '', '1990-01-01', 0, 'American',
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
    if char._profileMigrated then
        MySQL.update.await(
            'UPDATE characters SET job = ?, job_grade = ?, metadata = ? WHERE id = ?',
            { char.job or 'unemployed', char.job_grade or 0, json.encode(char.metadata or {}), charId }
        )
        char._profileMigrated = nil
    end
    char.last_played_before = char.last_played
    MySQL.update.await('UPDATE characters SET last_played = NOW() WHERE id = ?', { charId })
    Players[source].character = char
    Player(source).state:set('sunsetName', GetPlayerBaseName(source), true)
    Player(source).state:set('sunsetDisplayName', GetPlayerDisplayName(source), true)
    TriggerEvent('sunset:server:characterSelected', source, charId)
    return char
end

-- Character selection is performed by server callbacks. Never accept a complete
-- character object from a client: it contains money, job, faction and progression.
RegisterNetEvent('sunset:server:characterSpawned', function(characterId)
    local source = source
    local char = Players[source] and Players[source].character
    if not char or tonumber(characterId) ~= tonumber(char.id) then return end
    TriggerClientEvent('sunset:client:characterLoaded', source, char)
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
                    if player.character then
                        if player.character._profileMigrated then
                            Sunset.SaveCharacter(src)
                            player.character._profileMigrated = nil
                        end
                    end
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
    CallbackRate[source] = nil
end)

-- ═══ CHARACTER CALLBACKS ═══

RegisterCallback('sunset:getCharacters', function(source)
    local player = GetPlayer(source)
    if not player then return {} end

    local chars = MySQL.query.await(
        'SELECT id, slot, firstname, lastname, dateofbirth, gender, nationality, cash, bank, job, job_grade, position, appearance, last_played, hunger, thirst, stress, level, xp, respect_points, paydays_received, home_property_id FROM characters WHERE player_id = ? ORDER BY slot',
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
    local function validNamePart(value)
        value = type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
        if #value < 2 or #value > 24 or not value:match("^[%a][%a'%-]+$") then return nil end
        return value:sub(1, 1):upper() .. value:sub(2):lower()
    end
    data.firstname = validNamePart(data.firstname) or validNamePart(player.name) or 'Player'
    data.lastname = validNamePart(data.lastname) or ''
    data.dateofbirth = type(data.dateofbirth) == 'string' and data.dateofbirth or '1990-01-01'
    local year, month, day = data.dateofbirth:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year and (year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0)) then daysInMonth[2] = 29 end
    if not year or year < 1900 or year > tonumber(os.date('%Y')) - 16
        or month < 1 or month > 12 or day < 1 or day > daysInMonth[month] then
        return nil, 'Enter a valid date of birth; characters must be at least 16 years old'
    end
    data.gender = math.max(0, math.min(1, tonumber(data.gender) or 0))
    data.nationality = type(data.nationality) == 'string' and data.nationality:sub(1, 32) or 'American'
    if not data.nationality:match("^[%a%s'%-]+$") then
        return nil, 'Select a valid nationality'
    end

    local slot = count + 1
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
