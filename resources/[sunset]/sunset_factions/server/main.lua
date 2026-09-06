local function getChar(source)
    return FactionCore.getChar(source)
end

local function getFactionOf(char)
    return FactionCore.getFactionOf(char)
end

local function hasPerm(source, perm)
    return FactionCore.hasPerm(source, perm)
end

local PendingFactionInvites = {}
local FACTION_INVITE_SECONDS = 120

local function addSociety(societyName, amount)
    if not societyName or amount <= 0 then return end
    pcall(function()
        MySQL.update.await('UPDATE societies SET balance = balance + ? WHERE name = ?', { amount, societyName })
    end)
end

local function nearFactionPoint(source, faction, point, radius)
    local coords = faction and faction[point]
    if not coords then return false end
    return FactionCore.distBetween(FactionCore.playerCoords(source), coords) <= (radius or 5.0)
end

function IsOnDuty(source)
    return FactionCore.isOnDuty(source)
end
exports('IsOnDuty', IsOnDuty)

local function setDuty(source, state)
    state = state == true
    FactionCore.setOnDuty(source, state)
    local char = getChar(source)
    if char then
        char.metadata = char.metadata or {}
        char.metadata.on_duty = state
        TriggerClientEvent('sunset:client:updateCharacter', source, char)
    end
    local factionId = char and select(1, getFactionOf(char)) or nil
    TriggerClientEvent('sunset:client:dutyState', source, state, factionId)
    TriggerEvent('sunset:server:taxiDutySync', source, state)
    if SyncPlayerCombatState then SyncPlayerCombatState(source) end
end

exports.sunset_core:RegisterCallback('sunset:toggleDuty', function(source)
    local char = getChar(source)
    if not char then return nil, 'Cannot toggle duty: your character is not loaded. Reconnect and select it again.' end
    local factionId = getFactionOf(char)
    local faction = factionId and Sunset.Factions[factionId]
    if not faction or not faction.duty then return nil, 'You are not in a faction with duty shifts' end
    if not FactionCore.isOnDuty(source) and not nearFactionPoint(source, faction, 'hq', 6.0) then
        return nil, 'Go to your faction HQ to start duty'
    end
    setDuty(source, not FactionCore.isOnDuty(source))
    return FactionCore.isOnDuty(source)
end)

exports.sunset_core:RegisterCallback('sunset:joinFactionHQ', function(source, factionId)
    local faction = Sunset.Factions[factionId]
    if not faction then return nil, 'Unknown faction' end
    return nil, faction.applicationsOpen
        and ('You cannot join %s at the HQ. Apply on Discord or the website; if accepted, its leader must invite you with /finvite.'):format(faction.label)
        or ('%s is not recruiting publicly. Membership requires a leader invitation.'):format(faction.label)
end)

local function leaveFactionForSource(source)
    local char = getChar(source)
    if not char then return nil, 'Cannot leave the faction: your character is not loaded. Reconnect and select it again.' end
    local oldFaction = getFactionOf(char)
    if not oldFaction then return nil, 'You are not in a faction' end

    local wasLeader = FactionCore.isFactionLeader(char.id, oldFaction)
    setDuty(source, false)

    if not exports.sunset_core:SetFaction(source, nil, 0) then
        return nil, 'Could not leave faction — try again'
    end

    if wasLeader then
        MySQL.update.await(
            'DELETE FROM faction_leaders WHERE character_id = ? AND faction_id = ?',
            { char.id, oldFaction }
        )
    end

    FactionCore.auditLog(oldFaction, char.id, 'leave', char.id, { voluntary = true })

    TriggerClientEvent('sunset:client:notify', source,
        ('You left %s. Your civilian job is unchanged.'):format(
            Sunset.Factions[oldFaction] and Sunset.Factions[oldFaction].label or oldFaction
        ), 'success')
    return true
end

exports.sunset_core:RegisterCallback('sunset:leaveFaction', function(source)
    return leaveFactionForSource(source)
end)

