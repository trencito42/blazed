-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — The Diamond Casino (server/main.lua)
--  Blackjack, Slots, Roulette — server-authoritative games.
--  All bets/payouts go through sunset_core money API.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetCasino.Config
local GameCooldowns = {}
local DailyLosses = {}  -- [charId] = { date = 'YYYY-MM-DD', total = n }
local ActiveBlackjack = {}  -- [src] = { deck, playerHand, dealerHand, bet, done }

local function notify(source, msg, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', duration or 5000)
end

local function today()
    return os.date('%Y-%m-%d')
end

local function checkDailyLoss(charId, amount)
    local entry = DailyLosses[charId]
    if not entry or entry.date ~= today() then
        DailyLosses[charId] = { date = today(), total = 0 }
        entry = DailyLosses[charId]
    end
    return entry.total + amount <= (Cfg.dailyLossLimit or 500000)
end

local function recordLoss(charId, amount)
    local entry = DailyLosses[charId]
    if not entry or entry.date ~= today() then
        DailyLosses[charId] = { date = today(), total = 0 }
        entry = DailyLosses[charId]
    end
    entry.total = entry.total + amount
end

local function checkCooldown(src)
    local now = GetGameTimer()
    if GameCooldowns[src] and now - GameCooldowns[src] < (Cfg.gameCooldownMs or 3000) then
        return false
    end
    GameCooldowns[src] = now
    return true
end

local function getCharId(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.id) or nil
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
        return exports.sunset_inventory:AddItem(source, 'casino_chips', amount)
    end)
    return ok and res ~= false
end

local function takeChips(source, amount)
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports.sunset_inventory:RemoveItem(source, 'casino_chips', amount)
    end)
    return ok and res == true
end

-- ═══════════════════════════════════════════════════════════════
--  BLACKJACK
-- ═══════════════════════════════════════════════════════════════

