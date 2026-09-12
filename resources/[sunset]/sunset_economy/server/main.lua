local lastPaydayHour = -1
local PlayedMinutes = {}
local WorldTime = { hour = nil, minute = nil, frozen = false }
local WorldWeather = nil

local WEATHER_TYPES = {
    CLEAR = true, EXTRASUNNY = true, CLOUDS = true, OVERCAST = true, RAIN = true,
    THUNDER = true, CLEARING = true, NEUTRAL = true, SMOG = true, FOGGY = true,
    XMAS = true, SNOWLIGHT = true, BLIZZARD = true,
}

local function serverClock()
    return tonumber(os.date('%H')), tonumber(os.date('%M'))
end

local function worldClock()
    if WorldTime.hour ~= nil and WorldTime.minute ~= nil then
        return WorldTime.hour, WorldTime.minute
    end
    return serverClock()
end

local function broadcastWeather()
    if not WorldWeather then return end
    TriggerClientEvent('sunset:client:serverWeather', -1, { weather = WorldWeather })
end

-- [AUDIT P7-07] One UPDATE per player per minute (48/min) replaced by in-memory
-- accumulation + a single batched flush every 5 minutes. Pending minutes for a
-- disconnecting player are flushed immediately so nothing is lost.
local PendingMinutes = {} -- [charId] = minutes not yet written

