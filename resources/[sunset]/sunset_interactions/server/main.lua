local INTERACTION_RANGE = 3.5
local MAX_CASH_TRANSFER = 50000
local RequestRate = {}

local function notify(source, message, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, message, kind or 'info', duration)
end

local function nearbyPlayers(source, targetId, range)
    targetId = tonumber(targetId)
    if not targetId or targetId <= 0 or not GetPlayerName(targetId) then
        return nil, 'That player is no longer online. Close the menu and select them again.'
    end
    if targetId == source then return nil, 'You cannot interact with yourself from this menu.' end

    local sourcePed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetId)
    if not sourcePed or sourcePed == 0 or not targetPed or targetPed == 0 then
        return nil, 'One of the characters is not available yet. Try again in a moment.'
    end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(sourceCoords - targetCoords) > (range or INTERACTION_RANGE) then
        return nil, ('Move closer to player #%d. You must remain within %.1f metres.'):format(targetId, range or INTERACTION_RANGE)
    end

    local sourceChar = exports.sunset_core:GetCharacter(source)
    local targetChar = exports.sunset_core:GetCharacter(targetId)
    if not sourceChar or not targetChar then
        return nil, 'Both players must have a loaded character.'
    end
    return { sourceChar = sourceChar, targetChar = targetChar, targetId = targetId }
end

local function permitted(source, permission)
    if GetResourceState('sunset_factions') ~= 'started' then return false end
    local ok, result = pcall(function()
        return exports.sunset_factions:HasFactionPerm(source, permission)
    end)
    return ok and result == true
end

