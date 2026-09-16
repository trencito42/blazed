-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — 3D Lucky Wheel (server.lua)
-- ═══════════════════════════════════════════════════════════════

local cooldowns = {} -- [charId] = timestamp
local isSpinning = false

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

local function takeChips(source, amount)
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports.sunset_inventory:RemoveItem(source, 'casino_chips', math.floor(amount))
    end)
    return ok and res == true
end

local function givePrize(source, prize)
    if prize.type == 'cash' then
        exports.sunset_core:AddMoney(source, 'cash', prize.amount, 'Lucky Wheel Prize')
        notify(source, ('You won %s from the Lucky Wheel!'):format(prize.label), 'success')
    elseif prize.type == 'chips' then
        exports.sunset_inventory:AddItem(source, 'casino_chips', prize.amount)
        notify(source, ('You won %s from the Lucky Wheel!'):format(prize.label), 'success')
    elseif prize.type == 'item' then
        exports.sunset_inventory:AddItem(source, prize.item, prize.count or 1)
        notify(source, ('You won %s from the Lucky Wheel!'):format(prize.label), 'success')
    elseif prize.type == 'vehicle' then
        local char = exports.sunset_core:GetPlayer(source)
        if char and char.id then
            exports.sunset_vehicles:AddPersonalVehicle(char.id, prize.model, nil, function(ok)
                if ok then
                    notify(source, 'JACKPOT! You won a brand new ' .. prize.label .. '! Check your garage!', 'success')
                end
            end)
        end
    end
end

RegisterServerEvent('sunset:luckywheel:requestSpin', function()
    local src = source
    if isSpinning then
        notify(src, 'The wheel is currently spinning. Please wait.', 'error')
        return
    end

    local char = exports.sunset_core:GetPlayer(src)
    local charId = char and char.id or src
    local now = os.time()
    local cooldownEnd = cooldowns[charId] or 0

    if now < cooldownEnd then
        local remainingMins = math.ceil((cooldownEnd - now) / 60)
        notify(src, ('Lucky Wheel is on cooldown. Try again in %d minute(s).'):format(remainingMins), 'error')
        return
    end

    local chips = countChips(src)
    if chips < (Config.Amount or 100) then
        notify(src, ('You need %d casino chips to spin the wheel.'):format(Config.Amount or 100), 'error')
        return
    end

    if not takeChips(src, Config.Amount or 100) then
        notify(src, 'Could not deduct chips.', 'error')
        return
    end

    isSpinning = true
    cooldowns[charId] = now + ((Config.SpinCooldownMinutes or 60) * 60)

    -- Weighted random index (1 to 20)
    local roll = math.random(1, 100)
    local prizeIndex = 1
    if roll == 1 then
        prizeIndex = 19 -- Car Jackpot
    elseif roll <= 4 then
        prizeIndex = 20 -- 100k grand prize
    elseif roll <= 10 then
        prizeIndex = 12 -- 50k cash
    elseif roll <= 20 then
        prizeIndex = 16 -- 10k chips
    elseif roll <= 35 then
        prizeIndex = 5 -- 25k cash
    elseif roll <= 50 then
        prizeIndex = 8 -- 2.5k chips
    elseif roll <= 70 then
        prizeIndex = 3 -- 5k cash
    else
        prizeIndex = math.random(1, 18)
    end

    local ped = GetPlayerPed(src)
    local netId = ped and ped ~= 0 and NetworkGetNetworkIdFromEntity(ped) or nil
    TriggerClientEvent('sunset:luckywheel:doRoll', -1, prizeIndex, netId)

    SetTimeout(8500, function()
        isSpinning = false
        local prize = Config.Prizes[prizeIndex] or Config.Prizes[1]
        givePrize(src, prize)
    end)
end)