local function buildDeck()
    local deck = {}
    local suits = { '♠', '♥', '♦', '♣' }
    local ranks = { 'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K' }
    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            local value = tonumber(rank)
            if not value then
                if rank == 'A' then value = 11
                else value = 10 end
            end
            deck[#deck + 1] = { rank = rank, suit = suit, value = value }
        end
    end
    -- Shuffle (Fisher-Yates)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

local function handValue(hand)
    local total = 0
    local aces = 0
    for _, card in ipairs(hand) do
        total = total + card.value
        if card.rank == 'A' then aces = aces + 1 end
    end
    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end
    return total
end

local function handToTable(hand)
    local t = {}
    for _, card in ipairs(hand) do
        t[#t + 1] = { rank = card.rank, suit = card.suit }
    end
    return t
end

local function isBlackjack(hand)
    return #hand == 2 and handValue(hand) == 21
end

local function dealerPlay(game)
    while handValue(game.dealerHand) < (Cfg.dealerStandsOn or 17) do
        table.insert(game.dealerHand, table.remove(game.deck, 1))
    end
end

local function settleBlackjack(source, game)
    local charId = getCharId(source)
    if not charId then return nil end

    local playerVal = handValue(game.playerHand)
    local dealerVal = handValue(game.dealerHand)
    local bet = game.bet
    local payout = 0
    local result = ''

    if playerVal > 21 then
        result = 'bust'
        payout = 0
        recordLoss(charId, bet)
    elseif isBlackjack(game.playerHand) and not isBlackjack(game.dealerHand) then
        result = 'blackjack'
        payout = bet + math.floor(bet * (Cfg.blackjackPayout or 1.5))
    elseif dealerVal > 21 then
        result = 'dealer_bust'
        payout = bet * 2
    elseif playerVal > dealerVal then
        result = 'win'
        payout = bet * 2
    elseif playerVal == dealerVal then
        result = 'push'
        payout = bet
    else
        result = 'lose'
        payout = 0
        recordLoss(charId, bet)
    end

    if payout > 0 then
        giveChips(source, payout)
    end

    ActiveBlackjack[source] = nil

    return {
        result = result,
        payout = payout,
        chips = countChips(source),
        playerHand = handToTable(game.playerHand),
        playerValue = playerVal,
        dealerHand = handToTable(game.dealerHand),
        dealerValue = dealerVal,
    }
end

exports.sunset_core:RegisterCallback('sunset:casino:blackjackStart', function(source, bet)
    bet = math.floor(tonumber(bet) or 0)
    if bet < (Cfg.minBet or 100) or bet > (Cfg.maxBet or 50000) then
        return nil, ('Bet must be between %d and %d chips.'):format(Cfg.minBet or 100, Cfg.maxBet or 50000)
    end
    if not checkCooldown(source) then
        return nil, 'Wait a moment between games.'
    end
    local charId = getCharId(source)
    if not charId then return nil, 'No character loaded.' end
    if not checkDailyLoss(charId, bet) then
        return nil, ('Daily loss limit reached ($%s). Come back tomorrow.'):format(Cfg.dailyLossLimit or 500000)
    end
    if ActiveBlackjack[source] then
        return nil, 'You already have an active blackjack hand.'
    end
    if countChips(source) < bet then
        return nil, 'You do not have enough chips. Buy chips at the Cashier.'
    end
    if not takeChips(source, bet) then
        return nil, 'Could not take chips from your inventory.'
    end

    local deck = buildDeck()
    local game = {
        deck = deck,
        playerHand = { table.remove(deck, 1), table.remove(deck, 1) },
        dealerHand = { table.remove(deck, 1), table.remove(deck, 1) },
        bet = bet,
        done = false,
    }
    ActiveBlackjack[source] = game

    -- Check for instant blackjack
    if isBlackjack(game.playerHand) then
        dealerPlay(game)
        local settled = settleBlackjack(source, game)
        return { state = 'settled', settled = settled }
    end

    return {
        state = 'playing',
        playerHand = handToTable(game.playerHand),
        playerValue = handValue(game.playerHand),
        dealerHand = handToTable({ game.dealerHand[1] }), -- hide hole card
        dealerValue = handValue({ game.dealerHand[1] }),
        bet = bet,
    }
end)

exports.sunset_core:RegisterCallback('sunset:casino:blackjackHit', function(source)
    local game = ActiveBlackjack[source]
    if not game or game.done then return nil, 'No active hand.' end

    table.insert(game.playerHand, table.remove(game.deck, 1))
    local val = handValue(game.playerHand)

    if val > 21 then
        dealerPlay(game)
        local settled = settleBlackjack(source, game)
        return { state = 'settled', settled = settled }
    end

    return {
        state = 'playing',
        playerHand = handToTable(game.playerHand),
        playerValue = val,
        dealerHand = handToTable({ game.dealerHand[1] }),
        dealerValue = handValue({ game.dealerHand[1] }),
    }
end)

exports.sunset_core:RegisterCallback('sunset:casino:blackjackStand', function(source)
    local game = ActiveBlackjack[source]
    if not game or game.done then return nil, 'No active hand.' end

    dealerPlay(game)
    local settled = settleBlackjack(source, game)
    return { state = 'settled', settled = settled }
end)

-- ═══════════════════════════════════════════════════════════════
--  SLOTS
-- ═══════════════════════════════════════════════════════════════

local SLOT_SYMBOLS = { '🍒', '🍋', '🍊', '🍇', '💎', '7️⃣', '🔔', '⭐' }

exports.sunset_core:RegisterCallback('sunset:casino:slotsSpin', function(source, bet)
    bet = math.floor(tonumber(bet) or 0)
    if bet < (Cfg.minBet or 100) or bet > (Cfg.maxBet or 50000) then
        return nil, ('Bet must be between %d and %d chips.'):format(Cfg.minBet or 100, Cfg.maxBet or 50000)
    end
    if not checkCooldown(source) then
        return nil, 'Wait a moment between games.'
    end
    local charId = getCharId(source)
    if not charId then return nil, 'No character loaded.' end
    if not checkDailyLoss(charId, bet) then
        return nil, ('Daily loss limit reached ($%s). Come back tomorrow.'):format(Cfg.dailyLossLimit or 500000)
    end
    if countChips(source) < bet then
        return nil, 'You do not have enough chips. Buy chips at the Cashier.'
    end
    if not takeChips(source, bet) then
        return nil, 'Could not take chips from your inventory.'
    end

    -- Spin 3 reels
    local reels = {}
    for i = 1, 3 do
        reels[i] = SLOT_SYMBOLS[math.random(#SLOT_SYMBOLS)]
    end

    -- Count matches
    local counts = {}
    for _, sym in ipairs(reels) do
        counts[sym] = (counts[sym] or 0) + 1
    end
    local maxMatch = 0
    for _, c in pairs(counts) do
        if c > maxMatch then maxMatch = c end
    end

    local payouts = Cfg.slotsPayouts or { [3] = 10, [2] = 2 }
    local multiplier = payouts[maxMatch] or 0
    local payout = bet * multiplier

    if payout > 0 then
        giveChips(source, payout)
    else
        recordLoss(charId, bet)
    end

    return {
        reels = reels,
        matches = maxMatch,
        payout = payout,
        bet = bet,
        chips = countChips(source),
    }
end)

-- ═══════════════════════════════════════════════════════════════
--  ROULETTE
-- ═══════════════════════════════════════════════════════════════

local RED_NUMBERS = { 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }

local function isRed(n)
    for _, r in ipairs(RED_NUMBERS) do
        if r == n then return true end
    end
    return false
end

exports.sunset_core:RegisterCallback('sunset:casino:rouletteSpin', function(source, bet, betType, betValue)
    bet = math.floor(tonumber(bet) or 0)
    if bet < (Cfg.minBet or 100) or bet > (Cfg.maxBet or 50000) then
        return nil, ('Bet must be between %d and %d chips.'):format(Cfg.minBet or 100, Cfg.maxBet or 50000)
    end
    if not checkCooldown(source) then
        return nil, 'Wait a moment between games.'
    end
    local charId = getCharId(source)
    if not charId then return nil, 'No character loaded.' end
    if not checkDailyLoss(charId, bet) then
        return nil, ('Daily loss limit reached ($%s). Come back tomorrow.'):format(Cfg.dailyLossLimit or 500000)
    end
    if countChips(source) < bet then
        return nil, 'You do not have enough chips. Buy chips at the Cashier.'
    end
    if not takeChips(source, bet) then
        return nil, 'Could not take chips from your inventory.'
    end

    -- Spin: 0-36
    local result = math.random(0, 36)
    local resultColor = result == 0 and 'green' or (isRed(result) and 'red' or 'black')

    -- Evaluate bet
    local won = false
    local payouts = Cfg.roulettePayouts or {}
    local multiplier = 0

    betType = tostring(betType or '')
    betValue = tonumber(betValue)

    if betType == 'straight' and betValue == result then
        won = true
        multiplier = payouts.straight or 35
    elseif betType == 'red' and resultColor == 'red' then
        won = true
        multiplier = payouts.red_black or 1
    elseif betType == 'black' and resultColor == 'black' then
        won = true
        multiplier = payouts.red_black or 1
    elseif betType == 'odd' and result > 0 and result % 2 == 1 then
        won = true
        multiplier = payouts.odd_even or 1
    elseif betType == 'even' and result > 0 and result % 2 == 0 then
        won = true
        multiplier = payouts.odd_even or 1
    elseif betType == 'low' and result >= 1 and result <= 18 then
        won = true
        multiplier = payouts.low_high or 1
    elseif betType == 'high' and result >= 19 and result <= 36 then
        won = true
        multiplier = payouts.low_high or 1
    elseif betType == 'dozen' then
        local dozen = math.ceil(result / 12)
        if result > 0 and dozen == betValue then
            won = true
            multiplier = payouts.dozen or 2
        end
    elseif betType == 'column' then
        if result > 0 and (result % 3) == (betValue % 3) then
            won = true
            multiplier = payouts.column or 2
        end
    end

    local payout = won and (bet + bet * multiplier) or 0
    if payout > 0 then
        giveChips(source, payout)
    else
        recordLoss(charId, bet)
    end

    return {
        result = result,
        color = resultColor,
        won = won,
        payout = payout,
        bet = bet,
        betType = betType,
        chips = countChips(source),
    }
end)

-- ═══════════════════════════════════════════════════════════════
--  LUCKY WHEEL
-- ═══════════════════════════════════════════════════════════════

local WheelCooldowns = {}  -- [charId] = lastSpinTime

exports.sunset_core:RegisterCallback('sunset:casino:wheelSpin', function(source)
    local charId = getCharId(source)
    if not charId then return nil end

    -- Cooldown check (1 hour)
    local now = GetGameTimer()
    if WheelCooldowns[charId] and now - WheelCooldowns[charId] < (Cfg.luckyWheelCooldownMs or 3600000) then
        local remaining = math.ceil(((Cfg.luckyWheelCooldownMs or 3600000) - (now - WheelCooldowns[charId])) / 60000)
        return nil, ('Wheel on cooldown. Try again in %d minutes.'):format(remaining)
    end

    if not checkCooldown(source) then
        return nil, 'Wait a moment before spinning again.'
    end

    -- Pick random prize
    local prizes = Cfg.luckyWheelPrizes or {}
    if #prizes == 0 then return nil, 'No prizes configured.' end
    local prizeIdx = math.random(#prizes)
    local prize = prizes[prizeIdx]

    -- Apply prize
    if prize.type == 'cash' then
        exports.sunset_core:AddMoney(source, 'cash', prize.value, 'casino_wheel')
    elseif prize.type == 'chips' then
        giveChips(source, prize.value)
    elseif prize.type == 'discount' then
        notify(source, ('You won a %d%% vehicle discount!'):format(prize.value), 'success')
    elseif prize.type == 'mystery' then
        local mysteryCash = math.random(1000, 50000)
        exports.sunset_core:AddMoney(source, 'cash', mysteryCash, 'casino_wheel_mystery')
        prize = { label = ('$%s (Mystery)'):format(mysteryCash), type = 'cash', value = mysteryCash }
    end

    WheelCooldowns[charId] = now

    return {
        prizeIndex = prizeIdx,
        prize = prize,
        totalPrizes = #prizes,
    }
end)

-- ═══════════════════════════════════════════════════════════════
--  CASHIER (cash ↔ chips)
--  Chips are an INVENTORY ITEM (casino_chips), not a money account —
--  sunset_core money only supports cash/bank (verified in player.lua).
-- ═══════════════════════════════════════════════════════════════

exports.sunset_core:RegisterCallback('sunset:casino:buyChips', function(source, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < (Cfg.minChipExchange or 100) then
        return nil, ('Minimum chip exchange is $%s.'):format(Cfg.minChipExchange or 100)
    end
    if amount > (Cfg.maxChipExchange or 100000) then
        return nil, ('Maximum chip exchange is $%s.'):format(Cfg.maxChipExchange or 100000)
    end

    local rate = Cfg.chipExchangeRate or 1
    local cost = math.floor(amount * rate)

    if not exports.sunset_core:RemoveMoney(source, 'cash', cost, 'casino_buy_chips') then
        return nil, ('Not enough cash. You need $%s.'):format(cost)
    end

    if not giveChips(source, amount) then
        -- Inventory full/failed — refund
        exports.sunset_core:AddMoney(source, 'cash', cost, 'casino_buy_chips_refund')
        return nil, 'Inventory full. Make room for your chips.'
    end

    return { chips = amount, cost = cost, totalChips = countChips(source), cash = exports.sunset_core:GetMoney(source, 'cash') }
end)

exports.sunset_core:RegisterCallback('sunset:casino:sellChips', function(source, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return nil, 'Enter an amount to sell.' end

    local current = countChips(source)
    if current < amount then
        return nil, ('You only have %s chips.'):format(current)
    end

    if not takeChips(source, amount) then
        return nil, 'Could not take chips from your inventory.'
    end

    local rate = Cfg.chipExchangeRate or 1
    local cash = math.floor(amount * rate)
    if not exports.sunset_core:AddMoney(source, 'cash', cash, 'casino_sell_chips') then
        -- Money add failed — return the chips
        giveChips(source, amount)
        return nil, 'Could not pay you. Try again.'
    end

    return { chips = amount, earned = cash, cash = exports.sunset_core:GetMoney(source, 'cash'), remainingChips = countChips(source) }
end)

-- ═══════════════════════════════════════════════════════════════
--  BAR
--  Drinks are inventory items (drink defs in sunset_core items.lua
--  with thirst effects). The bar sells them; the player consumes
--  them from the inventory (thirst applied by sunset_inventory:UseItem
--  — the ONLY domain allowed to write char.thirst).
-- ═══════════════════════════════════════════════════════════════

exports.sunset_core:RegisterCallback('sunset:casino:buyDrink', function(source, drinkId)
    drinkId = tostring(drinkId or '')
    local drink = nil
    for _, d in ipairs(Cfg.barDrinks or {}) do
        if d.id == drinkId then drink = d break end
    end
    if not drink then return nil, 'Unknown drink.' end

    if not exports.sunset_core:RemoveMoney(source, 'cash', drink.price, 'casino_bar') then
        return nil, ('Not enough cash. %s costs $%s.'):format(drink.label, drink.price)
    end

    local added = false
    if GetResourceState('sunset_inventory') == 'started' then
        local ok, res = pcall(function()
            return exports.sunset_inventory:AddItem(source, drink.id, 1)
        end)
        added = ok and res ~= false
    end
    if not added then
        exports.sunset_core:AddMoney(source, 'cash', drink.price, 'casino_bar_refund')
        return nil, 'Inventory full. Could not hold the drink.'
    end

    return { label = drink.label, price = drink.price, cash = exports.sunset_core:GetMoney(source, 'cash') }
end)

-- ═══════════════════════════════════════════════════════════════
--  CASINO STATUS (cash + chips from inventory)
-- ═══════════════════════════════════════════════════════════════

exports.sunset_core:RegisterCallback('sunset:casino:status', function(source)
    local charId = getCharId(source)
    if not charId then return nil end
    local entry = DailyLosses[charId]
    local dailyLoss = (entry and entry.date == today()) and entry.total or 0
    return {
        dailyLoss = dailyLoss,
        dailyLimit = Cfg.dailyLossLimit or 500000,
        minBet = Cfg.minBet or 100,
        maxBet = Cfg.maxBet or 50000,
        chips = countChips(source),
        cash = exports.sunset_core:GetMoney(source, 'cash'),
        drinks = Cfg.barDrinks or {},
        prizes = Cfg.luckyWheelPrizes or {},
        wheelCooldownMs = Cfg.luckyWheelCooldownMs or 3600000,
    }
end)

AddEventHandler('playerDropped', function()
    local src = source
    ActiveBlackjack[src] = nil
    GameCooldowns[src] = nil
end)

-- [DISCOVERY] Mirror client probe output into the server log so it can be
-- read via `docker logs blazed-fivem-1 | grep CASINOPROBE`. Also append to a
-- file inside the persistent config volume so probe results SURVIVE container
-- recreation (docker logs of a recreated container are lost).
-- [OVERFLOW FIX] Client now sends lines in batches (max 5 per event) instead
-- of one TriggerServerEvent per line — a 60m scan can enumerate hundreds of
-- entities and the old per-line approach hit "Reliable network event overflow".
local function writeProbeLine(text)
    print('^3' .. text .. '^7')
    local fh = io.open('/config/casino_probe.log', 'a')
    if fh then
        fh:write(os.date('%Y-%m-%d %H:%M:%S ') .. text .. '\n')
        fh:close()
    end
end

RegisterNetEvent('sunset:casino:probeLog', function(line)
    writeProbeLine(('[CASINOPROBE #%d] %s'):format(source, tostring(line):sub(1, 400)))
end)

RegisterNetEvent('sunset:casino:probeLogBatch', function(lines)
    if type(lines) ~= 'table' then return end
    for _, line in ipairs(lines) do
        writeProbeLine(('[CASINOPROBE #%d] %s'):format(source, tostring(line):sub(1, 400)))
    end
end)

print('^2[sunset_casino]^7 The Diamond Casino online (blackjack, slots, roulette)')
