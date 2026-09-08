CreateThread(function()
    Wait(500)
    pcall(function()
        MySQL.query.await([[
            ALTER TABLE `characters`
                ADD COLUMN IF NOT EXISTS `phone_number` VARCHAR(32) NULL AFTER `nationality`;
        ]])
    end)
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `phone_contacts` (
                `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
                `character_id` INT UNSIGNED NOT NULL,
                `contact_name` VARCHAR(64) NOT NULL,
                `phone_number` VARCHAR(32) NOT NULL,
                `contact_character_id` INT UNSIGNED DEFAULT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `unique_char_contact_phone` (`character_id`, `phone_number`),
                KEY `idx_phone_contacts_char` (`character_id`),
                KEY `idx_phone_contacts_phone` (`phone_number`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])
    end)
    -- Populate any existing characters missing phone numbers
    pcall(function()
        MySQL.query.await([[
            UPDATE `characters`
            SET `phone_number` = CONCAT('555-', LPAD(id, 4, '0'))
            WHERE `phone_number` IS NULL OR `phone_number` = '';
        ]])
    end)
end)

local function formatPhone(raw)
    if not raw then return nil end
    local str = tostring(raw):gsub('%s+', '')
    if str:match('^%d%d%d%-%d%d%d%d$') then
        return str
    end
    local digits = str:gsub('%D', '')
    if #digits == 7 and digits:sub(1, 3) == '555' then
        return ('555-%s'):format(digits:sub(4))
    elseif #digits > 0 and #digits <= 4 then
        return ('555-%04d'):format(tonumber(digits) or 0)
    elseif #digits > 4 then
        return str
    end
    return str
end

local function getCharacterPhoneNumber(char)
    if not char then return '555-0000' end
    if char.phone_number and tostring(char.phone_number) ~= '' then
        return char.phone_number
    end
    if char.metadata and type(char.metadata) == 'table' and char.metadata.phone then
        return char.metadata.phone
    end
    local derived = ('555-%04d'):format(tonumber(char.id) or 0)
    char.phone_number = derived
    CreateThread(function()
        pcall(function()
            MySQL.update.await('UPDATE characters SET phone_number = ? WHERE id = ?', { derived, char.id })
        end)
    end)
    return derived
end

local function findCharacterByPhone(phoneQuery)
    if not phoneQuery or phoneQuery == '' then return nil end
    local normalized = formatPhone(phoneQuery)
    local rawDigits = tostring(phoneQuery):gsub('%D', '')

    -- 1. Exact match on characters.phone_number
    local row = MySQL.single.await([[
        SELECT id, firstname, lastname, phone_number
        FROM characters
        WHERE phone_number = ? OR phone_number = ? LIMIT 1
    ]], { phoneQuery, normalized })

    if row then return row end

    -- 2. If it's 555-XXXX or matches numeric ID
    local charId = tonumber(normalized:match('^555%-(%d+)$')) or tonumber(rawDigits)
    if charId and charId > 0 then
        local byId = MySQL.single.await([[
            SELECT id, firstname, lastname, phone_number
            FROM characters
            WHERE id = ? LIMIT 1
        ]], { charId })
        if byId then return byId end
    end

    return nil
end

local function findSourceByCharacterId(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = exports.sunset_core:GetCharacter(src)
        if c and tonumber(c.id) == characterId then
            return src
        end
    end
    return nil
end

exports.sunset_core:RegisterCallback('sunset:getPhoneData', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character loaded' end

    local myCharId = tonumber(char.id)
    local myPhone = getCharacterPhoneNumber(char)

    local messages = {}
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT m.id, m.message, m.created_at, m.sender_character_id, m.receiver_character_id,
                   sc.firstname AS sender_name, rc.firstname AS receiver_name
            FROM phone_messages m
            LEFT JOIN characters sc ON sc.id = m.sender_character_id
            LEFT JOIN characters rc ON rc.id = m.receiver_character_id
            WHERE m.sender_character_id = ? OR m.receiver_character_id = ?
            ORDER BY m.id DESC LIMIT 60
        ]], { myCharId, myCharId })
    end)
    if ok and rows then
        messages = rows
    end

    local onlineByChar = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            local c = exports.sunset_core:GetCharacter(src)
            local cid = c and tonumber(c.id)
            if cid then
                onlineByChar[cid] = src
            end
        end
    end

    -- Load personal saved contacts
    local contacts = {}
    local contactRows = MySQL.query.await([[
        SELECT id, contact_name, phone_number, contact_character_id, created_at
        FROM phone_contacts
        WHERE character_id = ?
        ORDER BY contact_name ASC
    ]], { myCharId }) or {}

    for _, cRow in ipairs(contactRows) do
        local targetCid = tonumber(cRow.contact_character_id)
        local isOnline = false
        local targetServerId = nil

        if targetCid and onlineByChar[targetCid] then
            isOnline = true
            targetServerId = onlineByChar[targetCid]
        end

        contacts[#contacts + 1] = {
            id = cRow.id,
            name = cRow.contact_name,
            phone = cRow.phone_number,
            characterId = targetCid,
            online = isOnline,
            serverId = targetServerId,
        }
    end

    return {
        myId = source,
        myCharacterId = myCharId,
        myName = exports.sunset_core:GetPlayerDisplayName(source),
        myPhoneNumber = myPhone,
        cash = char.cash or 0,
        bank = char.bank or 0,
        messages = messages,
        contacts = contacts,
        onlineByChar = onlineByChar,
    }
end)

exports.sunset_core:RegisterCallback('sunset:phoneAddContact', function(source, name, rawPhone)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character loaded' end

    rawPhone = tostring(rawPhone or ''):gsub('^%s*(.-)%s*$', '%1')
    name = tostring(name or ''):gsub('^%s*(.-)%s*$', '%1')

    if rawPhone == '' then
        return nil, 'Please enter a valid phone number.'
    end

    local myPhone = getCharacterPhoneNumber(char)
    local formatted = formatPhone(rawPhone)

    if formatted == myPhone or formatted == tostring(char.id) then
        return nil, 'You cannot add your own phone number.'
    end

    -- Resolve character if exists
    local matchedChar = findCharacterByPhone(rawPhone)
    local contactCharId = matchedChar and tonumber(matchedChar.id) or nil

    if not name or name == '' then
        if matchedChar then
            name = (matchedChar.firstname or '') .. ' ' .. (matchedChar.lastname or '')
        else
            name = 'Contact ' .. formatted
        end
    end

    if #name > 48 then
        name = name:sub(1, 48)
    end

    local ok, insertId = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO phone_contacts (character_id, contact_name, phone_number, contact_character_id)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                contact_name = VALUES(contact_name),
                contact_character_id = VALUES(contact_character_id)
        ]], { tonumber(char.id), name, formatted, contactCharId })
    end)

    if not ok then
        return nil, 'Database error while saving contact.'
    end

    local isOnline = (contactCharId and findSourceByCharacterId(contactCharId) ~= nil) or false

    return {
        ok = true,
        contact = {
            id = insertId,
            name = name,
            phone = formatted,
            characterId = contactCharId,
            online = isOnline,
        }
    }
end)

exports.sunset_core:RegisterCallback('sunset:phoneDeleteContact', function(source, contactId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character loaded' end

    contactId = tonumber(contactId)
    if not contactId then return nil, 'Invalid contact ID' end

    local affected = MySQL.update.await([[
        DELETE FROM phone_contacts
        WHERE id = ? AND character_id = ?
    ]], { contactId, tonumber(char.id) })

    if not affected or affected < 1 then
        return nil, 'Contact not found or already deleted.'
    end

    return { ok = true }
end)

exports.sunset_core:RegisterCallback('sunset:phoneSend', function(source, targetCharacterId, message, targetPhoneNumber)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    targetCharacterId = tonumber(targetCharacterId)
    if (not targetCharacterId or targetCharacterId == 0) and targetPhoneNumber then
        local resolved = findCharacterByPhone(targetPhoneNumber)
        if resolved then
            targetCharacterId = tonumber(resolved.id)
        end
    end

    message = tostring(message or ''):sub(1, 256)
    if not targetCharacterId or message == '' then return nil, 'Invalid recipient or message' end

    -- Handle 112 Emergency dispatch messaging
    if targetCharacterId == -112 or tostring(targetPhoneNumber) == '112' then
        pcall(function()
            MySQL.insert.await(
                'INSERT INTO phone_messages (sender_character_id, receiver_character_id, message) VALUES (?, ?, ?)',
                { tonumber(char.id), -112, message }
            )
            local reply = 'Dispecerat 112: Mesajul tau a fost receptionat. Echipajele au fost alertate.'
            MySQL.insert.await(
                'INSERT INTO phone_messages (sender_character_id, receiver_character_id, message) VALUES (?, ?, ?)',
                { -112, tonumber(char.id), reply }
            )
        end)

        local ped = GetPlayerPed(source)
        local pCoords = (ped and ped ~= 0) and GetEntityCoords(ped) or vector3(0, 0, 0)
        local streetHash, crossingHash = GetStreetNameAtCoord(pCoords.x, pCoords.y, pCoords.z)
        local street = GetStreetNameFromHashKey(streetHash)
        if crossingHash ~= 0 then
            street = street .. ' / ' .. GetStreetNameFromHashKey(crossingHash)
        end
        local zone = GetNameOfZone(pCoords.x, pCoords.y, pCoords.z)
        local area = GetLabelText(zone)
        if area == 'NULL' or area == '' then area = zone end

        pcall(function()
            if exports.sunset_dispatch and exports.sunset_dispatch.CreateCall then
                exports.sunset_dispatch:CreateCall({
                    source = source,
                    type = 'police',
                    coords = pCoords,
                    description = '112 SMS Apel: ' .. message,
                    metadata = {
                        emergency = '112',
                        category = 'emergency',
                        street = street,
                        area = area,
                        callerPhone = char.phone_number or '112-SMS',
                        callerName = (char.firstname or '') .. ' ' .. (char.lastname or ''),
                        timestamp = os.time(),
                    },
                })
            end
        end)

        TriggerClientEvent('sunset:client:phoneMessage', source)
        return true
    end

    if targetCharacterId == tonumber(char.id) then return nil, 'Cannot message yourself' end

    local exists = MySQL.scalar.await('SELECT id FROM characters WHERE id = ?', { targetCharacterId })
    if not exists then return nil, 'Player / character not found' end

    MySQL.insert.await(
        'INSERT INTO phone_messages (sender_character_id, receiver_character_id, message) VALUES (?, ?, ?)',
        { tonumber(char.id), targetCharacterId, message }
    )

    local targetSource = findSourceByCharacterId(targetCharacterId)
    if targetSource then
        TriggerClientEvent('sunset:chat:message', targetSource, {
            id = source,
            name = exports.sunset_core:GetPlayerBaseName(source),
            message = '',
            time = os.date('%H:%M:%S'),
            type = 'sms',
            smsNotify = true,
        })
        TriggerClientEvent('sunset:client:phoneMessage', targetSource)
    end

    return true
end)
