-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Slot Machines (server.lua)
-- ═══════════════════════════════════════════════════════════════

local function notify(src, msg, kind)
    TriggerClientEvent('sunset:client:notify', src, msg, kind or 'info', 5000)
end

local function countChips(source)
    if GetResourceState('sunset_inventory') ~= 'started' then return 0 end
    local ok, count = pcall(function()
        return exports.sunset_inventory:CountItem(source, 'casino_chips')
    end)
    return ok and (tonumber(count) or 0) or 0
end

local function giveChips(source, amount)
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports.sunset_inventory:AddItem(source, 'casino_chips', math.floor(amount))
    end)
    return ok and res ~= false
end

local function takeChips(source, amount)
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports.sunset_inventory:RemoveItem(source, 'casino_chips', math.floor(amount))
    end)
    return ok and res == true
end

RegisterServerEvent('sunset_slots:BetsAndMoney')
AddEventHandler('sunset_slots:BetsAndMoney', function(bets)
    local src = source
    bets = math.floor(tonumber(bets) or 0)

    if bets < (Config.MinBet or 50) or bets > (Config.MaxBet or 50000) then
        notify(src, ('Bet must be between %d and %d chips.'):format(Config.MinBet or 50, Config.MaxBet or 50000), 'error')
        if Config.SittingEnabled then
            TriggerClientEvent('sunset_slots:unsit', src)
        end
        return
    end

    if countChips(src) < bets then
        notify(src, 'You do not have enough chips. Buy chips at the Cashier.', 'error')
        if Config.SittingEnabled then
            TriggerClientEvent('sunset_slots:unsit', src)
        end
        return
    end

    if not takeChips(src, bets) then
        notify(src, 'Could not deduct chips from inventory.', 'error')
        if Config.SittingEnabled then
            TriggerClientEvent('sunset_slots:unsit', src)
        end
        return
    end

    TriggerClientEvent('sunset_slots:UpdateSlots', src, bets)
end)

RegisterServerEvent('sunset_slots:PayOutRewards')
AddEventHandler('sunset_slots:PayOutRewards', function(amount)
    local src = source
    amount = math.floor(tonumber(amount) or 0)
    if amount > 0 then
        giveChips(src, amount)
        notify(src, ('You cashed out %s chips from the slot machine!'):format(amount), 'success')
    else
        notify(src, 'Better luck next time!', 'info')
    end
end)

-- ── SEAT LOCKING ──
local SeatsTaken = {} -- [id] = src

RegisterServerEvent('sunset_slots:takePlace')
AddEventHandler('sunset_slots:takePlace', function(object)
    local src = source
    if object then
        SeatsTaken[tostring(object)] = src
    end
end)

RegisterServerEvent('sunset_slots:leavePlace')
AddEventHandler('sunset_slots:leavePlace', function(object)
    local src = source
    if object then
        if SeatsTaken[tostring(object)] == src then
            SeatsTaken[tostring(object)] = nil
        end
    end
end)

exports.sunset_core:RegisterCallback('sunset:slots:getPlace', function(source, id)
    if not id then return false end
    return SeatsTaken[tostring(id)] ~= nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, playerSrc in pairs(SeatsTaken) do
        if playerSrc == src then
            SeatsTaken[id] = nil
        end
    end
end)

print('^2[sunset_slots]^7 Sizzling 5-reel slot machines online')