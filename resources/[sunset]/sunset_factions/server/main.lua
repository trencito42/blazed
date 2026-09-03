local function getChar(source)
    return FactionCore.getChar(source)
end

local function getFactionOf(char)
    return FactionCore.getFactionOf(char)
end

local function hasPerm(source, perm)
    return FactionCore.hasPerm(source, perm)
end

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
    if not char then return nil, 'No character' end
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
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local faction = Sunset.Factions[factionId]
    if not faction then return nil, 'Unknown faction' end
    if faction.type == 'illegal' then return nil, 'This faction is invite-only' end
    if not nearFactionPoint(source, faction, 'hq', 6.0) then
        return nil, 'You must be at this faction HQ'
    end

    local currentFaction = getFactionOf(char)
    if currentFaction and currentFaction ~= factionId then
        local currentLabel = Sunset.Factions[currentFaction] and Sunset.Factions[currentFaction].label or currentFaction
        return nil, ('You are in %s. Use /leavefaction first.'):format(currentLabel)
    end
    if currentFaction == factionId then return nil, 'You are already a member — use /duty' end

    if not exports.sunset_core:SetFaction(source, factionId, 0) then
        return nil, 'Could not join faction'
    end
    if faction.duty then
        setDuty(source, true)
    end
    return true
end)

exports.sunset_core:RegisterCallback('sunset:leaveFaction', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local oldFaction = getFactionOf(char)
    if not oldFaction then return nil, 'You are not in a faction' end

    setDuty(source, false)

    if not exports.sunset_core:SetFaction(source, nil, 0) then
        return nil, 'Could not leave faction — try again'
    end

    TriggerClientEvent('sunset:client:notify', source,
        ('You left %s. Your civilian job is unchanged.'):format(
            Sunset.Factions[oldFaction] and Sunset.Factions[oldFaction].label or oldFaction
        ), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionInvite', function(source, targetId)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    if not hasPerm(source, 'invite') and not FactionCore.isFactionLeader(char.id, select(1, getFactionOf(char))) then
        return nil, 'No permission'
    end

    local myFaction = getFactionOf(char)
    if not myFaction then return nil, 'No faction' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end
    local target = getChar(targetId)
    if not target then return nil, 'Target has no character' end
    if getFactionOf(target) then return nil, 'Target is already in a faction' end

    exports.sunset_core:SetFaction(targetId, myFaction, 0)
    FactionCore.auditLog(myFaction, char.id, 'invite', target.id, {})
    TriggerClientEvent('sunset:client:notify', targetId, 'You joined ' .. (Sunset.Factions[myFaction].label or myFaction), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionPromote', function(source, targetId, newGrade)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    if not hasPerm(source, 'promote') and not FactionCore.isFactionLeader(char.id, select(1, getFactionOf(char))) then
        return nil, 'No permission'
    end

    local myFaction, myGrade = getFactionOf(char)
    if not myFaction then return nil, 'No faction' end

    targetId = tonumber(targetId)
    newGrade = tonumber(newGrade)
    if not targetId or newGrade == nil then return nil, 'Usage: /fpromote [id] [grade]' end
    if not GetPlayerName(targetId) then return nil, 'Player not found' end

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
    if not hasPerm(source, 'fine') and not hasPerm(source, 'ticket') then
        return nil, 'Not on duty or no permission'
    end
    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    if not targetId or amount < 1 or amount > 50000 then return nil, 'Invalid fine' end
    if not GetPlayerName(targetId) then return nil, 'Player not found' end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > 8.0 then
        return nil, 'You must be near the target'
    end

    if not exports.sunset_core:RemoveMoney(targetId, 'bank', amount, 'fine') then
        if not exports.sunset_core:RemoveMoney(targetId, 'cash', amount, 'fine') then
            return nil, 'Target cannot pay'
        end
    end

    local officer = getChar(source)
    local target = getChar(targetId)
    if officer and target then
        MySQL.insert.await(
            'INSERT INTO faction_fines (officer_character_id, target_character_id, amount, reason) VALUES (?, ?, ?, ?)',
            { officer.id, target.id, amount, reason or '' }
        )
    end

    local commission = math.floor(amount * 0.1)
    exports.sunset_core:AddMoney(source, 'bank', commission, 'fine_commission')
    local officerFaction = officer and select(1, Sunset.GetCharacterFaction(officer))
    local faction = officerFaction and Sunset.Factions[officerFaction]
    if faction and faction.society then
        addSociety(faction.society, amount - commission)
    end

    TriggerClientEvent('sunset:client:notify', targetId, ('Fined $%s: %s'):format(amount, reason or '—'), 'error')
    return true
end)

function HasFactionPerm(source, perm)
    return hasPerm(source, perm)
end
exports('HasFactionPerm', HasFactionPerm)

exports.sunset_core:RegisterCallback('sunset:factionHeal', function(source, targetId)
    if not hasPerm(source, 'heal') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId) or source
    if not FactionCore.isOnline(targetId) then return nil, 'Player not found' end
    TriggerClientEvent('sunset:admin:heal', targetId)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionRevive', function(source, targetId)
    if not hasPerm(source, 'revive') then return nil, 'Not on duty or no permission' end
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

exports.sunset_core:RegisterCallback('sunset:mechanicRepair', function(source, targetId)
    if not hasPerm(source, 'repair') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId) or source
    if not GetPlayerName(targetId) then return nil, 'Player not found' end

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
    if not hasPerm(source, 'fare') then return nil, 'Not on duty or no permission' end
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
    if not char then return nil, 'No character' end
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
        commands = Sunset.GetFactionCommandsForGrade(factionId, grade),
        isFaction = true,
        civilianJob = select(1, Sunset.GetCharacterJob(char)),
        motd = motd,
        isLeader = FactionCore.isFactionLeader(char.id, factionId),
    }
end)

AddEventHandler('playerDropped', function()
    FactionCore.setOnDuty(source, false)
    if Detention and Detention.clear then Detention.clear(source) end
end)

AddEventHandler('sunset:server:characterSelected', function(source)
    FactionCore.setOnDuty(source, false)
    TriggerClientEvent('sunset:client:dutyState', source, false, nil)
end)

AddEventHandler('sunset:server:factionChanged', function(source, factionId)
    FactionCore.setOnDuty(source, false)
    TriggerClientEvent('sunset:client:dutyState', source, false, factionId)
end)

function GetDutyState(source)
    return FactionCore.isOnDuty(source)
end
exports('GetDutyState', GetDutyState)

exports('AddSocietyMoney', addSociety)