local function flushPendingMinutes(onlyCharId)
    local ids, params, whenClauses = {}, {}, {}
    for charId, mins in pairs(PendingMinutes) do
        if (not onlyCharId or charId == onlyCharId) and mins > 0 then
            ids[#ids + 1] = charId
            whenClauses[#whenClauses + 1] = 'WHEN ? THEN ?'
            params[#params + 1] = charId
            params[#params + 1] = mins
        end
    end
    if #ids == 0 then return end
    for _, charId in ipairs(ids) do PendingMinutes[charId] = nil end
    local sql = ('UPDATE characters SET active_minutes_since_payday = LEAST(65535, active_minutes_since_payday + CASE id %s END) WHERE id IN (%s)')
        :format(table.concat(whenClauses, ' '), table.concat(ids, ','))
    local ok, err = pcall(function() MySQL.update.await(sql, params) end)
    if not ok then
        print(('[sunset_economy] pending minutes flush failed: %s'):format(tostring(err)))
        for i, charId in ipairs(ids) do
            PendingMinutes[charId] = (PendingMinutes[charId] or 0) + (params[(i - 1) * 2 + 2] or 0)
        end
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                local char = exports.sunset_core:GetCharacter(src)
                if char and not char.is_dead then
                    PlayedMinutes[src] = (PlayedMinutes[src] or 0) + 1
                    PendingMinutes[char.id] = (PendingMinutes[char.id] or 0) + 1
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(300000)
        flushPendingMinutes()
    end
end)

AddEventHandler('playerDropped', function()
    local ok, char = pcall(function() return exports.sunset_core:GetCharacter(source) end)
    PlayedMinutes[source] = nil
    if ok and char and char.id then
        flushPendingMinutes(char.id)
    end
end)

local function getSalary(char, source)
    local civilianSalary = 0
    local factionSalary = 0

    local jobId, jobGrade = Sunset.GetCharacterJob(char)
    local job = Sunset.CivilianJobs[jobId] or Sunset.Jobs[jobId]
    local jobRow = job and job.grades[jobGrade or 0]
    civilianSalary = jobRow and tonumber(jobRow.salary) or 0

    local factionId, grade = Sunset.GetCharacterFaction(char)
    if factionId then
        local faction = Sunset.Factions[factionId]
        if not faction or not faction.duty or exports.sunset_factions:IsOnDuty(source) then
            local row = faction and faction.grades[grade or 0]
            factionSalary = row and tonumber(row.salary) or 0
        end
    end
    return civilianSalary + factionSalary, civilianSalary, factionSalary
end

local function processPayday(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end

    local periodKey = os.date('%Y%m%d%H')
    if MySQL.scalar.await('SELECT 1 FROM payday_runs WHERE character_id=? AND period_key=? LIMIT 1', { char.id, periodKey }) then
        return
    end

    local salary, civilianSalary, factionSalary = getSalary(char, source)
    local incomeTax = math.floor(salary * (Sunset.Config.TaxRate or 0))

    -- Anti-inflation maintenance taxes
    local vehCount = 0
    pcall(function()
        vehCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `vehicles` WHERE `character_id` = ? AND `destroyed` = 0', { char.id })) or 0
    end)
    local vehicleTax = math.min(1000, vehCount * 30)
    local propertyTax = (char.home_property_id and tonumber(char.home_property_id) > 0) and 50 or 0
    local totalTax = incomeTax + vehicleTax + propertyTax

    local net = math.max(0, salary - totalTax)
    local respect = Sunset.Config.RespectPerPayday or 1
    local robPts = 1
    local rent = { charged = 0 }
    local outcome = { status = 'failed', played = 0 }
    -- [AUDIT P6-01] GetDetentionState returns uppercase 'JAILED'; the previous
    -- lowercase comparison never matched, so jailed players collected full payday.
    local detentionState = GetResourceState('sunset_factions') == 'started'
        and exports.sunset_factions:GetDetentionState(source) or nil
    local detained = char.is_dead == 1 or char.is_dead == true
        or tostring(detentionState or ''):upper() == 'JAILED'
    local callOk, committed = pcall(function()
        return MySQL.startTransaction(function(query)
            local rows = query.await([[SELECT cash, bank, active_minutes_since_payday, metadata
                FROM characters WHERE id=? FOR UPDATE]], { char.id })
            local locked = rows and rows[1]
            if not locked then return false end
            local played = tonumber(locked.active_minutes_since_payday) or 0
            outcome.played = played
            local status = played < 20 and 'insufficient_activity' or (detained and 'detained' or 'paid')

            if status ~= 'paid' then
                query.await('UPDATE characters SET active_minutes_since_payday=0 WHERE id=?', { char.id })
                query.await([[INSERT INTO payday_runs(character_id,period_key,played_minutes,status)
                    VALUES(?,?,?,?)]], { char.id, periodKey, played, status })
                outcome.status = status
                return true
            end

            local bankAfter = (tonumber(locked.bank) or 0) + net
            local cashAfter = tonumber(locked.cash) or 0
            local rentalRows = query.await([[SELECT r.id,r.property_id,r.rent_price,p.label,p.owner_character_id
                FROM property_rentals r JOIN properties p ON p.id=r.property_id
                WHERE r.character_id=? AND r.active=1 LIMIT 1 FOR UPDATE]], { char.id })
            local rental = rentalRows and rentalRows[1]
            if rental then
                local rentPrice = math.max(0, tonumber(rental.rent_price) or 0)
                rent.label = rental.label
                if bankAfter >= rentPrice then
                    bankAfter = bankAfter - rentPrice
                    rent.charged = rentPrice
                elseif cashAfter >= rentPrice then
                    cashAfter = cashAfter - rentPrice
                    rent.charged = rentPrice
                else
                    query.await('UPDATE property_rentals SET active=0 WHERE id=?', { rental.id })
                    query.await('UPDATE characters SET home_property_id=NULL WHERE id=? AND home_property_id=?',
                        { char.id, rental.property_id })
                    rent.evicted = true
                end
                if rent.charged > 0 then
                    local ownerPaid = query.await('UPDATE characters SET bank=bank+? WHERE id=?',
                        { rent.charged, rental.owner_character_id })
                    if tonumber(ownerPaid) ~= 1 then return false end
                    query.await('UPDATE property_rentals SET last_paid_at=NOW() WHERE id=?', { rental.id })
                    rent.ownerId = tonumber(rental.owner_character_id)
                end
            end

            local metadata = type(locked.metadata) == 'table' and locked.metadata or json.decode(locked.metadata or '{}') or {}
            metadata.rob_points = math.max(0, math.floor(tonumber(metadata.rob_points) or 0) + robPts)
            local changed = query.await([[UPDATE characters SET cash=?, bank=?,
                respect_points=respect_points+?, paydays_received=paydays_received+1,
                active_minutes_since_payday=0, metadata=? WHERE id=?]],
                { cashAfter, bankAfter, respect, json.encode(metadata), char.id })
            if tonumber(changed) ~= 1 then return false end
            query.await([[INSERT INTO payday_runs(character_id,period_key,played_minutes,status,gross,tax,net,rent)
                VALUES(?,?,?,?,?,?,?,?)]],
                { char.id, periodKey, played, 'paid', salary, totalTax, net, rent.charged or 0 })
            outcome.status = 'paid'
            outcome.metadata = metadata
            return true
        end)
    end)
    PlayedMinutes[source] = 0
    if not callOk or not committed then
        TriggerClientEvent('sunset:client:notify', source, 'Payday could not be committed safely. Your activity was kept; staff can retry this period.', 'error')
        return
    end
    if outcome.status == 'insufficient_activity' then
        TriggerClientEvent('sunset:client:notify', source, ('Payday skipped: You played %d/20 min required this hour.'):format(outcome.played), 'info')
        return
    elseif outcome.status == 'detained' then
        TriggerClientEvent('sunset:client:notify', source, 'Payday suspended while incapacitated or serving a jail sentence.', 'warning')
        return
    end

    exports.sunset_core:RefreshMoney(source)
    local refreshed = MySQL.single.await('SELECT respect_points,paydays_received,metadata,home_property_id FROM characters WHERE id=?', { char.id })
    if refreshed then
        char.respect_points = tonumber(refreshed.respect_points) or char.respect_points
        char.paydays_received = tonumber(refreshed.paydays_received) or char.paydays_received
        char.metadata = type(refreshed.metadata) == 'table' and refreshed.metadata or json.decode(refreshed.metadata or '{}') or {}
        char.home_property_id = refreshed.home_property_id
        TriggerClientEvent('sunset:client:updateCharacter', source, char)
    end
    if rent.ownerId then
        for _, playerId in ipairs(GetPlayers()) do
            local ownerSource = tonumber(playerId)
            local owner = exports.sunset_core:GetCharacter(ownerSource)
            if owner and tonumber(owner.id) == rent.ownerId then exports.sunset_core:RefreshMoney(ownerSource) break end
        end
    end
    if rent.evicted then
        TriggerClientEvent('sunset:client:notify', source,
            ('Rental at %s ended because you could not pay it.'):format(rent.label or 'your house'), 'error')
    end
    TriggerEvent('sunset:payday:processed', source)
    TriggerClientEvent('sunset:client:payday', source, net, totalTax, {
        civilian = civilianSalary,
        faction = factionSalary,
        gross = salary,
        tax = totalTax,
        vehicleTax = vehicleTax,
        propertyTax = propertyTax,
        rent = rent.charged or 0,
        rentProperty = rent.label,
        rentEvicted = rent.evicted == true,
        respect = respect,
        robPoints = robPts,
    })
    if GetResourceState('sunset_pass') == 'started' then
        exports.sunset_pass:AddMissionProgress(source, 'paydays', 1)
    end
end

local function broadcastTime()
    local srvHour, srvMinute = serverClock()
    local worldHour, worldMinute = worldClock()
    local nextH = (srvHour + 1) % 24
    TriggerClientEvent('sunset:client:serverTime', -1, {
        -- HUD clock (top-right) always shows real server time, not /sett world override.
        time = ('%02d:%02d'):format(srvHour, srvMinute),
        hour = srvHour,
        minute = srvMinute,
        worldHour = worldHour,
        worldMinute = worldMinute,
        nextPayday = ('%02d:00'):format(nextH),
    })
    broadcastWeather()
end

exports('SetWorldTime', function(hour, minute, frozen)
    hour = math.floor(tonumber(hour) or 0) % 24
    minute = math.floor(tonumber(minute) or 0) % 60
    WorldTime.hour = hour
    WorldTime.minute = minute
    WorldTime.frozen = frozen ~= false
    broadcastTime()
    return true
end)

exports('ClearWorldTime', function()
    WorldTime.hour = nil
    WorldTime.minute = nil
    WorldTime.frozen = false
    broadcastTime()
    return true
end)

exports('SetWorldWeather', function(weather)
    weather = string.upper(tostring(weather or ''))
    if not WEATHER_TYPES[weather] then return false, 'Invalid weather type' end
    WorldWeather = weather
    broadcastWeather()
    return true
end)

exports('ClearWorldWeather', function()
    WorldWeather = nil
    TriggerClientEvent('sunset:client:serverWeather', -1, { weather = 'CLEAR', reset = true })
    return true
end)

-- [AUDIT P7-02] Payday used to fire ~8-10 sequential queries per player in ONE
-- tick (~400-500 queries at 48 slots), freezing the server thread for seconds.
-- Players are now queued and processed a few at a time, spread over ~30s.
local PaydayQueue = {}
local PAYDAY_BATCH_SIZE = 2
local PAYDAY_BATCH_DELAY = 500

CreateThread(function()
    while true do
        if #PaydayQueue > 0 then
            local batch = {}
            for _ = 1, PAYDAY_BATCH_SIZE do
                local src = table.remove(PaydayQueue, 1)
                if not src then break end
                batch[#batch + 1] = src
            end
            for _, src in ipairs(batch) do
                if GetPlayerName(src) then
                    local ok, err = pcall(processPayday, src)
                    if not ok then
                        print(('[sunset_economy] payday error for %d: %s'):format(src, tostring(err)))
                    end
                end
            end
            Wait(PAYDAY_BATCH_DELAY)
        else
            Wait(2000)
        end
    end
end)

CreateThread(function()
    while true do
        local srvHour, _ = serverClock()
        if lastPaydayHour == -1 then
            lastPaydayHour = srvHour
        elseif srvHour ~= lastPaydayHour then
            lastPaydayHour = srvHour
            print(('[sunset_economy] Triggering hourly payday at %02d:00'):format(srvHour))
            -- [AUDIT P7-07] Flush pending activity minutes FIRST so payday's
            -- 20-minute eligibility check sees fresh data.
            pcall(flushPendingMinutes)
            -- Enqueue instead of processing inline; dedupe by source.
            local queued = {}
            for _, src in ipairs(PaydayQueue) do queued[src] = true end
            for _, playerId in ipairs(GetPlayers()) do
                local pSrc = tonumber(playerId)
                if pSrc and not queued[pSrc] then
                    PaydayQueue[#PaydayQueue + 1] = pSrc
                    queued[pSrc] = true
                end
            end
            if SunsetLottery and SunsetLottery.Draw then
                pcall(SunsetLottery.Draw)
            end
        end

        local hour, minute = worldClock()
        if not WorldTime.frozen and WorldTime.hour ~= nil then
            minute = minute + 1
            if minute >= 60 then
                minute = 0
                hour = (hour + 1) % 24
            end
            WorldTime.hour = hour
            WorldTime.minute = minute
        end

        broadcastTime()
        Wait(10000)
    end
end)

exports.sunset_core:RegisterCallback('sunset:buyItem', function(source, shopId, itemName, amount, businessId)
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then return nil, 'Invalid amount' end
    -- [AUDIT P6-05] Downed/jailed players cannot shop.
    if exports.sunset_core:IsIncapacitated(source) then return nil, 'You cannot shop right now.' end

    local shop = Sunset.Shops[shopId]
    if not shop then return nil, 'Shop not found' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'Invalid player ped' end
    local playerCoords = GetEntityCoords(ped)
    if shopId == 'twentyfour7' then
        local nearStore = false
        for _, store in ipairs(Sunset.TwentyFourSevenStores or {}) do
            if store.coords and #(playerCoords - store.coords) <= 4.0 then
                nearStore = true
                break
            end
        end
        if not nearStore then
            return nil, 'You must be at a 24/7 store to buy items'
        end
    elseif shop.coords and #(playerCoords - shop.coords) > 15.0 then
        return nil, 'You must be at the shop location to buy items'
    end

    local shopItem
    for _, row in ipairs(shop.items) do
        if row.item == itemName then shopItem = row break end
    end
    if not shopItem then return nil, 'Item not sold here' end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and try again.' end
    local maxAmount = math.max(1, math.floor(tonumber(shopItem.maxAmount) or 100))
    if amount > maxAmount then
        return nil, ('You can buy at most %d of this item at once.'):format(maxAmount)
    end
    local itemDef = Sunset.Items[itemName]
    if not itemDef then return nil, 'This shop item is not configured correctly.' end
    if shopItem.minLevel and (tonumber(char.level) or 1) < tonumber(shopItem.minLevel) then
        return nil, ('Requires level %d. Your current level is %d.'):format(
            tonumber(shopItem.minLevel), tonumber(char.level) or 1)
    end
    if shopItem.requiredLicense then
        if GetResourceState('sunset_licenses') ~= 'started' then
            return nil, 'The license service is unavailable. You were not charged.'
        end
        if not exports.sunset_licenses:HasLicense(source, shopItem.requiredLicense) then
            return nil, 'A valid Firearm License is required. Contact an on-duty LSSI instructor.'
        end
    end
    if itemDef.weapon and exports.sunset_inventory:HasItem(source, itemName, 1) then
        return nil, ('You already own %s.'):format(itemDef.label or itemName)
    end

    -- Optional fisherman-skill gate (minFishLevel on shop item)
    if shopItem.minFishLevel then
        local fishLevel = 1
        if char then
            fishLevel = tonumber(MySQL.scalar.await(
                'SELECT level FROM job_progress WHERE character_id = ? AND job_id = ?',
                { char.id, 'fisherman' }
            )) or 1
        end
        if fishLevel < shopItem.minFishLevel then
            return nil, ('Requires Fisherman level %d (your level: %d). Fish more to level up!'):format(
                shopItem.minFishLevel, fishLevel)
        end
    end

    local total = shopItem.price * amount
    local chargedAccount = 'cash'
    if not exports.sunset_core:RemoveMoney(source, 'cash', total, 'shop') then
        if not exports.sunset_core:RemoveMoney(source, 'bank', total, 'shop') then
            return nil, 'Not enough money'
        end
        chargedAccount = 'bank'
    end

    if not exports.sunset_inventory:AddItem(source, itemName, amount) then
        exports.sunset_core:AddMoney(source, chargedAccount, total, 'shop_refund')
        return nil, 'Inventory full'
    end

    businessId = tonumber(businessId)
    if businessId and GetResourceState('sunset_businesses') == 'started' then
        exports.sunset_businesses:RecordSale(businessId, total)
    end

    return true
end)

exports.sunset_core:RegisterCallback('sunset:atmTransfer', function(source, action, amount)
    amount = math.floor(amount or 0)
    if amount < 1 then return nil, 'Invalid amount' end
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    -- [AUDIT P2-08] Require physical presence at an ATM. Money math was already
    -- safe, but the callback was callable from anywhere (defeats robbery RP).
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'No character' end
    local pos = GetEntityCoords(ped)
    local nearAtm = false
    for _, atm in ipairs(Sunset.ATMs or {}) do
        if #(pos - atm) <= 2.5 then nearAtm = true break end
    end
    if not nearAtm then return nil, 'You must be at an ATM.' end

    if action == 'deposit' then
        if not exports.sunset_core:MoveMoney(source, 'cash', 'bank', amount, 'atm_deposit') then
            return nil, 'Not enough cash'
        end
    elseif action == 'withdraw' then
        if not exports.sunset_core:MoveMoney(source, 'bank', 'cash', amount, 'atm_withdraw') then
            return nil, 'Not enough bank balance'
        end
    else
        return nil, 'Invalid action'
    end
    return { cash = char.cash, bank = char.bank }
end)

exports.sunset_core:RegisterCallback('sunset:phoneBankTransfer', function(source, targetId, amount)
    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    if not targetId or targetId < 1 then return nil, 'Invalid player ID' end
    if amount < 1 then return nil, 'Invalid amount' end
    if targetId == source then return nil, 'You cannot transfer to yourself' end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character loaded' end

    local targetChar = exports.sunset_core:GetCharacter(targetId)
    if not targetChar then return nil, 'Player not found or offline' end

    if not exports.sunset_core:TransferMoney(source, targetId, 'bank', amount, 'bank_transfer') then
        return nil, 'Not enough bank balance'
    end
    TriggerClientEvent('sunset:client:notify', targetId,
        ('Received $%s bank transfer from %s.'):format(amount, exports.sunset_core:GetPlayerDisplayName(source) or 'someone'),
        'success', 6000)

    exports.sunset_core:RefreshMoney(source)
    char = exports.sunset_core:GetCharacter(source)
    local history = exports.sunset_core:GetMoneyHistory(char.id, 30)
    return {
        cash = char.cash,
        bank = char.bank,
        transactions = history,
    }
end)