exports.sunset_core:RegisterCallback('sunset:factionInvite', function(source, targetId)
    local char = getChar(source)
    if not char then return nil, 'Cannot recruit: your character is not loaded. Reconnect and select it again.' end
    local myFaction = getFactionOf(char)
    if not myFaction then return nil, 'No faction' end
    if not FactionCore.isFactionLeader(char.id, myFaction) then
        return nil, 'Only the faction leader appointed by an administrator can invite applicants.'
    end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    if targetId == source then return nil, 'You cannot invite yourself.' end
    local target = getChar(targetId)
    if not target then return nil, 'That player has not loaded a character yet.' end
    local targetFaction = getFactionOf(target)
    if targetFaction then
        local label = Sunset.Factions[targetFaction] and Sunset.Factions[targetFaction].label or targetFaction
        return nil, ('That player is already a member of %s.'):format(label)
    end
    if FactionCore.distBetween(FactionCore.playerCoords(source), FactionCore.playerCoords(targetId)) > 10.0 then
        return nil, 'Meet the accepted applicant first; they must be within 10 metres when you invite them.'
    end
    local existing = PendingFactionInvites[targetId]
    if existing and existing.expiresAt > os.time() then
        return nil, 'That player already has a pending faction invitation. They must accept or decline it first.'
    end

    local faction = Sunset.Factions[myFaction]
    PendingFactionInvites[targetId] = {
        factionId = myFaction,
        inviterSource = source,
        inviterCharacterId = char.id,
        targetCharacterId = target.id,
        expiresAt = os.time() + FACTION_INVITE_SECONDS,
    }
    FactionCore.auditLog(myFaction, char.id, 'invite_sent', target.id, { expiresIn = FACTION_INVITE_SECONDS })
    TriggerClientEvent('sunset:faction:inviteReceived', targetId, {
        factionId = myFaction,
        label = faction and faction.label or myFaction,
        leader = exports.sunset_core:GetPlayerDisplayName(source),
        expiresIn = FACTION_INVITE_SECONDS,
    })
    return {
        label = faction and faction.label or myFaction,
        target = exports.sunset_core:GetPlayerDisplayName(targetId),
        expiresIn = FACTION_INVITE_SECONDS,
    }
end)

exports.sunset_core:RegisterCallback('sunset:factionAcceptInvite', function(source)
    local invite = PendingFactionInvites[source]
    if not invite then return nil, 'You do not have a pending faction invitation.' end
    PendingFactionInvites[source] = nil
    if invite.expiresAt <= os.time() then return nil, 'Your faction invitation expired. Ask the leader to invite you again.' end

    local char = getChar(source)
    if not char or tonumber(char.id) ~= tonumber(invite.targetCharacterId) then
        return nil, 'The invitation belongs to a different or unloaded character.'
    end
    if getFactionOf(char) then return nil, 'You are already a member of a faction.' end
    local leader = getChar(invite.inviterSource)
    if not leader or select(1, getFactionOf(leader)) ~= invite.factionId
        or not FactionCore.isFactionLeader(leader.id, invite.factionId) then
        return nil, 'The inviting leader is no longer available. Ask them to send a new invitation.'
    end
    if not exports.sunset_core:SetFaction(source, invite.factionId, 0) then
        return nil, 'Faction membership could not be saved. Please try again.'
    end

    local faction = Sunset.Factions[invite.factionId]
    FactionCore.auditLog(invite.factionId, leader.id, 'invite_accepted', char.id, {})
    TriggerClientEvent('sunset:client:notify', invite.inviterSource,
        ('%s accepted the invitation to %s.'):format(exports.sunset_core:GetPlayerDisplayName(source), faction.label), 'success', 7000)
    return { factionId = invite.factionId, label = faction.label }
end)

