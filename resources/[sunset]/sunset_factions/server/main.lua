local OnDuty = {}
local Cuffed = {}

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function getFactionOf(char)
    return Sunset.GetCharacterFaction(char)
end

local function hasPerm(source, perm)
    local char = getChar(source)
    if not char then return false end
    if not OnDuty[source] then return false end
    local factionId, grade = getFactionOf(char)
    if not factionId then return false end
    return Sunset.HasFactionPerm(factionId, grade, perm)
end

local function addSociety(societyName, amount)
    if not societyName or amount <= 0 then return end
    pcall(function()
        MySQL.update.await('UPDATE societies SET balance = balance + ? WHERE name = ?', { amount, societyName })
    end)
end

function IsOnDuty(source)
    return OnDuty[source] == true
end
exports('IsOnDuty', IsOnDuty)

local function setDuty(source, state)
    OnDuty[source] = state and true or false
    local char = getChar(source)
    if char then
        char.metadata = char.metadata or {}
        char.metadata.on_duty = OnDuty[source]
        TriggerClientEvent('sunset:client:updateCharacter', source, char)
    end
    local factionId = select(1, getFactionOf(char))
    TriggerClientEvent('sunset:client:dutyState', source, OnDuty[source], factionId)
    TriggerEvent('sunset:server:taxiDutySync', source, OnDuty[source])
end

exports.sunset_core:RegisterCallback('sunset:toggleDuty', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local factionId = getFactionOf(char)
    local faction = factionId and Sunset.Factions[factionId]
    if not faction or not faction.duty then return nil, 'You are not in a faction with duty shifts' end
    setDuty(source, not OnDuty[source])
    return OnDuty[source]
end)

exports.sunset_core:RegisterCallback('sunset:joinFactionHQ', function(source, factionId)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local faction = Sunset.Factions[factionId]
    if not faction then return nil, 'Unknown faction' end

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
    if not hasPerm(source, 'invite') then return nil, 'No permission' end

    local myFaction = getFactionOf(char)
    if not myFaction then return nil, 'No faction' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end
    local target = getChar(targetId)
    if not target then return nil, 'Target has no character' end
    if getFactionOf(target) then return nil, 'Target is already in a faction' end

    exports.sunset_core:SetFaction(targetId, myFaction, 0)
    TriggerClientEvent('sunset:client:notify', targetId, 'You joined ' .. (Sunset.Factions[myFaction].label or myFaction), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionPromote', function(source, targetId, newGrade)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    if not hasPerm(source, 'promote') then return nil, 'No permission' end

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
    TriggerClientEvent('sunset:client:notify', targetId, ('Promoted to %s'):format(gradeLabel), 'success')
    TriggerClientEvent('sunset:client:notify', source, ('Promoted player to %s'):format(gradeLabel), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeFine', function(source, targetId, amount, reason)
    if not hasPerm(source, 'fine') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    if not targetId or amount < 1 then return nil, 'Invalid fine' end
    if not GetPlayerName(targetId) then return nil, 'Player not found' end

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
    local faction = officer and Sunset.Factions[officer.job]
    if faction and faction.society then
        addSociety(faction.society, amount - commission)
    end

    TriggerClientEvent('sunset:client:notify', targetId, ('Fined $%s: %s'):format(amount, reason or '—'), 'error')
    return true
end)

local function isOnline(target)
    target = tonumber(target)
    if not target then return false end
    for _, id in ipairs(GetPlayers()) do
        if tonumber(id) == target then return true end
    end
    return false
end

function HasFactionPerm(source, perm)
    return hasPerm(source, perm)
end
exports('HasFactionPerm', HasFactionPerm)

exports.sunset_core:RegisterCallback('sunset:factionHeal', function(source, targetId)
    if not hasPerm(source, 'heal') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId) or source
    if not isOnline(targetId) then return nil, 'Player not found' end
    TriggerClientEvent('sunset:admin:heal', targetId)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionRevive', function(source, targetId)
    if not hasPerm(source, 'revive') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId)
    if not targetId then return nil, 'Usage: /revive [player id]' end
    local ok, err = exports.sunset_death:RevivePlayer(targetId)
    if not ok then return nil, err end
    return true
end)

exports.sunset_core:RegisterCallback('sunset:mechanicShopRepair', function(source)
    local price = 250
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

exports.sunset_core:RegisterCallback('sunset:mechanicRepair', function(source, targetId)
    if not hasPerm(source, 'repair') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId) or source
    if not GetPlayerName(targetId) then return nil, 'Player not found' end
    TriggerClientEvent('sunset:faction:repairVehicle', targetId)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:taxiFare', function(source, targetId, amount)
    if not hasPerm(source, 'fare') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    if not targetId or amount < 1 then return nil, 'Invalid fare' end
    if not GetPlayerName(targetId) then return nil, 'Passenger not found' end
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
    if not OnDuty[source] then return nil, 'You must be on duty' end

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
    return {
        job = factionId,
        label = faction.label,
        type = faction.type,
        description = faction.description,
        grade = grade,
        gradeLabel = gradeRow and gradeRow.label or '—',
        onDuty = OnDuty[source] == true,
        salary = gradeRow and gradeRow.salary or 0,
        depot = faction.depot and faction.depot.label or nil,
        commands = Sunset.GetFactionCommandsForGrade(factionId, grade),
        isFaction = true,
        civilianJob = select(1, Sunset.GetCharacterJob(char)),
    }
end)

RegisterCommand('f', function(source, args)
    local char = getChar(source)
    local factionId = char and getFactionOf(char)
    if not char or not factionId then return end
    local msg = table.concat(args, ' ')
    if msg == '' then return end
    local name = exports.sunset_core:GetPlayerDisplayName(source)
    local faction = Sunset.Factions[factionId]
    local label = faction and faction.label or factionId
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = getChar(src)
        if c and getFactionOf(c) == factionId then
            TriggerClientEvent('sunset:chat:message', src, {
                id = source,
                name = '[' .. label .. '] ' .. name,
                message = msg,
                time = os.date('%H:%M'),
            })
        end
    end
end, false)

RegisterNetEvent('sunset:server:factionCmd', function(cmd, ...)
    local source = source
    local args = { ... }
    if cmd == 'cuff' then
        if not hasPerm(source, 'cuff') then return end
        local target = tonumber(args[1])
        if target and GetPlayerName(target) then
            Cuffed[target] = true
            TriggerClientEvent('sunset:faction:cuff', target)
        end
    elseif cmd == 'uncuff' then
        if not hasPerm(source, 'uncuff') then return end
        local target = tonumber(args[1])
        if target and GetPlayerName(target) then
            Cuffed[target] = nil
            TriggerClientEvent('sunset:faction:uncuff', target)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    OnDuty[src] = nil
    Cuffed[src] = nil
end)

AddEventHandler('sunset:server:characterSelected', function(source)
    OnDuty[source] = false
    TriggerClientEvent('sunset:client:dutyState', source, false, nil)
end)

AddEventHandler('sunset:server:jobChanged', function(source, job)
    OnDuty[source] = false
    TriggerClientEvent('sunset:client:dutyState', source, false, job)
end)

function GetDutyState(source)
    return OnDuty[source] == true
end
exports('GetDutyState', GetDutyState)

exports('AddSocietyMoney', addSociety)