local function addAction(actions, id, group, label, description, options)
    local row = options or {}
    row.id = id
    row.group = group
    row.label = label
    row.description = description
    actions[#actions + 1] = row
end

local function getDetentionState(targetId)
    local ok, state = pcall(function()
        return exports.sunset_factions:GetDetentionState(targetId)
    end)
    return ok and state or 'FREE'
end

exports.sunset_core:RegisterCallback('sunset:interactionContext', function(source, targetId)
    local pair, err = nearbyPlayers(source, targetId)
    if not pair then return nil, err end

    local actions = {}
    local state = getDetentionState(pair.targetId)
    addAction(actions, 'give_cash', 'CIVILIAN', 'Give cash', 'Hand money directly to this player.', {
        input = { type = 'number', label = 'Amount', min = 1, max = MAX_CASH_TRANSFER, placeholder = '$ amount' },
    })
    addAction(actions, 'add_friend', 'CIVILIAN', 'Add to contacts', 'Save this player in your phone contacts.')

    local isLeader = false
    local leaderOk, leaderResult = pcall(function()
        return exports.sunset_factions:IsFactionLeader(source)
    end)
    isLeader = leaderOk and leaderResult == true
    if isLeader then
        addAction(actions, 'faction_invite', 'FACTION', 'Invite to faction', 'Invite an accepted applicant to your faction.')
    end

    if permitted(source, 'cuff') and state ~= 'CUFFED' and state ~= 'ESCORTED' and state ~= 'IN_VEHICLE' then
        addAction(actions, 'cuff', 'POLICE', 'Cuff suspect', 'Apply restraints to the nearby player.', { danger = true })
    end
    if permitted(source, 'uncuff') and (state == 'CUFFED' or state == 'ESCORTED' or state == 'IN_VEHICLE') then
        addAction(actions, 'uncuff', 'POLICE', 'Remove cuffs', 'Release the player from restraints.')
    end
    if permitted(source, 'escort') and (state == 'CUFFED' or state == 'ESCORTED') then
        addAction(actions, 'escort', 'POLICE', state == 'ESCORTED' and 'Stop escorting' or 'Escort suspect', 'Attach or release the restrained player.')
    end
    if permitted(source, 'vehicle_detain') and (state == 'CUFFED' or state == 'ESCORTED') then
        addAction(actions, 'put_vehicle', 'POLICE', 'Place in vehicle', 'Put the restrained player into a nearby vehicle.')
    end
    if permitted(source, 'vehicle_detain') and state == 'IN_VEHICLE' then
        addAction(actions, 'take_vehicle', 'POLICE', 'Remove from vehicle', 'Take the restrained player out of the vehicle.')
    end
    if permitted(source, 'frisk') then
        addAction(actions, 'frisk', 'POLICE', 'Search player', 'Inspect carried items and contraband.')
    end
    if permitted(source, 'confiscate') then
        addAction(actions, 'confiscate', 'POLICE', 'Confiscate contraband', 'Remove confiscatable illegal items.', { danger = true })
    end
    if permitted(source, 'ticket') or permitted(source, 'fine') then
        addAction(actions, 'ticket', 'POLICE', 'Issue citation', 'Open the official violation selector.')
    end
    if permitted(source, 'wanted') or permitted(source, 'wanted_limited') then
        local reasons = {}
        for code, reason in pairs((Sunset.Police and Sunset.Police.reasons) or {}) do
            reasons[#reasons + 1] = {
                value = code,
                label = ('%s — %d star%s%s'):format(reason.label, reason.stars, reason.stars == 1 and '' or 's', reason.surrenderable == false and ' / no surrender' or ''),
            }
        end
        table.sort(reasons, function(a, b) return a.label < b.label end)
        addAction(actions, 'set_wanted', 'POLICE', 'Add wanted charge', 'Select the offence committed by this player.', {
            danger = true,
            input = { type = 'select', label = 'Offence', options = reasons },
        })
    end
    if permitted(source, 'megaphone') then
        addAction(actions, 'summon', 'POLICE', 'Issue stop order', 'Send a visible and audible police warning.')
    end
    if permitted(source, 'arrest') then
        addAction(actions, 'arrest', 'POLICE', 'Book into jail', 'Requires cuffs, active wanted and a booking location.', { danger = true })
    end

    if permitted(source, 'stabilize') then
        addAction(actions, 'stabilize', 'MEDICAL', 'Stabilize patient', 'Stop a downed patient from deteriorating.')
    end
    if permitted(source, 'heal') then
        addAction(actions, 'heal', 'MEDICAL', 'Treat injuries', 'Restore the nearby patient’s health.')
    end
    if permitted(source, 'revive') then
        addAction(actions, 'revive', 'MEDICAL', 'Revive patient', 'Revive a stabilized downed patient.')
    end
    if permitted(source, 'repair') then
        addAction(actions, 'repair_vehicle', 'SERVICE', 'Repair vehicle', 'Repair the vehicle occupied by this player.')
    end
    if permitted(source, 'fare') then
        addAction(actions, 'taxi_fare', 'SERVICE', 'Offer taxi fare', 'Send a fare that the passenger must accept.', {
            input = { type = 'number', label = 'Fare', min = 1, max = 1000, placeholder = '$ fare' },
        })
    end
    if permitted(source, 'issue_license') then
        addAction(actions, 'license_exam', 'INSTRUCTOR', 'Authorize license exam', 'Start a supervised LSSI exam for this candidate.', {
            input = { type = 'select', label = 'License', options = {
                { value = 'pilot', label = 'Flying license' },
                { value = 'boat', label = 'Boat license' },
                { value = 'weapon', label = 'Gun license' },
            } },
        })
    end

    local targetFaction = Sunset.GetCharacterFaction(pair.targetChar)
    local wanted = nil
    local wantedOk, wantedState = pcall(function()
        return exports.sunset_factions:GetWantedState(pair.targetId)
    end)
    if wantedOk and type(wantedState) == 'table' and (tonumber(wantedState.level) or 0) > 0 then
        wanted = { level = tonumber(wantedState.level) or 0, surrenderable = wantedState.surrenderable ~= false }
    end

    return {
        target = {
            id = pair.targetId,
            name = exports.sunset_core:GetPlayerDisplayName(pair.targetId),
            level = tonumber(pair.targetChar.level) or 1,
            faction = targetFaction and Sunset.Factions[targetFaction] and Sunset.Factions[targetFaction].label or nil,
            detention = state,
            wanted = wanted,
        },
        actions = actions,
    }
end)

exports.sunset_core:RegisterCallback('sunset:interactionGiveCash', function(source, targetId, rawAmount)
    local pair, err = nearbyPlayers(source, targetId)
    if not pair then return nil, err end

    local amount = math.floor(tonumber(rawAmount) or 0)
    if amount < 1 or amount > MAX_CASH_TRANSFER then
        return nil, ('Enter an amount between $1 and $%s.'):format(MAX_CASH_TRANSFER)
    end

    local now = GetGameTimer()
    if now - (RequestRate[source] or 0) < 1500 then return nil, 'Wait a moment before transferring money again.' end
    RequestRate[source] = now

    if not exports.sunset_core:RemoveMoney(source, 'cash', amount, 'player_transfer') then
        return nil, ('You need $%s cash in hand for this transfer.'):format(amount)
    end
    if not exports.sunset_core:AddMoney(pair.targetId, 'cash', amount, 'player_transfer') then
        exports.sunset_core:AddMoney(source, 'cash', amount, 'player_transfer_rollback')
        return nil, 'The recipient could not receive the money. Your cash was returned.'
    end

    local giverName = exports.sunset_core:GetPlayerDisplayName(source)
    local targetName = exports.sunset_core:GetPlayerDisplayName(pair.targetId)
    notify(pair.targetId, ('%s gave you $%s cash.'):format(giverName, amount), 'success', 6000)
    return { amount = amount, target = targetName }
end)

exports.sunset_core:RegisterCallback('sunset:interactionAddFriend', function(source, targetId)
    local pair, err = nearbyPlayers(source, targetId)
    if not pair then return nil, err end

    local phone = tostring(pair.targetChar.phone_number or '')
    if phone == '' then
        phone = ('555-%04d'):format(tonumber(pair.targetChar.id) or 0)
        pair.targetChar.phone_number = phone
        MySQL.update.await('UPDATE characters SET phone_number = ? WHERE id = ?', { phone, pair.targetChar.id })
    end
    local name = ('%s %s'):format(pair.targetChar.firstname or '', pair.targetChar.lastname or ''):gsub('^%s*(.-)%s*$', '%1')
    if name == '' then name = GetPlayerName(pair.targetId) or ('Player ' .. pair.targetId) end

    local ok = MySQL.update.await([[
        INSERT INTO phone_contacts (character_id, contact_name, phone_number, contact_character_id)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE contact_name = VALUES(contact_name), contact_character_id = VALUES(contact_character_id)
    ]], { pair.sourceChar.id, name:sub(1, 48), phone, pair.targetChar.id })
    if ok == nil then return nil, 'The contact could not be saved. Try again.' end

    notify(pair.targetId, ('%s added you to their phone contacts.'):format(exports.sunset_core:GetPlayerDisplayName(source)), 'info', 5000)
    return { name = name, phone = phone }
end)

AddEventHandler('playerDropped', function()
    RequestRate[source] = nil
end)
