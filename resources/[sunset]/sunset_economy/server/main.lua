local PaydayTimers = {}

local function getSalary(char)
    local job = Sunset.Jobs[char.job]
    if not job then return 0 end
    local grade = job.grades[char.job_grade or 0]
    return grade and grade.salary or 0
end

local function processPayday(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end
    local salary = getSalary(char)
    if salary <= 0 then return end

    local tax = math.floor(salary * (Sunset.Config.TaxRate or 0))
    local net = salary - tax
    exports.sunset_core:AddMoney(source, 'bank', net, 'payday')
    TriggerClientEvent('sunset:client:payday', source, net, tax)
end

RegisterNetEvent('sunset:server:paydayTick', function()
    processPayday(source)
end)

AddEventHandler('sunset:client:playerSpawned', function() end)

RegisterNetEvent('sunset:server:playerSpawned', function()
    local source = source
    PaydayTimers[source] = Sunset.Config.PaydayInterval
end)

AddEventHandler('playerDropped', function()
    PaydayTimers[source] = nil
end)

CreateThread(function()
    while true do
        for src, timer in pairs(PaydayTimers) do
            timer = timer - 1
            if timer <= 0 then
                processPayday(src)
                timer = Sunset.Config.PaydayInterval
            end
            PaydayTimers[src] = timer
            TriggerClientEvent('sunset:client:paydayTimer', src, timer)
        end
        Wait(1000)
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