exports.sunset_core:RegisterCallback('sunset:factionDeclineInvite', function(source)
    local invite = PendingFactionInvites[source]
    if not invite then return nil, 'You do not have a pending faction invitation.' end
    PendingFactionInvites[source] = nil
    local char = getChar(source)
    FactionCore.auditLog(invite.factionId, char and char.id or nil, 'invite_declined', invite.targetCharacterId, {})
    if GetPlayerName(invite.inviterSource) then
        TriggerClientEvent('sunset:client:notify', invite.inviterSource,
            ('%s declined the faction invitation.'):format(exports.sunset_core:GetPlayerDisplayName(source)), 'info', 6000)
    end
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionPromote', function(source, targetId, newGrade)
    local char = getChar(source)
    if not char then return nil, 'Cannot change rank: your character is not loaded. Reconnect and select it again.' end
    if not hasPerm(source, 'promote') and not FactionCore.isFactionLeader(char.id, select(1, getFactionOf(char))) then
        return nil, FactionCore.accessError(source, 'promote', 'change a faction member rank')
    end

    local myFaction, myGrade = getFactionOf(char)
    if not myFaction then return nil, 'No faction' end

    targetId = tonumber(targetId)
    newGrade = tonumber(newGrade)
    if not targetId or newGrade == nil then return nil, 'Usage: /fpromote [id] [grade]' end
    if not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end

    local target = getChar(targetId)
    local targetFaction, _ = target and getFactionOf(target)
    if not target or targetFaction ~= myFaction then return nil, 'Target is not in your faction' end

    local faction = Sunset.Factions[myFaction]
    if not faction or not faction.grades[newGrade] then return nil, 'Invalid grade' end
    if newGrade >= (myGrade or 0) and source ~= targetId then
        return nil, 'You cannot promote to your rank or higher'
    end

    exports.sunset_core:SetFaction(targetId, myFaction, newGrade)
    local gradeLabel = faction.grades[newGrade].label
    FactionCore.auditLog(myFaction, char.id, 'promote', target.id, { grade = newGrade })
    TriggerClientEvent('sunset:client:notify', targetId, ('Promoted to %s'):format(gradeLabel), 'success')
    TriggerClientEvent('sunset:client:notify', source, ('Promoted player to %s'):format(gradeLabel), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeFine', function(source, targetId, amount, reason)
    return nil, 'The old instant fine command is disabled. Use /ticket [id], select an official violation, and let the player pay or refuse it.'
end)

function HasFactionPerm(source, perm)
    return hasPerm(source, perm)
end
exports('HasFactionPerm', HasFactionPerm)

exports.sunset_core:RegisterCallback('sunset:factionHeal', function(source, targetId)
    if not hasPerm(source, 'heal') then return nil, FactionCore.accessError(source, 'heal', 'heal a patient') end
    targetId = tonumber(targetId) or source
    if not FactionCore.isOnline(targetId) then
        return nil, ('Patient ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end
    TriggerClientEvent('sunset:admin:heal', targetId)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionRevive', function(source, targetId)
    if not hasPerm(source, 'revive') then return nil, FactionCore.accessError(source, 'revive', 'revive a patient') end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Usage: /revive [player id]' end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > 4.0 then
        return nil, 'You must be near the patient'
    end

    local isDowned = false
    pcall(function() isDowned = exports.sunset_death:IsPlayerDowned(targetId) end)
    if not isDowned then return nil, 'Target is not downed' end

    local ok, err = exports.sunset_death:RevivePlayer(targetId)
    if not ok then return nil, err end
    return true
end)

exports.sunset_core:RegisterCallback('sunset:mechanicShopRepair', function(source)
    local price = 250
    local faction = Sunset.Factions.mechanic
    if not nearFactionPoint(source, faction, 'hq', 8.0) then return nil, 'You must be at LS Customs' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or GetVehiclePedIsIn(ped, false) == 0 then return nil, 'You must be in a vehicle' end
    if exports.sunset_core:RemoveMoney(source, 'cash', price, 'ls_customs_repair') then
        addSociety('mechanic', math.floor(price * 0.5))
        return true
    end
    if exports.sunset_core:RemoveMoney(source, 'bank', price, 'ls_customs_repair') then
        addSociety('mechanic', math.floor(price * 0.5))
        return true
    end
    return nil, ('Not enough money ($%s)'):format(price)
end)

exports.sunset_core:RegisterCallback('sunset:factionRequestFleet', function(source, factionId)
    local char = getChar(source)
    local ownFaction = char and select(1, getFactionOf(char))
    local faction = ownFaction and Sunset.Factions[ownFaction]
    if ownFaction ~= factionId or not faction or not faction.depot then return nil, 'You do not work here' end
    if not FactionCore.isOnDuty(source) then return nil, 'Go on duty first' end
    if FactionCore.distBetween(FactionCore.playerCoords(source), faction.depot.coords) > 8.0 then
        return nil, 'You must be at the fleet garage'
    end
    return { vehicle = faction.depot.vehicle, platePrefix = faction.depot.platePrefix }
end)

RegisterNetEvent('sunset:factionRegisterFleetVehicle', function(networkId, factionId)
    local src = source
    networkId = tonumber(networkId)
    factionId = tostring(factionId or '')
    local char = getChar(src)
    local ownFaction = char and select(1, getFactionOf(char))
    local faction = ownFaction and Sunset.Factions[ownFaction]
    if not networkId or ownFaction ~= factionId or not faction or not faction.depot then return end
    if not FactionCore.isOnDuty(src) then return end

    local vehicle = 0
    for _ = 1, 20 do
        vehicle = NetworkGetEntityFromNetworkId(networkId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then break end
        Wait(100)
    end
    local ped = GetPlayerPed(src)
    if vehicle == 0 or not DoesEntityExist(vehicle) or ped == 0 then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    if GetEntityModel(vehicle) ~= joaat(faction.depot.vehicle) then return end
    if FactionCore.distBetween(GetEntityCoords(vehicle), faction.depot.spawn) > 25.0 then return end

    Entity(vehicle).state:set('sunsetFactionVehicle', factionId, true)
    Entity(vehicle).state:set('sunsetProtectedVehicle', true, true)
end)

exports.sunset_core:RegisterCallback('sunset:mechanicRepair', function(source, targetId)
    if not hasPerm(source, 'repair') then return nil, FactionCore.accessError(source, 'repair', 'repair a customer vehicle') end
    targetId = tonumber(targetId) or source
    if not GetPlayerName(targetId) then
        return nil, ('Player ID %s is not online. Use F10 to check current IDs.'):format(tostring(targetId or '?'))
    end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > 6.0 then
        return nil, 'You must be near the vehicle'
    end
    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 or GetVehiclePedIsIn(targetPed, false) == 0 then
        return nil, 'Target must be inside a vehicle'
    end

    TriggerClientEvent('sunset:faction:repairVehicle', targetId)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:taxiFare', function(source, targetId, amount)
    if not hasPerm(source, 'fare') then return nil, FactionCore.accessError(source, 'fare', 'charge a taxi fare') end
    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    if not targetId or amount < 1 or amount > 25000 then return nil, 'Invalid fare' end
    if not GetPlayerName(targetId) then return nil, 'Passenger not found' end

    local driverPos = FactionCore.playerCoords(source)
    local passengerPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(driverPos, passengerPos) > 8.0 then
        return nil, 'You must be near the passenger'
    end

    if not exports.sunset_core:RemoveMoney(targetId, 'cash', amount, 'taxi') then
        if not exports.sunset_core:RemoveMoney(targetId, 'bank', amount, 'taxi') then
            return nil, 'Passenger cannot pay'
        end
    end
    local cut = math.floor(amount * (Sunset.Taxi and Sunset.Taxi.companyCut or 0.12))
    exports.sunset_core:AddMoney(source, 'cash', amount - cut, 'taxi_fare')
    addSociety('taxi', cut)
    TriggerClientEvent('sunset:client:notify', targetId, ('Taxi fare: $%s'):format(amount), 'info')
    return true
end)

local function sellIllegalAtHQ(source, factionId)
    local char = getChar(source)
    if not char or getFactionOf(char) ~= factionId then return nil, 'Wrong faction' end
    if not FactionCore.isOnDuty(source) then return nil, 'You must be on duty' end

    local prices = Sunset.IllegalSellPrices and Sunset.IllegalSellPrices[factionId]
    if not prices then return nil, 'Nothing to sell here' end

    local sold = 0
    local total = 0

    if prices.item then
        if not hasPerm(source, 'sell') then return nil, 'Rank too low' end
        if not exports.sunset_inventory:HasItem(source, prices.item, 1) then
            return nil, ('You need %s to sell'):format(prices.label or prices.item)
        end
        exports.sunset_inventory:RemoveItem(source, prices.item, 1)
        exports.sunset_core:AddMoney(source, 'cash', prices.price, 'illegal_sale')
        sold = 1
        total = prices.price
    else
        if not hasPerm(source, 'fence') then return nil, 'Rank too low' end
        for _, row in ipairs(prices) do
            if exports.sunset_inventory:HasItem(source, row.item, 1) then
                exports.sunset_inventory:RemoveItem(source, row.item, 1)
                exports.sunset_core:AddMoney(source, 'cash', row.price, 'fence_sale')
                sold = sold + 1
                total = total + row.price
                break
            end
        end
        if sold < 1 then return nil, 'No fenceable items in inventory' end
    end

    return { sold = sold, total = total }
end

exports.sunset_core:RegisterCallback('sunset:illegalSell', function(source)
    local char = getChar(source)
    if not char then return nil, 'Cannot sell faction goods: your character is not loaded. Reconnect and select it again.' end
    local factionId = getFactionOf(char)
    if not factionId then return nil, 'Not in a faction' end
    return sellIllegalAtHQ(source, factionId)
end)

exports.sunset_core:RegisterCallback('sunset:getFactionPanel', function(source)
    local char = getChar(source)
    if not char then return nil end
    local factionId, grade = getFactionOf(char)
    local faction = factionId and Sunset.Factions[factionId]
    if not faction then
        local jobId = select(1, Sunset.GetCharacterJob(char))
        local job = Sunset.CivilianJobs[jobId]
        return {
            job = jobId,
            label = job and job.label or 'Unemployed',
            onDuty = false,
            isFaction = false,
        }
    end
    local gradeRow = Sunset.GetFactionGrade(factionId, grade)
    local motd = ''
    pcall(function()
        local row = MySQL.single.await('SELECT message FROM faction_motd WHERE faction_id = ?', { factionId })
        motd = row and row.message or ''
    end)
    return {
        job = factionId,
        label = faction.label,
        type = faction.type,
        factionType = faction.factionType,
        description = faction.description,
        grade = grade,
        gradeLabel = gradeRow and gradeRow.label or '—',
        onDuty = FactionCore.isOnDuty(source),
        salary = gradeRow and gradeRow.salary or 0,
        depot = faction.depot and faction.depot.label or nil,
        commands = Sunset.GetFactionCommandsForGrade(factionId, grade, FactionCore.isFactionLeader(char.id, factionId)),
        isFaction = true,
        civilianJob = select(1, Sunset.GetCharacterJob(char)),
        motd = motd,
        isLeader = FactionCore.isFactionLeader(char.id, factionId),
    }
end)

local function factionRoster(factionId)
    local leaders = {}
    for _, row in ipairs(MySQL.query.await([[
        SELECT fl.character_id, c.firstname, c.lastname
        FROM faction_leaders fl
        LEFT JOIN characters c ON c.id = fl.character_id
        WHERE fl.faction_id = ?
        ORDER BY fl.assigned_at ASC
    ]], { factionId }) or {}) do
        leaders[tonumber(row.character_id)] = true
    end

    local online = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local member = src and getChar(src)
        if member and select(1, getFactionOf(member)) == factionId then
            online[tonumber(member.id)] = { serverId = src, onDuty = FactionCore.isOnDuty(src) }
        end
    end

    local roster = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, firstname, lastname, metadata FROM characters', {}) or {}) do
        local metadata = row.metadata
        if type(metadata) == 'string' then
            local ok, decoded = pcall(json.decode, metadata)
            metadata = ok and decoded or {}
        end
        metadata = type(metadata) == 'table' and metadata or {}
        if metadata.faction == factionId then
            local grade = tonumber(metadata.faction_grade) or 0
            local gradeRow = Sunset.GetFactionGrade(factionId, grade)
            local presence = online[tonumber(row.id)]
            roster[#roster + 1] = {
                characterId = tonumber(row.id),
                serverId = presence and presence.serverId or nil,
                name = (('%s %s'):format(row.firstname or '', row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                grade = grade,
                gradeLabel = gradeRow and gradeRow.label or ('Rank ' .. grade),
                leader = leaders[tonumber(row.id)] == true,
                online = presence ~= nil,
                onDuty = presence and presence.onDuty or false,
            }
        end
    end
    table.sort(roster, function(a, b)
        if a.leader ~= b.leader then return a.leader end
        if a.online ~= b.online then return a.online end
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    return roster
end

exports.sunset_core:RegisterCallback('sunset:factionDashboard', function(source)
    local char = getChar(source)
    if not char then return nil, 'Your character is not loaded.' end
    local factionId, grade = getFactionOf(char)
    local faction = factionId and Sunset.Factions[factionId]
    if not faction then return nil, 'You are not a member of a faction. Use /factions to browse them.' end
    local gradeRow = Sunset.GetFactionGrade(factionId, grade)
    local motd = ''
    local motdOk, motdRow = pcall(function()
        return MySQL.single.await('SELECT message FROM faction_motd WHERE faction_id = ?', { factionId })
    end)
    if not motdOk then return nil, 'Faction data could not be read from the database. Please try again.' end
    if motdRow then motd = tostring(motdRow.message or '') end
    local activityOk, activity = pcall(function()
        return MySQL.single.await([[
            SELECT COUNT(*) AS total FROM faction_audit_log
            WHERE faction_id = ? AND actor_character_id = ?
              AND created_at >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)
        ]], { factionId, char.id })
    end)
    if not activityOk then return nil, 'Weekly faction report could not be read. Please try again.' end
    local rosterOk, roster = pcall(factionRoster, factionId)
    if not rosterOk then return nil, 'Faction roster could not be read. Please try again.' end
    return {
        id = factionId,
        label = faction.label,
        description = faction.description,
        grade = grade,
        gradeLabel = gradeRow and gradeRow.label or ('Rank ' .. tostring(grade)),
        salary = gradeRow and gradeRow.salary or 0,
        onDuty = FactionCore.isOnDuty(source),
        leader = FactionCore.isFactionLeader(char.id, factionId),
        motd = motd,
        depot = faction.depot and faction.depot.label or 'No fleet garage',
        report = { current = tonumber(activity and activity.total) or 0, target = faction.weeklyReportTarget or 0 },
        members = roster,
    }
end)

exports.sunset_core:RegisterCallback('sunset:factionDirectory', function(source)
    if not getChar(source) then return nil, 'Your character is not loaded.' end
    local result, byId = {}, {}
    for factionId, faction in pairs(Sunset.Factions or {}) do
        local entry = {
            id = factionId, label = faction.label, type = faction.type,
            factionType = faction.factionType, description = faction.description,
            applicationsOpen = faction.applicationsOpen == true,
            applicationLabel = faction.type == 'illegal' and 'Invite only'
                or (faction.applicationsOpen and 'Applications open — Discord / website' or 'Applications closed'),
            online = 0, onDuty = 0, total = 0, leaders = {},
        }
        byId[factionId] = entry
        result[#result + 1] = entry
    end
    local charactersOk, characters = pcall(function()
        return MySQL.query.await('SELECT id, metadata FROM characters', {})
    end)
    if not charactersOk then return nil, 'Faction directory could not read member data. Please try again.' end
    for _, row in ipairs(characters or {}) do
        local metadata = row.metadata
        if type(metadata) == 'string' then
            local ok, decoded = pcall(json.decode, metadata)
            metadata = ok and decoded or {}
        end
        local entry = type(metadata) == 'table' and byId[metadata.faction]
        if entry then entry.total = entry.total + 1 end
    end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local member = src and getChar(src)
        local factionId = member and select(1, getFactionOf(member))
        local entry = factionId and byId[factionId]
        if entry then
            entry.online = entry.online + 1
            if FactionCore.isOnDuty(src) then entry.onDuty = entry.onDuty + 1 end
        end
    end
    local leadersOk, leaderRows = pcall(function()
        return MySQL.query.await([[
            SELECT fl.faction_id, c.firstname, c.lastname FROM faction_leaders fl
            LEFT JOIN characters c ON c.id = fl.character_id ORDER BY fl.assigned_at ASC
        ]], {})
    end)
    if not leadersOk then return nil, 'Faction directory could not read leadership data. Please try again.' end
    for _, row in ipairs(leaderRows or {}) do
        local entry = byId[row.faction_id]
        if entry then entry.leaders[#entry.leaders + 1] = (('%s %s'):format(row.firstname or '', row.lastname or '')):gsub('%s+$', '') end
    end
    table.sort(result, function(a, b)
        if a.type ~= b.type then return a.type == 'legal' end
        return a.label < b.label
    end)
    return result
end)

AddEventHandler('playerDropped', function()
    PendingFactionInvites[source] = nil
    for target, invite in pairs(PendingFactionInvites) do
        if invite.inviterSource == source then PendingFactionInvites[target] = nil end
    end
    FactionCore.setOnDuty(source, false)
    if Detention and Detention.clear then Detention.clear(source) end
end)

AddEventHandler('sunset:server:characterSelected', function(source)
    FactionCore.setOnDuty(source, false)
    local char = getChar(source)
    local factionId = char and select(1, getFactionOf(char)) or nil
    TriggerClientEvent('sunset:client:dutyState', source, false, factionId, true)
end)

AddEventHandler('sunset:server:factionChanged', function(source, factionId)
    FactionCore.setOnDuty(source, false)
    TriggerClientEvent('sunset:client:dutyState', source, false, factionId, true)
end)

function GetDutyState(source)
    return FactionCore.isOnDuty(source)
end
exports('GetDutyState', GetDutyState)

function IsFactionLeader(source)
    local char = getChar(source)
    local factionId = char and select(1, getFactionOf(char))
    return factionId ~= nil and FactionCore.isFactionLeader(char.id, factionId)
end
exports('IsFactionLeader', IsFactionLeader)

local function leaderHqPayload(source)
    local char = getChar(source)
    if not char then return nil end
    local factionId = select(1, getFactionOf(char))
    if not factionId or not FactionCore.isFactionLeader(char.id, factionId) then return nil end
    local faction = Sunset.Factions[factionId]
    local hq = faction and faction.hq
    if not hq then return nil end
    local heading = 0.0
    if faction.depot and faction.depot.spawn then
        heading = faction.depot.spawn.w or 0.0
    end
    return {
        factionId = factionId,
        label = faction.label or factionId,
        hidden = faction.type == 'illegal',
        x = hq.x,
        y = hq.y,
        z = hq.z,
        w = heading,
    }
end

function GetLeaderHqSpawn(source)
    return leaderHqPayload(source)
end
exports('GetLeaderHqSpawn', GetLeaderHqSpawn)

exports.sunset_core:RegisterCallback('sunset:getLeaderSpawnHq', function(source)
    local hq = leaderHqPayload(source)
    if not hq then return nil end
    return { factionId = hq.factionId, label = hq.label, hidden = hq.hidden == true }
end)

exports('AddSocietyMoney', addSociety)
