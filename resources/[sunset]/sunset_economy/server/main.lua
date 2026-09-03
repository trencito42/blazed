local lastPaydayHour = -1

local function getSalary(char)
    local job = Sunset.Jobs[char.job]
    if not job then return 0 end
    local grade = job.grades[char.job_grade or 0]
    return grade and grade.salary or 0
end

local function processPayday(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end

    local faction = Sunset.Factions and Sunset.Factions[char.job]
    if faction and faction.duty and not exports.sunset_factions:IsOnDuty(source) then
        return
    end

    local salary = getSalary(char)
    if salary <= 0 then return end

    local tax = math.floor(salary * (Sunset.Config.TaxRate or 0))
    local net = salary - tax
    exports.sunset_core:AddMoney(source, 'bank', net, 'payday')
    TriggerClientEvent('sunset:client:payday', source, net, tax)
end

local function broadcastTime()
    local hour = tonumber(os.date('%H'))
    local minute = tonumber(os.date('%M'))
    local nextH = (hour + 1) % 24
  TriggerClientEvent('sunset:client:serverTime', -1, {
        time = os.date('%H:%M'),
        hour = hour,
        minute = minute,
        nextPayday = ('%02d:00'):format(nextH),
    })
end

CreateThread(function()
    while true do
        local hour = tonumber(os.date('%H'))
        if hour ~= lastPaydayHour then
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

    local shopItem
    for _, row in ipairs(shop.items) do
        if row.item == itemName then shopItem = row break end
    end
    if not shopItem then return nil, 'Item not sold here' end

    local total = shopItem.price * amount
    if not exports.sunset_core:RemoveMoney(source, 'cash', total, 'shop') then
        if not exports.sunset_core:RemoveMoney(source, 'bank', total, 'shop') then
            return nil, 'Not enough money'
        end
    end

    if not exports.sunset_inventory:AddItem(source, itemName, amount) then
        exports.sunset_core:AddMoney(source, 'cash', total, 'shop_refund')
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
