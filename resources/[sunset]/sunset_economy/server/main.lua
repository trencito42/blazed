local lastPaydayHour = -1
local PlayedMinutes = {}
local WorldTime = { hour = nil, minute = nil, frozen = false }
local WorldWeather = nil

local WEATHER_TYPES = {
    CLEAR = true, EXTRASUNNY = true, CLOUDS = true, OVERCAST = true, RAIN = true,
    THUNDER = true, CLEARING = true, NEUTRAL = true, SMOG = true, FOGGY = true,
    XMAS = true, SNOWLIGHT = true, BLIZZARD = true,
}

local function worldClock()
    if WorldTime.hour ~= nil and WorldTime.minute ~= nil then
        return WorldTime.hour, WorldTime.minute
    end
    return tonumber(os.date('%H')), tonumber(os.date('%M'))
end

local function broadcastWeather()
    if not WorldWeather then return end
    TriggerClientEvent('sunset:client:serverWeather', -1, { weather = WorldWeather })
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
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    PlayedMinutes[source] = nil
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

    local played = PlayedMinutes[source] or 0
    PlayedMinutes[source] = 0

    if played < 20 then
        TriggerClientEvent('sunset:client:notify', source, ('Payday skipped: You played %d/20 min required this hour.'):format(played), 'info')
        return
    end

    if char.is_dead == 1 or (exports.sunset_factions and exports.sunset_factions:GetDetentionState(source) == 'jailed') then
        TriggerClientEvent('sunset:client:notify', source, 'Payday suspended while incapacitated or serving a jail sentence.', 'warning')
        return
    end

    local salary, civilianSalary, factionSalary = getSalary(char, source)
    local tax = math.floor(salary * (Sunset.Config.TaxRate or 0))
    local net = salary - tax
    if net > 0 then
        exports.sunset_core:AddMoney(source, 'bank', net, 'payday')
    end
    local rent = { charged = 0 }
    if GetResourceState('sunset_properties') == 'started' then
        local ok, result = pcall(function() return exports.sunset_properties:ProcessRentPayday(source) end)
        if ok and type(result) == 'table' then rent = result end
    end
    local respect = Sunset.Config.RespectPerPayday or 1
    exports.sunset_core:AddRespectPoints(source, respect)
    TriggerEvent('sunset:payday:processed', source)
    local robPts = 1
    exports.sunset_core:AddRobPoints(source, robPts)
    TriggerClientEvent('sunset:client:payday', source, net, tax, {
        civilian = civilianSalary,
        faction = factionSalary,
        gross = salary,
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
    local hour, minute = worldClock()
    local nextH = (hour + 1) % 24
    TriggerClientEvent('sunset:client:serverTime', -1, {
        time = ('%02d:%02d'):format(hour, minute),
        hour = hour,
        minute = minute,
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

CreateThread(function()
    while true do
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

        if hour ~= lastPaydayHour and WorldTime.hour == nil then
            if lastPaydayHour >= 0 then
                for _, playerId in ipairs(GetPlayers()) do
                    processPayday(tonumber(playerId))
                end
            end
            lastPaydayHour = hour
        end
        broadcastTime()
        Wait(10000)
    end
end)

exports.sunset_core:RegisterCallback('sunset:buyItem', function(source, shopId, itemName, amount)
    amount = math.floor(amount or 1)
    if amount < 1 then return nil, 'Invalid amount' end

    local shop = Sunset.Shops[shopId]
    if not shop then return nil, 'Shop not found' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'Invalid player ped' end
    if shop.coords and #(GetEntityCoords(ped) - shop.coords) > 15.0 then
        return nil, 'You must be at the shop location to buy items'
    end

    local shopItem
    for _, row in ipairs(shop.items) do
        if row.item == itemName then shopItem = row break end
    end
    if not shopItem then return nil, 'Item not sold here' end

    -- Optional fisherman-skill gate (minFishLevel on shop item)
    if shopItem.minFishLevel then
        local char = exports.sunset_core:GetCharacter(source)
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

    return true
end)

exports.sunset_core:RegisterCallback('sunset:atmTransfer', function(source, action, amount)
    amount = math.floor(amount or 0)
    if amount < 1 then return nil, 'Invalid amount' end
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    if action == 'deposit' then
        if not exports.sunset_core:RemoveMoney(source, 'cash', amount, 'atm_deposit') then
            return nil, 'Not enough cash'
        end
        exports.sunset_core:AddMoney(source, 'bank', amount, 'atm_deposit')
    elseif action == 'withdraw' then
        if not exports.sunset_core:RemoveMoney(source, 'bank', amount, 'atm_withdraw') then
            return nil, 'Not enough bank balance'
        end
        exports.sunset_core:AddMoney(source, 'cash', amount, 'atm_withdraw')
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

    if not exports.sunset_core:RemoveMoney(source, 'bank', amount, 'bank_transfer_out') then
        return nil, 'Not enough bank balance'
    end

    exports.sunset_core:AddMoney(targetId, 'bank', amount, 'bank_transfer_in')
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
